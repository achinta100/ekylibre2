# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2011 Brice Texier, Thibaud Merigon
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

module Backend
  class OutgoingPaymentListsController < Backend::BaseController
    manage_restfully only: %i[index destroy]

    respond_to :pdf, :odt, :docx, :xml, :json, :html, :csv

    list do |t|
      t.action :destroy, if: :destroyable?
      t.action :export_to_sepa, method: :get, if: :sepa_exportable?
      t.column :number, url: true
      t.column :created_at
      t.column :mode
      t.column :cached_payment_count, datatype: :integer
      t.column :cached_total_sum, label: :total, datatype: :float, currency: true
    end

    list(:payments, model: :purchase_payment, conditions: { list_id: 'params[:id]'.c }) do |t|
      t.column :number, url: true
      t.column :payee, url: true
      t.column :paid_at
      t.column :amount, currency: true, url: true
      t.column :mode
      t.column :bank_check_number
      t.column :to_bank_at
      t.column :work_name, through: :affair, label: :affair_number, url: { controller: :purchase_affairs }
      t.column :deal_work_name, through: :affair, label: :purchase_number, url: { controller: :purchase_invoices, id: 'RECORD.affair.deals_of_type(Purchase).first.id'.c }
      t.column :bank_statement_number, through: :journal_entry, url: { controller: :bank_statements, id: 'RECORD.journal_entry.bank_statements.first.id'.c }
    end

    def show
      return unless (@outgoing_payment_list = find_and_check)

      t3e @outgoing_payment_list

      respond_to do |format|
        format.html
        format.pdf do
          template = DocumentTemplate.find(params[:template])

          if template.file_extension == 'odt'
            printer = Printers::OutgoingPaymentListPrinter.new(outgoing_payment_list: @outgoing_payment_list, nature: params[:nature], template: template)

            generator = Ekylibre::DocumentManagement::DocumentGenerator.build
            pdf_data = generator.generate_pdf(template: template, printer: printer)

            archiver = Ekylibre::DocumentManagement::DocumentArchiver.build
            archiver.archive_document(
              pdf_content: pdf_data,
              template: template,
              key: printer.key,
              name: printer.document_name
            )

            send_data pdf_data, type: 'application/pdf', disposition: 'attachment', filename: "#{printer.document_name}.pdf"
          else
            respond_with(
              @outgoing_payment_list,
              methods: %i[currency payments_sum entity],
              include: {
                payer: {
                  methods: [:picture_path],
                  include: {
                    default_mail_address: {
                      methods: [:mail_coordinate]
                    },
                    websites: {},
                    emails: {},
                    mobiles: {}
                  }
                },
                payments: {
                  methods: %i[amount_to_letter label affair_reference_numbers],
                  include: {
                    responsible: {},
                    affair: { include: { purchase_invoices: {} } },
                    mode: {},
                    payee: {
                      include: {
                        default_mail_address: {
                          methods: [:mail_coordinate]
                        },
                        websites: {},
                        emails: {},
                        mobiles: {}
                      }
                    }
                  }
                }
              }
            )
          end
        end
      end
    end

    def export_to_sepa
      list = OutgoingPaymentList.find(params[:id])

      if list.sepa?
        send_data(list.to_sepa, filename: "#{list.number}.xml", type: 'text/xml')
      else
        render :index
      end
    end

    def new
      @outgoing_payment_list = OutgoingPaymentList.new
      @affairs = []

      if params[:period_reference] && params[:outgoing_payment_list] && params[:outgoing_payment_list][:mode_id]
        params[:started_at] = FinancialYear.minimum(:started_on) if params[:started_at].blank?
        params[:stopped_at] = FinancialYear.maximum(:stopped_on) if params[:stopped_at].blank?
        mode = OutgoingPaymentMode.find_by(id: params[:outgoing_payment_list][:mode_id])
        @outgoing_payment_list.mode = mode
        if @outgoing_payment_list.valid?
          @currency = mode.cash.currency
          @affairs = PurchaseAffair
                       .joins(:purchase_invoices)
                       .joins(:supplier)
                       .includes(:supplier)
                       .where(closed: false, currency: mode.cash.currency)
                       .where("purchases.#{params[:period_reference]} IS NOT NULL AND purchases.#{params[:period_reference]} BETWEEN ? AND ?", params[:started_at], params[:stopped_at])
                       .where.not(purchases: { id: nil })
                       .where(entities: { supplier_payment_mode_id: mode.id })
                       .order('entities.full_name ASC')
                       .order("purchases.#{params[:period_reference]} ASC", :number)

          notify_warning :no_purchase_affair_found_on_given_period if @affairs.empty?
        end
      end
      @submit_label = :search.tl if @affairs.none?
    end

    def create
      params[:purchase_affairs] ||= []
      params[:purchase_affairs].reject!(&:empty?)

      if params[:purchase_affairs].is_a?(Array) && params[:purchase_affairs].any?
        affairs = PurchaseAffair.where(id: params[:purchase_affairs].compact).uniq

        mode_id = params[:outgoing_payment_list][:mode_id] if params[:outgoing_payment_list] && params[:outgoing_payment_list][:mode_id]
        outgoing_payment_list = OutgoingPaymentList.build_from_affairs(affairs, OutgoingPaymentMode.find_by(id: mode_id), current_user, params[:bank_check_number], true)
        outgoing_payment_list.save!

        redirect_to action: :show, id: outgoing_payment_list.id
      else
        permitted = params.permit(:period_reference, :started_at, :stopped_at, :bank_check_number, outgoing_payment_list: %i[mode_id])

        redirect_to new_backend_outgoing_payment_list_path(permitted.to_h)
      end
    end

    def destroy
      return unless @outgoing_payment_list = find_and_check

      @outgoing_payment_list.remove if @outgoing_payment_list
      redirect_to action: :index
    end
  end
end
