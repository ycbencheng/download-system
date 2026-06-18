module Api
  module V1
    class OrdersController < BaseController
      def create
        product = Product.find(params.require(:product_id))
        order = product.orders.new(buyer_email: params.require(:buyer_email))

        raw_token = SecureRandom.urlsafe_base64(32)
        # Store SHA256(token), not the raw value. Lookup is by digest on a unique index.
        token_digest = Digest::SHA256.hexdigest(raw_token)

        ActiveRecord::Base.transaction do
          order.save!
          order.download_links.create!(
            token_digest: token_digest,
            expires_at: order.created_at + product.expiry_hours.hours,
            max_downloads: product.max_downloads
          )
        end

        download_url = download_url_for(raw_token)

        # Enqueue after the transaction commits so the order exists before email sends.
        DownloadMailer.link_email(order, download_url).deliver_later

        render json: {
          order_id: order.id,
          download_url: download_url,
          expires_at: order.download_links.first.expires_at.iso8601,
          max_downloads: product.max_downloads
        }, status: :created
      end

      private

      def download_url_for(token)
        "#{request.base_url}/d/#{token}"
      end
    end
  end
end
