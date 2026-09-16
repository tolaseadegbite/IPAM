module Api
  module V1
    class DevicesController < BaseController
      def index
        @search = Device.ransack(params[:q])
        @pagy, @devices = pagy(@search.result.order(:id))
        @meta = pagination_meta(@pagy)
      end

      def show
        @device = Device.includes(:ip_addresses).find(params[:id])
      end
    end
  end
end
