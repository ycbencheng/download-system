require "test_helper"

class DownloadLinkTest < ActiveSupport::TestCase
  def valid_attributes
    order = Order.create!(product: products(:ebook), buyer_email: "link-fixture-#{SecureRandom.hex(4)}@example.com")
    {
      order: order,
      token_digest: "a_unique_digest_#{SecureRandom.hex(4)}",
      expires_at: 24.hours.from_now,
      max_downloads: 3
    }
  end

  test "valid with required attributes and a default count of zero" do
    link = DownloadLink.new(valid_attributes)
    assert link.valid?
    link.save!
    assert_equal 0, link.download_count
  end

  test "requires an order" do
    link = DownloadLink.new(valid_attributes.except(:order))
    assert_not link.valid?
    assert_includes link.errors[:order], "must exist"
  end

  test "requires a token_digest" do
    link = DownloadLink.new(valid_attributes.merge(token_digest: nil))
    assert_not link.valid?
    assert_includes link.errors[:token_digest], "can't be blank"
  end

  test "token_digest is unique" do
    duplicate = DownloadLink.new(valid_attributes.merge(token_digest: download_links(:active).token_digest))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:token_digest], "has already been taken"
  end

  test "db enforces token_digest uniqueness even when validations are bypassed" do
    duplicate = DownloadLink.new(valid_attributes.merge(token_digest: download_links(:active).token_digest))
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "requires expires_at" do
    link = DownloadLink.new(valid_attributes.merge(expires_at: nil))
    assert_not link.valid?
    assert_includes link.errors[:expires_at], "can't be blank"
  end

  test "max_downloads must be a positive integer" do
    assert_not DownloadLink.new(valid_attributes.merge(max_downloads: 0)).valid?
    assert_not DownloadLink.new(valid_attributes.merge(max_downloads: nil)).valid?
  end

  test "download_count cannot be negative" do
    assert_not DownloadLink.new(valid_attributes.merge(download_count: -1)).valid?
  end

  test "db rejects a negative download_count that bypasses validations" do
    link = DownloadLink.new(valid_attributes.merge(download_count: -1))
    assert_raises(ActiveRecord::StatementInvalid) { link.save!(validate: false) }
  end

  test "db rejects download_count above max_downloads when validations are bypassed" do
    link = DownloadLink.new(valid_attributes.merge(download_count: 4, max_downloads: 3))
    assert_raises(ActiveRecord::StatementInvalid) { link.save!(validate: false) }
  end

  test "status prefers expired over limit_reached" do
    link = download_links(:maxed)
    link.update_columns(expires_at: 1.hour.ago)

    assert_equal :expired, link.status
  end

  test "status returns limit_reached when count equals max" do
    assert_equal :limit_reached, download_links(:maxed).status
  end

  test "status returns active label for ok links" do
    assert_equal "active", download_links(:active).status_label
  end

  test "status returns revoked for revoked links" do
    assert_equal :revoked, download_links(:revoked).status
  end

  test "revoked? is false until revoked" do
    assert_not download_links(:active).revoked?
  end

  test "revoke! stamps revoked_at and marks the link revoked" do
    link = download_links(:active)
    freeze_time do
      link.revoke!
      assert link.revoked?
      assert_equal Time.current, link.revoked_at
    end
  end

  test "revoke! preserves original revoked_at on second call" do
    link = download_links(:active)

    freeze_time do
      link.revoke!
    end
    first_revoked_at = link.revoked_at

    travel 1.hour do
      link.revoke!
    end

    assert_equal first_revoked_at, link.reload.revoked_at
  end

  test "cannot be destroyed while it has download events" do
    assert_raises(ActiveRecord::DeleteRestrictionError) { download_links(:active).destroy! }
  end
end
