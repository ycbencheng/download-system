module Api
  module V1
    module DashboardAuthentication
      extend ActiveSupport::Concern

      included do
        before_action :authenticate_dashboard!
      end

      private

      # The dashboard feeds expose buyer PII (emails, IPs, user agents), so they
      # fail closed in production: no DASHBOARD_TOKEN means no access. In dev/test
      # the token is optional so local review stays frictionless.
      def authenticate_dashboard!
        expected = ENV["DASHBOARD_TOKEN"]

        if expected.blank?
          return unless Rails.env.production?

          return render json: {
            error: { code: "unauthorized", message: "Dashboard access is not configured" }
          }, status: :unauthorized
        end

        provided = request.authorization&.sub(/\ABearer /i, "") || params[:dashboard_token].to_s
        return if provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)

        render json: { error: { code: "unauthorized", message: "Unauthorized" } }, status: :unauthorized
      end
    end
  end
end
