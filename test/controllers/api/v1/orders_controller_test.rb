require "test_helper"

class Api::V1::OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:ebook)
  end

  test "POST /api/v1/orders creates order and returns download URL" do
    assert_difference -> { Order.count } => 1, -> { DownloadLink.count } => 1 do
      post api_v1_orders_url, params: { product_id: @product.id, buyer_email: "buyer@example.com" }, as: :json
    end

    assert_response :created

    body = response.parsed_body
    assert body["order_id"].present?
    assert body["download_url"].present?
    assert body["expires_at"].present?
    assert_equal @product.max_downloads, body["max_downloads"]

    assert_match %r{/d/[A-Za-z0-9_-]{43}}, body["download_url"]

    order = Order.find(body["order_id"])
    assert_equal "buyer@example.com", order.buyer_email
    assert_equal @product, order.product

    link = order.download_links.first
    assert link.present?
    assert_equal 0, link.download_count
    assert_equal @product.max_downloads, link.max_downloads
    assert_in_delta order.created_at + @product.expiry_hours.hours, link.expires_at, 1.second
  end

  test "POST /api/v1/orders returns 404 for missing product" do
    assert_no_enqueued_emails do
      assert_no_difference "Order.count" do
        post api_v1_orders_url, params: { product_id: 0, buyer_email: "buyer@example.com" }, as: :json
      end
    end

    assert_response :not_found
    body = response.parsed_body
    assert_equal "not_found", body.dig("error", "code")
    assert_equal "Resource not found", body.dig("error", "message")
  end

  test "POST /api/v1/orders accepts nested order params (README curl shape)" do
    assert_difference -> { Order.count } => 1, -> { DownloadLink.count } => 1 do
      post api_v1_orders_url,
        params: { order: { product_id: @product.id, buyer_email: "nested@example.com" } },
        as: :json
    end

    assert_response :created
    assert_equal "nested@example.com", Order.find(response.parsed_body["order_id"]).buyer_email
  end

  test "POST /api/v1/orders retries on token digest collision" do
    attempts = 0
    original_save = DownloadLink.instance_method(:save!)
    DownloadLink.define_method(:save!) do |*args, **kwargs, &block|
      if new_record?
        attempts += 1
        raise ActiveRecord::RecordNotUnique.new("PG::UniqueViolation") if attempts == 1
      end

      original_save.bind(self).call(*args, **kwargs, &block)
    end

    assert_difference -> { Order.count } => 1, -> { DownloadLink.count } => 1 do
      post api_v1_orders_url,
        params: { product_id: @product.id, buyer_email: "collision@example.com" },
        as: :json
    end

    assert_response :created
    assert_equal 2, attempts
  ensure
    DownloadLink.define_method(:save!, original_save) if original_save
  end

  test "POST /api/v1/orders returns 422 for invalid email" do
    assert_no_enqueued_emails do
      assert_no_difference "Order.count" do
        post api_v1_orders_url, params: { product_id: @product.id, buyer_email: "not-an-email" }, as: :json
      end
    end

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_equal "validation_failed", body.dig("error", "code")
  end

  test "POST /api/v1/orders returns 422 for missing buyer_email" do
    assert_no_enqueued_emails do
      assert_no_difference "Order.count" do
        post api_v1_orders_url, params: { product_id: @product.id }, as: :json
      end
    end

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_equal "validation_failed", body.dig("error", "code")
  end

  test "POST /api/v1/orders enqueues email delivery" do
    assert_enqueued_emails 1 do
      post api_v1_orders_url, params: { product_id: @product.id, buyer_email: "buyer@example.com" }, as: :json
    end
  end

  test "POST /api/v1/orders email contains the download URL" do
    post api_v1_orders_url, params: { product_id: @product.id, buyer_email: "buyer@example.com" }, as: :json
    assert_response :created

    download_url = response.parsed_body["download_url"]

    perform_enqueued_jobs

    mail = ActionMailer::Base.deliveries.last
    assert_equal ["buyer@example.com"], mail.to
    assert_includes mail.html_part.decoded, download_url
    assert_includes mail.text_part.decoded, download_url
  end

  test "POST /api/v1/orders stores token digest not raw token" do
    post api_v1_orders_url, params: { product_id: @product.id, buyer_email: "buyer@example.com" }, as: :json
    assert_response :created

    download_url = response.parsed_body["download_url"]
    raw_token = download_url.split("/d/").last

    link = Order.last.download_links.first
    expected_digest = Digest::SHA256.hexdigest(raw_token)
    assert_equal expected_digest, link.token_digest
  end

  test "POST /api/v1/orders ignores spoofed Host header when building download_url" do
    post api_v1_orders_url,
      params: { product_id: @product.id, buyer_email: "buyer@example.com" },
      headers: { "Host" => "evil.com" },
      as: :json

    assert_response :created
    download_url = response.parsed_body["download_url"]
    assert_includes download_url, "example.com"
    assert_not_includes download_url, "evil.com"
  end

  test "POST /api/v1/orders rolls back order when link creation fails" do
    original_save = DownloadLink.instance_method(:save!)
    DownloadLink.define_method(:save!) do |*args, **kwargs, &block|
      if new_record?
        errors.add(:base, "simulated failure")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      original_save.bind(self).call(*args, **kwargs, &block)
    end

    assert_no_difference "Order.count" do
      post api_v1_orders_url,
        params: { product_id: @product.id, buyer_email: "buyer@example.com" },
        as: :json
    end

    assert_response :unprocessable_entity
  ensure
    DownloadLink.define_method(:save!, original_save) if original_save
  end
end
