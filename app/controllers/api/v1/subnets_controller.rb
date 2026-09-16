module Api
  module V1
    class SubnetsController < BaseController
      def index
        @pagy, @subnets = pagy(Subnet.order(:id))
        @meta = pagination_meta(@pagy)
      end

      def show
        @subnet = Subnet.find(params[:id])
      end
    end
  end
end
