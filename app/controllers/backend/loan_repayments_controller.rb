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

class Backend::LoanRepaymentsController < Backend::BaseController
  def index
    redirect_to backend_loans_url
  end

  def show
    if @loan_repayment = LoanRepayment.find_by(id: params[:id])
      redirect_to backend_loan_url(@loan_repayment.loan_id)
    else
      redirect_to backend_root_url
    end
  end
end
