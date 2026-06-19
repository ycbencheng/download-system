module Api
  module V1
    module DashboardAuthentication
      extend ActiveSupport::Concern

      included do
        before_action :authenticate_dashboard!
      end

      private

      # When DASHBOARD_TOKEN is set, dashboard JSON feeds require Bearer auth.
      # Unset in dev/test by default so local review stays frictionless.
      def authenticate_dashboard!
        expected = ENV["DASHBOARD_TOKEN"]
        return if expected.blank?

        provided = request.authorization&.sub(/\ABearer /i, "") || params[:dashboard_token].to_s
        return if provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)

        render json: { error: { code: "unauthorized", message: "Unauthorized" } }, status: :unauthorized
      end
    end
  end
end
