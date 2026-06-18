class DownloadsController < ApplicationController
  include DownloadLinkLookup

  def show
    @token = params[:token]
    link = find_link_by_token(@token)

    unless link
      return render_download_error(
        status: :not_found,
        code: "not_found",
        message: "Link not found",
        template: :not_found
      )
    end

    @link = link
    @product = link.order.product

    case link_status(link)
    when :revoked
      render_download_error(
        status: :gone,
        code: "revoked",
        message: "This download link has been revoked",
        template: :revoked
      )
    when :expired
      render_download_error(
        status: :gone,
        code: "expired",
        message: "This download link has expired",
        template: :expired
      )
    when :limit_reached
      render_download_error(
        status: :forbidden,
        code: "limit_reached",
        message: "This link has reached its download limit",
        template: :limit
      )
    else
      respond_to do |format|
        format.html
        format.json do
          render json: {
            status: "ready",
            product_name: @product.name,
            expires_at: link.expires_at.iso8601
          }
        end
      end
    end
  end

  private

  def render_download_error(status:, code:, message:, template:)
    respond_to do |format|
      format.html { render template, status: status }
      format.json do
        render json: { error: { code: code, message: message } }, status: status
      end
    end
  end
end
