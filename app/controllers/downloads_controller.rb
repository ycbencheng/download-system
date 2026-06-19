class DownloadsController < ApplicationController
  include DownloadLinkLookup

  # Token URLs use a layout with no JavaScript.
  layout "download"

  protect_from_forgery with: :exception
  # HTML form POSTs from button_to include the CSRF token; JSON POSTs skip verification.
  skip_before_action :verify_authenticity_token, only: :download, if: -> { request.format.json? }

  # Single source of truth for buyer-facing errors. Status symbols returned by
  # DownloadLink#status (:revoked/:expired/:limit_reached) are also keys here, so
  # a failed download can be rendered straight from the link's status.
  ERROR_RESPONSES = {
    not_found: {
      status: :not_found, code: "not_found",
      message: "Link not found", template: :not_found
    },
    revoked: {
      status: :gone, code: "revoked",
      message: "This download link has been revoked", template: :revoked
    },
    expired: {
      status: :gone, code: "expired",
      message: "This download link has expired", template: :expired
    },
    limit_reached: {
      status: :forbidden, code: "limit_reached",
      message: "This link has reached its download limit", template: :limit
    },
    file_unavailable: {
      status: :internal_server_error, code: "file_unavailable",
      message: "The file for this download is temporarily unavailable", template: :unavailable
    }
  }.freeze

  # GET show is read-only; POST download consumes one download. GET-only clients
  # (common prefetchers and email scanners) never increment download_count.

  def show
    @token = params[:token]
    link = find_link_by_token(@token)
    return render_download_error(:not_found) unless link

    @link = link
    @product = link.order.product

    if link.status == :ok
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
    else
      render_download_error(link.status)
    end
  end

  def download
    @token = params[:token]
    link = find_link_by_token(@token)
    return render_download_error(:not_found) unless link

    # Resolve and verify the file BEFORE consuming a download: never burn one of
    # the buyer's downloads for a file we cannot deliver.
    file_path = ::DownloadDelivery.path_for(link.order.product)
    unless file_path
      Rails.logger.error(
        "Download file unavailable for link #{link.id} (product #{link.order.product_id})"
      )
      return render_download_error(:file_unavailable)
    end

    if link.consume
      link.reload # update_all bypasses Active Record.
      log_download_event(link, "success")
      send_file file_path, disposition: "attachment"
    else
      link.reload
      # Classify why the consume failed. The status cannot normally be :ok here
      # (counts only rise, expiry is fixed, revocation is one-way), but guard it
      # so we never log or render an outcome outside the documented vocabulary.
      outcome = link.status
      outcome = :limit_reached if outcome == :ok

      # Audit the failed attempt against this known link only (never unknown
      # tokens), so the open endpoint cannot become an unbounded write vector.
      # Production still needs Rack::Attack to bound attempts per valid link.
      log_download_event(link, outcome.to_s)
      render_download_error(outcome)
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

  def render_download_error(key)
    spec = ERROR_RESPONSES.fetch(key)
    respond_to do |format|
      format.html { render spec[:template], status: spec[:status] }
      format.json do
        render json: { error: { code: spec[:code], message: spec[:message] } }, status: spec[:status]
      end
    end
  end
end
