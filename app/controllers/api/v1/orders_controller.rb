module Api
  module V1
    class OrdersController < BaseController
      def create
        product = Product.find(order_params.require(:product_id))
        order = product.orders.new(buyer_email: order_params.require(:buyer_email))

        raw_token = SecureRandom.urlsafe_base64(32)
        # Store SHA256(token), not the raw value. Lookup is by digest on a unique index.
        token_digest = Digest::SHA256.hexdigest(raw_token)

        # No collision retry: a 256-bit random token makes a digest collision
        # unreachable (~2^-128). The unique index is correctness insurance, not a
        # hot path — if the impossible happens it surfaces as a 500 rather than
        # masking a real bug behind a retry loop.
        ActiveRecord::Base.transaction do
          order.save!
          order.create_download_link!(
            token_digest: token_digest,
            expires_at: order.created_at + product.expiry_hours.hours,
            max_downloads: product.max_downloads
          )
        end

        download_url = download_url_for(raw_token)

        # deliver_later runs outside the transaction block, so the order row is committed
        # before the job is enqueued (email still sends asynchronously).
        DownloadMailer.link_email(order, download_url).deliver_later

        render json: {
          order_id: order.id,
          download_url: download_url,
          expires_at: order.download_link.expires_at.iso8601,
          max_downloads: product.max_downloads
        }, status: :created
      end

      private

      # Accept nested { order: { … } } (README curl) or flat { product_id, buyer_email }.
      def order_params
        source = params[:order].present? ? params.require(:order) : params
        source.permit(:product_id, :buyer_email)
      end

      # Use configured host, not request.base_url — prevents Host-header poisoning in download URLs.
      def download_url_for(token)
        opts = Rails.application.config.action_mailer.default_url_options
        download_landing_url(token, **opts)
      end
    end
  end
end
