module Api
  module V1
    class BaseController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound do |e|
        render json: { error: { code: "not_found", message: e.message } }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: { error: { code: "validation_failed", message: e.record.errors.full_messages.join(", ") } },
               status: :unprocessable_entity
      end

      rescue_from ActionController::ParameterMissing do |e|
        render json: { error: { code: "validation_failed", message: e.message } },
               status: :unprocessable_entity
      end
    end
  end
end
