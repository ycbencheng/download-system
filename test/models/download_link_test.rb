require "test_helper"

class DownloadLinkTest < ActiveSupport::TestCase
  def valid_attributes
    {
      order: orders(:alice),
      token_digest: "a_unique_digest",
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

  test "cannot be destroyed while it has download events" do
    assert_raises(ActiveRecord::DeleteRestrictionError) { download_links(:active).destroy! }
  end
end
