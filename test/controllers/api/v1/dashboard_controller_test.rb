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
end
