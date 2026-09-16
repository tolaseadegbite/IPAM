module Api
  module V1
    class BaseController < ActionController::API
      include Pagy::Backend

      before_action :authenticate_token!

      private

      def authenticate_token!
        raw = request.headers["Authorization"].to_s.sub(/\ABearer\s+/i, "")
        digest = Digest::SHA256.hexdigest(raw.presence || "")
        token = ApiToken.includes(:user).find_by(token_digest: digest)

        if token.nil? || token.expired?
          render json: { error: { code: "unauthorized", message: "Valid Bearer token required." } }, status: :unauthorized
        else
          token.touch_last_used!
        end
      end

      def pagination_meta(pagy)
        { page: pagy.page, pages: pagy.pages, count: pagy.count, limit: pagy.limit }
      end
    end
  end
end
