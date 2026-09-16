module Api
  module V1
    class IpAddressesController < BaseController
      def index
        @search = IpAddress.ransack(params[:q])
        @pagy, @ip_addresses = pagy(@search.result.order(:id))
        @meta = pagination_meta(@pagy)
      end

      def show
        @ip_address = IpAddress.find(params[:id])
      end
    end
  end
end
