require "test_helper"

class DownloadsControllerTest < ActionDispatch::IntegrationTest
  test "GET /d/:token renders landing page with Download button and does not change count" do
    link = download_links(:active)
    token = "fixture-active-token"

    assert_no_difference -> { link.reload.download_count } do
      get download_landing_url(token: token)
    end

    assert_response :success
    assert_includes response.body, "Sample Ebook"
    assert_includes response.body, "Download"
    assert_includes response.body, 'method="post"'
  end

  test "GET /d/:token landing page ships no script tags (bearer-token pages stay JS-free)" do
    get download_landing_url(token: "fixture-active-token")

    assert_response :success
    assert_no_match(/<script/i, response.body, "download landing page must not load any JS")
    assert_no_match(%r{/@vite/client}, response.body, "download landing page must not load Vite")
  end

  test "GET /d/:token error page ships no script tags" do
    get download_landing_url(token: "bogus-token")

    assert_response :not_found
    assert_no_match(/<script/i, response.body, "download error page must not load any JS")
  end

  test "GET /d/:token returns JSON when ready" do
    get download_landing_url(token: "fixture-active-token"), headers: { "Accept" => "application/json" }

    assert_response :success
    body = response.parsed_body
    assert_equal "ready", body["status"]
    assert_equal "Sample Ebook", body["product_name"]
    assert body["expires_at"].present?
  end

  test "GET /d/:token returns 404 for unknown token" do
    get download_landing_url(token: "bogus-token")

    assert_response :not_found
    assert_includes response.body, "Link not found"
  end

  test "GET /d/:token returns 404 JSON for unknown token" do
    get download_landing_url(token: "bogus-token"), headers: { "Accept" => "application/json" }

    assert_response :not_found
    body = response.parsed_body
    assert_equal "not_found", body.dig("error", "code")
    assert_equal "Link not found", body.dig("error", "message")
  end

  test "GET /d/:token returns 410 for expired link" do
    get download_landing_url(token: "fixture-expired-token")

    assert_response :gone
    assert_includes response.body, "expired"
  end

  test "GET /d/:token returns 410 JSON for expired link" do
    get download_landing_url(token: "fixture-expired-token"), headers: { "Accept" => "application/json" }

    assert_response :gone
    body = response.parsed_body
    assert_equal "expired", body.dig("error", "code")
    assert_equal "This download link has expired", body.dig("error", "message")
  end

  test "GET /d/:token returns 410 for revoked link" do
    get download_landing_url(token: "fixture-revoked-token")

    assert_response :gone
    assert_includes response.body, "revoked"
  end

  test "GET /d/:token returns 410 JSON for revoked link" do
    get download_landing_url(token: "fixture-revoked-token"), headers: { "Accept" => "application/json" }

    assert_response :gone
    body = response.parsed_body
    assert_equal "revoked", body.dig("error", "code")
    assert_equal "This download link has been revoked", body.dig("error", "message")
  end

  test "GET /d/:token returns 403 for limit-reached link" do
    get download_landing_url(token: "fixture-maxed-token")

    assert_response :forbidden
    assert_includes response.body, "limit"
  end

  test "GET /d/:token returns 403 JSON for limit-reached link" do
    get download_landing_url(token: "fixture-maxed-token"), headers: { "Accept" => "application/json" }

    assert_response :forbidden
    body = response.parsed_body
    assert_equal "limit_reached", body.dig("error", "code")
    assert_equal "This link has reached its download limit", body.dig("error", "message")
  end

  test "POST /d/:token increments count, logs DownloadEvent, and streams the file" do
    link = download_links(:active)

    assert_difference -> { link.reload.download_count }, 1 do
      assert_difference -> { DownloadEvent.where(download_link: link).count }, 1 do
        post download_confirm_url(token: "fixture-active-token"), headers: { "User-Agent" => "Minitest" }
      end
    end

    assert_response :success
    assert_match(/attachment/, response.headers["Content-Disposition"])

    event = DownloadEvent.where(download_link: link).order(:created_at).last
    assert_equal "127.0.0.1", event.ip
    assert_equal "Minitest", event.user_agent
  end

  test "POST /d/:token logs a limit_reached outcome against an existing maxed link" do
    link = download_links(:maxed)

    assert_difference -> { DownloadEvent.where(download_link: link).count }, 1 do
      post download_confirm_url(token: "fixture-maxed-token")
    end

    assert_response :forbidden
    assert_equal "limit_reached", DownloadEvent.where(download_link: link).order(:created_at).last.outcome
  end

  test "POST /d/:token logs an expired outcome against an existing expired link" do
    link = download_links(:expired)

    assert_difference -> { DownloadEvent.where(download_link: link).count }, 1 do
      post download_confirm_url(token: "fixture-expired-token")
    end

    assert_response :gone
    assert_equal "expired", DownloadEvent.where(download_link: link).order(:created_at).last.outcome
  end

  test "POST /d/:token logs a revoked outcome against an existing revoked link" do
    link = download_links(:revoked)

    assert_difference -> { DownloadEvent.where(download_link: link).count }, 1 do
      post download_confirm_url(token: "fixture-revoked-token")
    end

    assert_response :gone
    assert_equal "revoked", DownloadEvent.where(download_link: link).order(:created_at).last.outcome
  end

  test "POST /d/:token writes no audit row for an unknown token" do
    assert_no_difference -> { DownloadEvent.count } do
      post download_confirm_url(token: "bogus-token")
    end

    assert_response :not_found
  end

  test "POST /d/:token returns 500 without consuming a download when the file is missing" do
    link = download_links(:active)
    link.order.product.update!(file_name: "not-on-disk.pdf")

    assert_no_difference -> { link.reload.download_count } do
      assert_no_difference -> { DownloadEvent.where(download_link: link).count } do
        post download_confirm_url(token: "fixture-active-token")
      end
    end

    assert_response :internal_server_error
  end

  test "POST /d/:token still streams the file when DownloadEvent insert fails" do
    link = download_links(:active)
    original_save = DownloadEvent.instance_method(:save!)
    DownloadEvent.define_method(:save!) do |*_args, **_kwargs, &_block|
      raise ActiveRecord::StatementInvalid.new("PG::Error: audit insert failed")
    end

    assert_difference -> { link.reload.download_count }, 1 do
      assert_no_difference -> { DownloadEvent.where(download_link: link).count } do
        post download_confirm_url(token: "fixture-active-token")
      end
    end

    assert_response :success
    assert_match(/attachment/, response.headers["Content-Disposition"])
  ensure
    DownloadEvent.define_method(:save!, original_save) if original_save
  end

  test "GET /d/:token returns 410 expired when link is both expired and maxed" do
    link = download_links(:active)
    link.update!(expires_at: 1.hour.ago, download_count: link.max_downloads)

    get download_landing_url(token: "fixture-active-token"), headers: { "Accept" => "application/json" }

    assert_response :gone
    body = response.parsed_body
    assert_equal "expired", body.dig("error", "code")
    assert_not_equal "limit_reached", body.dig("error", "code")
  end

  test "POST /d/:token returns 404 for unknown token" do
    post download_confirm_url(token: "bogus-token")

    assert_response :not_found
    assert_includes response.body, "Link not found"
  end

  test "POST /d/:token returns 404 JSON for unknown token" do
    post download_confirm_url(token: "bogus-token"), headers: { "Accept" => "application/json" }

    assert_response :not_found
    body = response.parsed_body
    assert_equal "not_found", body.dig("error", "code")
  end

  test "POST /d/:token returns 410 for expired link" do
    post download_confirm_url(token: "fixture-expired-token")

    assert_response :gone
    assert_includes response.body, "expired"
  end

  test "POST /d/:token returns 410 JSON for expired link" do
    post download_confirm_url(token: "fixture-expired-token"), headers: { "Accept" => "application/json" }

    assert_response :gone
    body = response.parsed_body
    assert_equal "expired", body.dig("error", "code")
  end

  test "POST /d/:token returns 410 for revoked link" do
    post download_confirm_url(token: "fixture-revoked-token")

    assert_response :gone
    assert_includes response.body, "revoked"
  end

  test "POST /d/:token returns 410 JSON for revoked link" do
    post download_confirm_url(token: "fixture-revoked-token"), headers: { "Accept" => "application/json" }

    assert_response :gone
    body = response.parsed_body
    assert_equal "revoked", body.dig("error", "code")
  end

  test "POST /d/:token returns 403 for limit-reached link" do
    post download_confirm_url(token: "fixture-maxed-token")

    assert_response :forbidden
    assert_includes response.body, "limit"
  end

  test "POST /d/:token returns 403 JSON for limit-reached link" do
    post download_confirm_url(token: "fixture-maxed-token"), headers: { "Accept" => "application/json" }

    assert_response :forbidden
    body = response.parsed_body
    assert_equal "limit_reached", body.dig("error", "code")
  end

  test "POST /d/:token allows exactly max_downloads successes then returns 403" do
    link = download_links(:active)
    token = "fixture-active-token"
    max = link.max_downloads

    max.times do
      post download_confirm_url(token: token)
      assert_response :success, "download #{link.reload.download_count} should succeed"
    end

    assert_equal max, link.reload.download_count

    post download_confirm_url(token: token)
    assert_response :forbidden
    assert_equal max, link.reload.download_count
  end

  test "POST /d/:token treats link at exact expires_at as expired" do
    link = download_links(:active)
    link.update!(expires_at: Time.zone.parse("2026-06-01 12:00:00"))

    travel_to Time.zone.parse("2026-06-01 12:00:00") do
      post download_confirm_url(token: "fixture-active-token")
      assert_response :gone
      assert_equal 0, link.reload.download_count
    end
  end

  test "POST /d/:token succeeds one microsecond before expires_at" do
    link = download_links(:active)
    expiry = Time.zone.parse("2026-06-01 12:00:00")
    link.update!(expires_at: expiry)

    travel_to Time.at(expiry.to_f - 0.000001) do
      post download_confirm_url(token: "fixture-active-token")
      assert_response :success
      assert_equal 1, link.reload.download_count
    end
  end

  # --- Revocation mid-flight ---

  test "revoking an active link makes GET landing return 410" do
    link = download_links(:active)

    get download_landing_url(token: "fixture-active-token")
    assert_response :success, "precondition: link is valid before revocation"

    link.revoke!

    get download_landing_url(token: "fixture-active-token")
    assert_response :gone
    assert_includes response.body, "revoked"
  end

  test "revoking an active link makes POST confirm return 410 and does not increment count" do
    link = download_links(:active)

    post download_confirm_url(token: "fixture-active-token")
    assert_response :success, "precondition: download succeeds before revocation"

    link.revoke!

    assert_no_difference -> { link.reload.download_count } do
      post download_confirm_url(token: "fixture-active-token")
    end

    assert_response :gone
    assert_includes response.body, "revoked"
  end

  test "revoking an active link makes GET landing return 410 JSON" do
    link = download_links(:active)
    link.revoke!

    get download_landing_url(token: "fixture-active-token"), headers: { "Accept" => "application/json" }

    assert_response :gone
    body = response.parsed_body
    assert_equal "revoked", body.dig("error", "code")
    assert_equal "This download link has been revoked", body.dig("error", "message")
  end

  test "revoking an active link makes POST confirm return 410 JSON" do
    link = download_links(:active)
    link.revoke!

    post download_confirm_url(token: "fixture-active-token"), headers: { "Accept" => "application/json" }

    assert_response :gone
    body = response.parsed_body
    assert_equal "revoked", body.dig("error", "code")
    assert_equal "This download link has been revoked", body.dig("error", "message")
  end
end
