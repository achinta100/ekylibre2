# encoding: utf-8
# == License
# Ekylibre - Simple ERP
# Copyright (C) 2013 Brice Texier, David Joulin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

class Backend::ManureManagementPlansController < BackendController
  manage_restfully redirect_to: "{action: :edit, id: 'id'}".c
  
  respond_to :pdf, :odt, :docx, :xml, :json, :html, :csv
  
  unroll

  list do |t|
    t.column :name, url: true
    t.column :campaign, url: true
    t.column :recommender, url: true
    t.column :opened_at, hidden: true
    t.column :default_computation_method, hidden: true
    t.column :selected
    t.action :edit
    t.action :destroy
  end

  list :zones, model: :manure_management_plan_zones do |t|
    t.column :activity, url: true
    t.column :cultivable_zone, url: true
    t.column :nitrogen_need
    t.column :absorbed_nitrogen_at_opening, hidden: true
    t.column :mineral_nitrogen_at_opening, hidden: true
    t.column :humus_mineralization, hidden: true
    t.column :meadow_humus_mineralization, hidden: true
    t.column :previous_cultivation_residue_mineralization, hidden: true
    t.column :intermediate_cultivation_residue_mineralization, hidden: true
    t.column :irrigation_water_nitrogen, hidden: true
    t.column :organic_fertilizer_mineral_fraction, hidden: true
    t.column :nitrogen_at_closing, hidden: true
    t.column :soil_production, hidden: true
    t.column :nitrogen_input
  end
  
  # Show one animal with params_id
  def show
    return unless @manure_management_plan = find_and_check
    t3e @manure_management_plan
    respond_with(@manure_management_plan, :include => [:campaign, :recommender, {:zones => {:include => [:support, :activity,:production]}}])

  end
  
end
