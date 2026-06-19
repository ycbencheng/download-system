module Api
  module V1
    class ProductsController < BaseController
      def create
        product = Product.create!(product_params)

        render json: {
          id: product.id,
          name: product.name,
          file_name: product.file_name,
          expiry_hours: product.expiry_hours,
          max_downloads: product.max_downloads,
          created_at: product.created_at.iso8601
        }, status: :created
      end

      private

      def product_params
        source = params[:product].present? ? params.require(:product) : params
        source.permit(:name, :file_name, :expiry_hours, :max_downloads)
      end
    end
  end
end
