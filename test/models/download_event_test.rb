require "test_helper"

class DownloadEventTest < ActiveSupport::TestCase
  test "valid with a download link" do
    event = DownloadEvent.new(download_link: download_links(:active), ip: "127.0.0.1", user_agent: "curl/8.0")
    assert event.valid?
  end

  test "requires a download link" do
    event = DownloadEvent.new(ip: "127.0.0.1")
    assert_not event.valid?
    assert_includes event.errors[:download_link], "must exist"
  end

  test "ip and user_agent are optional" do
    event = DownloadEvent.new(download_link: download_links(:active))
    assert event.valid?
  end
end
