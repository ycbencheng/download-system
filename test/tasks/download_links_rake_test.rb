require "test_helper"
require "rake"

class DownloadLinksRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("download_links:revoke")
  end

  test "revoke task sets revoked_at on the given link" do
    link = download_links(:active)
    assert_not link.revoked?

    freeze_time do
      Rake::Task["download_links:revoke"].reenable
      assert_output(/revoked at/) do
        Rake::Task["download_links:revoke"].invoke(link.id)
      end

      link.reload
      assert link.revoked?
      assert_equal Time.current, link.revoked_at
    end
  end

  test "revoke task prints already-revoked message for a revoked link" do
    link = download_links(:revoked)
    assert link.revoked?

    Rake::Task["download_links:revoke"].reenable
    assert_output(/already revoked/) do
      Rake::Task["download_links:revoke"].invoke(link.id)
    end
  end

  test "revoke task aborts when no ID is given" do
    Rake::Task["download_links:revoke"].reenable
    assert_raises(SystemExit) do
      capture_io { Rake::Task["download_links:revoke"].invoke(nil) }
    end
  end

  test "revoke task raises for a non-existent ID" do
    Rake::Task["download_links:revoke"].reenable
    assert_raises(ActiveRecord::RecordNotFound) do
      Rake::Task["download_links:revoke"].invoke(0)
    end
  end
end
