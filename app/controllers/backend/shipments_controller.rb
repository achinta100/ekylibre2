module Backend
  class ShipmentsController < Backend::ParcelsController
    manage_restfully continue: true, except: :new
    before_action :save_search_preference, only: :index

    before_action only: :new do
      params[:shipment] ||= {}
      params[:shipment][:planned_at] ||= Time.zone.now
    end

    respond_to :csv, :ods, :xlsx, :pdf, :odt, :docx, :html, :xml, :json

    unroll

    # params:
    #   :q Text search
    #   :s State search
    #   :period Two Dates with _ separator
    #   :recipient_id
    #   :sender_id
    #   :transporter_id
    #   :delivery_mode Choice
    #   :nature Choice
    def self.shipments_conditions
      code = search_conditions(shipments: %i[number reference_number], entities: %i[full_name number]) + " ||= []\n"
      code << "unless params[:period].blank? || params[:period].is_a?(Symbol)\n"

      code << "  if params[:period] != 'all'\n"
      code << "    if params[:period] == 'interval' \n"
      code << "      started_on = params[:started_on] \n"
      code << "      stopped_on = params[:stopped_on] \n"
      code << "    else \n"
      code << "      interval = params[:period].split('_')\n"
      code << "      started_on = interval.first\n"
      code << "      stopped_on = interval.last\n"
      code << "    end \n"
      code << "    c[0] << \" AND #{Shipment.table_name}.planned_at::DATE BETWEEN ? AND ?\"\n"
      code << "    c << started_on\n"
      code << "    c << stopped_on\n"
      code << "  end\n "
      code << "end\n "
      code << "if params[:recipient_id].to_i > 0\n"
      code << "  c[0] << \" AND \#{Shipment.table_name}.recipient_id = ?\"\n"
      code << "  c << params[:recipient_id].to_i\n"
      code << "end\n"
      code << "if params[:sender_id].to_i > 0\n"
      code << "  c[0] << \" AND \#{Shipment.table_name}.sender_id = ?\"\n"
      code << "  c << params[:sender_id].to_i\n"
      code << "end\n"
      code << "if params[:transporter_id].to_i > 0\n"
      code << "  c[0] << \" AND \#{Shipment.table_name}.transporter_id = ?\"\n"
      code << "  c << params[:transporter_id].to_i\n"
      code << "end\n"
      code << "if params[:responsible_id].to_i > 0\n"
      code << "  c[0] << \" AND \#{Shipment.table_name}.responsible_id = ?\"\n"
      code << "  c << params[:responsible_id]\n"
      code << "end\n"
      code << "if params[:delivery_mode].present? && params[:delivery_mode] != 'all'\n"
      code << "  if Shipment.delivery_mode.values.include?(params[:delivery_mode].to_sym)\n"
      code << "    c[0] << ' AND #{Shipment.table_name}.delivery_mode = ?'\n"
      code << "    c << params[:delivery_mode]\n"
      code << "  end\n"
      code << "end\n"
      code << "if params[:invoice_status] && params[:invoice_status] == 'invoiced'\n"
      code << "  c[0] << ' AND (#{Shipment.table_name}.purchase_id IS NOT NULL OR #{Shipment.table_name}.sale_id IS NOT NULL) '\n"
      code << "elsif params[:invoice_status] && params[:invoice_status] == 'uninvoiced'\n"
      code << "  c[0] << ' AND (#{Shipment.table_name}.purchase_id IS NULL AND #{Shipment.table_name}.sale_id IS NULL) '\n"
      code << "end\n"
      code << "c\n"
      code.c
    end

    list(conditions: shipments_conditions, order: { planned_at: :desc }) do |t|
      t.action :invoice, on: :both, method: :post, if: :invoiceable?
      t.action :ship, on: :both, method: :post, if: :shippable?
      t.action :edit, if: :updateable?
      t.action :destroy
      t.column :number, url: true
      t.column :reference_number, hidden: true
      t.column :content_sentence, label: :contains
      t.column :planned_at
      t.column :given_at
      t.column :recipient, url: true
      t.column :address, url: true, hidden: true
      t.status
      t.column :state, label_method: :human_state_name, hidden: true
      t.column :delivery, url: true
      t.column :responsible, url: true, hidden: true
      t.column :transporter, url: true, hidden: true
      t.column :delivery_mode
      t.column :sale, url: true
    end

    list(:items, model: :parcel_items, conditions: { parcel_id: 'params[:id]'.c }) do |t|
      t.column :source_product, url: true
      t.column :product, url: true, hidden: true
      t.column :product_work_number, through: :product, label_method: :work_number, hidden: true
      t.column :product_identification_number, hidden: true
      t.column :conditioning_unit
      t.column :conditioning_quantity, class: 'left-align'
      t.column :analysis, url: true
    end

    Shipment.state_machine.events.each do |event|
      define_method event.name do
        fire_event(event.name)
      end
    end

    def show
      return unless (shipment = find_and_check)

      respond_to do |format|
        format.pdf do
          next unless (template = find_and_check :document_template, params[:template])

          printer = Printers::ShippingNotePrinter.new(template: template, shipment: shipment)

          generator = Ekylibre::DocumentManagement::DocumentGenerator.build
          pdf_data = generator.generate_pdf(template: template, printer: printer)

          archiver = Ekylibre::DocumentManagement::DocumentArchiver.build
          archiver.archive_document(pdf_content: pdf_data, template: template, key: printer.key, name: printer.document_name)

          send_data pdf_data, filename: "#{printer.document_name}.pdf", type: 'application/pdf', disposition: 'inline'
        end

        format.html do
          super
        end
      end
    end

    def new
      @shipment = Shipment.new(shipment_params)
    end

    # Converts parcel to trade
    def invoice
      parcels = find_parcels
      return unless parcels

      parcel = parcels.first
      begin
        if parcels.all? { |p| p.incoming? && p.third_id == parcel.third_id && p.invoiceable? }
          purchase = Parcel.convert_to_purchase(parcels)
          redirect_to backend_purchase_path(purchase)
        elsif parcels.all? { |p| p.outgoing? && p.third_id == parcel.third_id && p.invoiceable? }
          sale = Parcel.convert_to_sale(parcels)
          redirect_to backend_sale_path(sale)
        end
      rescue ActiveRecord::RecordInvalid => error
        notify_error(error.message)
        redirect_to backend_shipments_path
      rescue StandardError => error
        Rails.logger.error error
        Rails.logger.error error.backtrace.join("\n")
        ElasticAPM.report(error)
        notify_error(:all_parcels_must_be_invoiceable_and_of_same_nature_and_third)
        redirect_to(params[:redirect] || { action: :index })
      end
    end

    #
    # Pre-fill delivery form with given parcels. Nothing else.
    # Only a shortcut now.
    def ship
      parcels = find_parcels
      return unless parcels

      parcel = parcels.detect(&:shippable?)
      options = { parcel_ids: parcels.map(&:id) }
      if !parcel
        redirect_to(options.merge(controller: :deliveries, action: :new))
      elsif parcels.all? { |p| p.shippable? && (p.delivery_mode == parcel.delivery_mode) }
        options[:mode] = parcel.delivery_mode
        options[:transporter_id] = parcel.transporter_id if parcel.transporter
        redirect_to(options.merge(controller: :deliveries, action: :new))
      else
        notify_error(:some_parcels_are_not_shippable)
        redirect_to(params[:redirect] || { action: :index })
      end
    end

    private

      def shipment_params
        params.require(:shipment).permit(:planned_at, :sale_id, :recipient_id, items_attributes: %i[source_product_id conditioning_quantity conditioning_unit_id])
      end
  end
end
