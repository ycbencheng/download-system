class DownloadsController < ApplicationController
  include DownloadLinkLookup

  # Token URLs use a layout with no JavaScript.
  layout "download"

  protect_from_forgery with: :exception
  # HTML form POSTs from button_to include the CSRF token; JSON POSTs skip verification.
  skip_before_action :verify_authenticity_token, only: :download, if: -> { request.format.json? }

  # GET show is read-only; POST download consumes one download. GET-only clients
  # (common prefetchers and email scanners) never increment download_count.

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

    # Resolve and verify the file BEFORE consuming a download: never burn one of
    # the buyer's downloads for a file we cannot deliver.
    file_path = ::DownloadDelivery.path_for(link.order.product)
    unless file_path
      Rails.logger.error(
        "Download file unavailable for link #{link.id} (product #{link.order.product_id})"
      )
      return render_download_error(
        status: :internal_server_error,
        code: "file_unavailable",
        message: "The file for this download is temporarily unavailable",
        template: :unavailable
      )
    end

    # Atomic conditional UPDATE: limit, expiry, and revocation enforced in one
    # statement so the cap holds under concurrent POSTs (read-then-increment races).
    updated = DownloadLink
      .where(id: link.id)
      .where("download_count < max_downloads AND expires_at > ? AND revoked_at IS NULL", Time.current)
      .update_all("download_count = download_count + 1")

    if updated == 1
      link.reload # update_all bypasses Active Record.
      log_download_event(link, "success")
      # Token-gated stream: the controller is the only path to these bytes.
      send_file file_path, disposition: "attachment"
    else
      link.reload
      # Audit the failed attempt against this known link. We only log attempts on
      # links that exist (never unknown tokens), so this cannot become an
      # unbounded write vector — production still needs Rack::Attack to bound the
      # volume of attempts against a single valid link.
      log_download_event(link, link.status.to_s)

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

  # DownloadEvent is best-effort audit; download_count on the link is canonical,
  # so the buyer still gets the file if the audit insert fails.
  def log_download_event(link, outcome)
    link.download_events.create!(
      ip: request.remote_ip,
      user_agent: request.user_agent,
      outcome: outcome
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
    Rails.logger.error(
      "DownloadEvent insert failed for link #{link.id}: #{e.class}: #{e.message}"
    )
  end

  def render_download_error(status:, code:, message:, template:)
    respond_to do |format|
      format.html { render template, status: status }
      format.json do
        render json: { error: { code: code, message: message } }, status: status
      end
    end
  end
end
