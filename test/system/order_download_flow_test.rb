require "application_system_test_case"

class OrderDownloadFlowTest < ApplicationSystemTestCase
  test "buyer can order via API, visit landing page, and confirm the download" do
    product = products(:ebook)

    api = ActionDispatch::Integration::Session.new(Rails.application)
    api.post(
      api_v1_orders_path,
      params: { order: { product_id: product.id, buyer_email: "flow@example.com" } }.to_json,
      headers: { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
    )

    assert_equal 201, api.response.status, api.response.body

    body = JSON.parse(api.response.body)
    link = Order.find(body["order_id"]).download_link

    visit body["download_url"]

    assert_text "Your download is ready"
    assert_text product.name

    # The file streams via send_file (not a navigable redirect), so we assert the
    # click reached the confirm action by its effect: one consumed download.
    # Byte-level delivery (200 + Content-Disposition) is covered in the
    # DownloadsController integration test.
    assert_difference -> { link.reload.download_count }, 1 do
      click_button "Download"
    end
  end
end
