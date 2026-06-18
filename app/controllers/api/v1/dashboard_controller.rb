module Api
  module V1
    class DashboardController < BaseController
      def products
        products = Product.order(created_at: :desc)
        render json: products.map { |p|
          {
            id: p.id,
            name: p.name,
            file_name: p.file_name,
            expiry_hours: p.expiry_hours,
            max_downloads: p.max_downloads,
            created_at: p.created_at.iso8601
          }
        }
      end

      def orders
        orders = Order.includes(:product, download_links: :download_events)
                      .order(created_at: :desc)
                      .limit(50)

        render json: orders.map { |o|
          link = o.download_links.first
          {
            id: o.id,
            buyer_email: o.buyer_email,
            product_name: o.product.name,
            created_at: o.created_at.iso8601,
            download_link: link && {
              id: link.id,
              expires_at: link.expires_at.iso8601,
              max_downloads: link.max_downloads,
              download_count: link.download_count,
              revoked: link.revoked?,
              status: link_status(link)
            }
          }
        }
      end

      def download_events
        events = DownloadEvent.includes(download_link: { order: :product })
                              .order(created_at: :desc)
                              .limit(100)

        render json: events.map { |e|
          link = e.download_link
          {
            id: e.id,
            ip: e.ip,
            user_agent: e.user_agent,
            created_at: e.created_at.iso8601,
            download_link_id: link.id,
            buyer_email: link.order.buyer_email,
            product_name: link.order.product.name
          }
        }
      end

      private

      def link_status(link)
        return "revoked" if link.revoked?
        return "expired" if link.expires_at <= Time.current
        return "limit_reached" if link.download_count >= link.max_downloads

        "active"
      end
    end
  end
end
