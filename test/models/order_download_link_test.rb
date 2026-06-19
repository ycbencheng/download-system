require "test_helper"

class OrderDownloadLinkTest < ActiveSupport::TestCase
  test "enforces one download link per order at the database level" do
    order = Order.create!(product: products(:ebook), buyer_email: "one-link@example.com")
    order.create_download_link!(
      token_digest: Digest::SHA256.hexdigest("first"),
      expires_at: 1.day.from_now,
      max_downloads: 3
    )

    duplicate = DownloadLink.new(
      order: order,
      token_digest: Digest::SHA256.hexdigest("second"),
      expires_at: 1.day.from_now,
      max_downloads: 3
    )

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save! }
  end

  test "order and link roll back together when link creation fails inside a transaction" do
    assert_no_difference "Order.count" do
      assert_raises(ActiveRecord::RecordInvalid) do
        Order.transaction do
          order = Order.create!(product: products(:ebook), buyer_email: "rollback-tx@example.com")
          order.create_download_link!(
            token_digest: Digest::SHA256.hexdigest("rollback-tx"),
            expires_at: 1.day.from_now,
            max_downloads: 0
          )
        end
      end
    end
  end
end
