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

class Backend::SaleCreditsController < Backend::BaseController
  before_action :find_credited_sale
  after_action :render_form

  def new # undo
    @sale_credit = @credited_sale.build_credit
    t3e @sale_credit.credited_sale
  end

  def create # cancel
    attributes = permitted_params[:sale]
    attributes[:credit] = true
    attributes[:credited_sale_id] = @credited_sale.id
    @sale_credit = Sale.new(attributes)
    saved = false
    if @sale_credit.save
      @sale_credit.reload
      @sale_credit.propose!
      @sale_credit.confirm!
      @sale_credit.invoice!
      saved = true
    end
    return false if save_and_redirect(@sale_credit, saved: saved, url: ({ controller: :sales, action: :show, id: 'id'.c }))
    t3e @sale_credit.credited_sale
  end

  protected

  def permitted_params
    params.permit!
  end

  def find_credited_sale
    return false unless @credited_sale = find_and_check(:sale, params[:credited_sale_id])
    unless @credited_sale.cancellable?
      notify_error :the_sales_invoice_is_not_cancellable
      redirect_to params[:redirect] || { action: :index }
      return false
    end
  end

  def render_form
    @form_url = backend_sale_credits_url(credited_sale_id: @credited_sale.id)
    # render locals: {cancel_url: backend_sales_url}
  end
end
