class DownloadsController < ApplicationController
  include DownloadLinkLookup

  # Token URLs use a layout with no JavaScript.
  layout "download"

  PLACEHOLDER_FILE = "/downloads/sample.pdf"

  protect_from_forgery with: :exception
  # HTML form POSTs from button_to include the CSRF token; JSON POSTs skip verification.
  skip_before_action :verify_authenticity_token, only: :download, if: -> { request.format.json? }

  # GET show is read-only; POST download consumes one download. Prefetchers and
  # email scanners typically issue GET only, so they cannot burn the limit.

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

    case link.status
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

  def download
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

    # Single atomic conditional UPDATE — one round trip, safe under concurrent POSTs.
    # update_all (not increment!) avoids row locks and keeps the guard in one SQL statement.
    # revoked_at IS NULL in the WHERE clause enforces revocation alongside limit and expiry.
    updated = DownloadLink
      .where(id: link.id)
      .where("download_count < max_downloads AND expires_at > ? AND revoked_at IS NULL", Time.current)
      .update_all("download_count = download_count + 1")

    if updated == 1
      # update_all bypasses Active Record — reload before using the link again.
      link.reload

      # DownloadEvent is audit-only; download_count on the link is canonical.
      # Buyer still gets the file if audit insert fails — intentional tradeoff.
      begin
        link.download_events.create!(
          ip: request.remote_ip,
          user_agent: request.user_agent
        )
      rescue StandardError => e
        Rails.logger.error(
          "DownloadEvent insert failed for link #{link.id}: #{e.class}: #{e.message}"
        )
      end

      redirect_to PLACEHOLDER_FILE, allow_other_host: false
    else
      link.reload

      case link.status
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
      else
        render_download_error(
          status: :forbidden,
          code: "limit_reached",
          message: "This link has reached its download limit",
          template: :limit
        )
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
