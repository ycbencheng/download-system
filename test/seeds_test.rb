require "test_helper"

# Verifies that running `rails db:seed` produces the four demo download
# links advertised in the README, each in a distinct state. Manual seed
# verification is fragile (easy to drift between code and docs); this test
# keeps the demo URLs honest in CI.
#
# Seeds run inside the default transactional fixture wrapper, so the rows
# they create are rolled back at the end of each test.
class SeedsTest < ActionDispatch::IntegrationTest
  setup do
    original_stdout = $stdout
    $stdout = StringIO.new
    begin
      Rails.application.load_seed
    ensure
      $stdout = original_stdout
    end
  end

  test "normal seeded link renders the landing page with a Download button" do
    get download_landing_url(token: "dev-active-link-token")

    assert_response :success
    assert_includes response.body, "Download"
    assert_includes response.body, 'method="post"'
  end

  test "pre-expired seeded link returns 410 expired" do
    get download_landing_url(token: "dev-expired-link-token")

    assert_response :gone
    assert_includes response.body, "expired"
  end

  test "pre-maxed seeded link returns 403 limit reached" do
    get download_landing_url(token: "dev-maxed-link-token")

    assert_response :forbidden
    assert_includes response.body, "limit"
  end

  test "revoked seeded link returns 410 revoked" do
    get download_landing_url(token: "dev-revoked-link-token")

    assert_response :gone
    assert_includes response.body, "revoked"
  end

  test "stub file exists under storage/product_files for the gated POST stream" do
    stub = DownloadDelivery::ROOT.join("sample.pdf")
    assert stub.file?, "expected #{stub} to exist as the streamed download target"

    # The bytes must NOT be reachable from public/ — gating is the whole point.
    assert_not Rails.public_path.join("downloads", "sample.pdf").exist?,
      "sample.pdf must not live under public/ (it would bypass token gating)"
  end
end
