require "application_system_test_case"

class OrderDownloadFlowTest < ApplicationSystemTestCase
  test "buyer can order via API, visit landing page, and download" do
    product = products(:ebook)

    api = ActionDispatch::Integration::Session.new(Rails.application)
    api.post(
      api_v1_orders_path,
      params: { order: { product_id: product.id, buyer_email: "flow@example.com" } }.to_json,
      headers: { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
    )

    assert_equal 201, api.response.status, api.response.body

    download_url = JSON.parse(api.response.body)["download_url"]
    visit download_url

    assert_text "Your download is ready"
    assert_text product.name

    click_button "Download"

    assert_current_path "/downloads/sample.pdf"
  end
end
