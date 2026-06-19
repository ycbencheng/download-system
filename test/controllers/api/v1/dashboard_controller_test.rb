require "test_helper"

class Api::V1::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "GET /api/v1/products returns all products" do
    get api_v1_products_url, as: :json

    assert_response :ok
    body = response.parsed_body
    assert_kind_of Array, body
    assert body.any? { |p| p["name"] == products(:ebook).name }

    product = body.first
    %w[id name file_name expiry_hours max_downloads created_at].each do |key|
      assert product.key?(key), "expected product to include #{key}"
    end
  end

  test "GET /api/v1/orders returns recent orders with link status" do
    get api_v1_orders_url, as: :json

    assert_response :ok
    body = response.parsed_body
    assert_kind_of Array, body

    order_json = body.find { |o| o["buyer_email"] == orders(:alice).buyer_email }
    assert order_json, "expected alice's order in the response"
    assert_equal products(:ebook).name, order_json["product_name"]

    link = order_json["download_link"]
    assert link, "expected a download_link summary"
    %w[id expires_at max_downloads download_count revoked status].each do |key|
      assert link.key?(key), "expected download_link to include #{key}"
    end
  end

  test "GET /api/v1/orders link status reflects actual state" do
    get api_v1_orders_url, as: :json
    body = response.parsed_body

    statuses = body.flat_map { |o| o["download_link"] ? [o["download_link"]["status"]] : [] }
    assert statuses.include?("active"), "expected at least one active link"
  end

  test "GET /api/v1/download_events returns recent events" do
    get api_v1_download_events_url, as: :json

    assert_response :ok
    body = response.parsed_body
    assert_kind_of Array, body

    event = body.first
    if event
      %w[id ip user_agent created_at download_link_id buyer_email product_name].each do |key|
        assert event.key?(key), "expected event to include #{key}"
      end
    end
  end

  test "GET /api/v1/download_events includes correct associations" do
    event_fixture = download_events(:one)
    get api_v1_download_events_url, as: :json

    body = response.parsed_body
    event = body.find { |e| e["id"] == event_fixture.id }
    assert event, "expected the fixture event in the response"
    assert_equal event_fixture.ip, event["ip"]
    assert_equal products(:ebook).name, event["product_name"]
    assert_equal orders(:alice).buyer_email, event["buyer_email"]
  end

  test "dashboard root renders HTML with #dashboard mount point" do
    get root_url

    assert_response :ok
    assert_includes response.body, 'id="dashboard"'
  end

  test "dashboard root shows a notice when the bundle is absent" do
    # No Vite manifest in test (autoBuild: false), so the page shows the fallback.
    get root_url

    assert_response :ok
    assert_includes response.body, "Dashboard frontend not built"
  end

  test "GET /api/v1/orders caps feed at 50 most recent" do
    Order.update_all(created_at: 2.years.ago)

    product = products(:ebook)
    51.times do |i|
      order = Order.create!(product: product, buyer_email: "cap-#{i}@example.com")
      order.create_download_link!(
        token_digest: Digest::SHA256.hexdigest("cap-feed-#{i}"),
        expires_at: 1.day.from_now,
        max_downloads: 3
      )
      order.update_column(:created_at, i.hours.ago)
    end

    get api_v1_orders_url, as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal 50, body.size
    emails = body.map { |o| o["buyer_email"] }
    assert_includes emails, "cap-0@example.com"
    assert_not_includes emails, "cap-50@example.com"
  end

  test "GET /api/v1/download_events caps feed at 100 most recent" do
    DownloadEvent.update_all(created_at: 2.years.ago)

    link = download_links(:active)
    101.times do |i|
      DownloadEvent.create!(
        download_link: link,
        ip: "10.0.0.#{i % 255}",
        created_at: i.minutes.ago
      )
    end

    get api_v1_download_events_url, as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal 100, body.size

    newest = body.max_by { |e| Time.iso8601(e["created_at"]) }
    oldest_in_feed = body.min_by { |e| Time.iso8601(e["created_at"]) }
    assert_in_delta Time.current, Time.iso8601(newest["created_at"]), 2.seconds
    assert_operator Time.iso8601(oldest_in_feed["created_at"]), :>, 100.minutes.ago
  end

  test "dashboard feeds return unauthorized when DASHBOARD_TOKEN is set and missing" do
    with_env("DASHBOARD_TOKEN" => "secret-token") do
      get api_v1_products_url, as: :json
      assert_response :unauthorized
      assert_equal "unauthorized", response.parsed_body.dig("error", "code")
    end
  end

  test "dashboard feeds accept bearer token when DASHBOARD_TOKEN is set" do
    with_env("DASHBOARD_TOKEN" => "secret-token") do
      get api_v1_products_url,
        headers: { "Authorization" => "Bearer secret-token" },
        as: :json

      assert_response :ok
    end
  end
end
