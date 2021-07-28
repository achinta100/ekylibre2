module Api
  module V2
    # Plants API permits to access plants
    class PlantsController < Api::V2::BaseController
      def index
        if modified_since = params[:modified_since]
          plants = Plant.where('activity_production_id IS NOT NULL AND updated_at > ?', modified_since.to_date).includes(activity_production: :activity)
        else
          plants = Plant.where('activity_production_id IS NOT NULL').includes(activity_production: :activity)
        end
        render 'api/v2/plants/index.json', locals: { plants: plants }
      end
    end
  end
end