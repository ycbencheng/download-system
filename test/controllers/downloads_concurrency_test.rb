require "test_helper"

class DownloadsConcurrencyTest < ActionDispatch::IntegrationTest
  # Transactional fixtures wrap each test in a DB transaction that other threads
  # cannot see — a concurrency test inside that bubble is a false positive.
  self.use_transactional_tests = false

  # This class fans out threads internally; do not also split it across workers.
  parallelize(workers: 1)

  MAX_DOWNLOADS = 5
  THREAD_COUNT = 10 # fixed 2× overshoot so exactly MAX_DOWNLOADS should win
  REQUIRED_POOL = THREAD_COUNT + 5

  setup do
    ensure_connection_pool!(REQUIRED_POOL)

    @product = Product.create!(
      name: "Concurrency Ebook",
      file_name: "concurrency.pdf",
      expiry_hours: 24,
      max_downloads: MAX_DOWNLOADS
    )
    @order = Order.create!(product: @product, buyer_email: "race@example.com")
    @token = "concurrency-race-token"
    @link = DownloadLink.create!(
      order: @order,
      token_digest: Digest::SHA256.hexdigest(@token),
      expires_at: 1.hour.from_now,
      max_downloads: MAX_DOWNLOADS,
      download_count: 0
    )
  end

  teardown do
    DownloadEvent.where(download_link_id: @link.id).delete_all if @link
    @link&.destroy
    @order&.destroy
    @product&.destroy
  end

  test "parallel POST /d/:token yields exactly max_downloads successes under race" do
    confirm_path = download_confirm_path(token: @token)
    barrier = Concurrent::CyclicBarrier.new(THREAD_COUNT + 1)
    results = Concurrent::Array.new

    threads = THREAD_COUNT.times.map do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.wait

          session = ActionDispatch::Integration::Session.new(Rails.application)
          session.post(confirm_path, headers: { "User-Agent" => "RaceThread-#{i}" })
          results << session.response.status.to_i
        end
      end
    end

    barrier.wait
    threads.each(&:join)

    successes = results.count(302)
    rejections = results.count(403)

    assert_equal THREAD_COUNT, results.size, "every thread should report a status"
    assert_equal MAX_DOWNLOADS, successes,
      "expected exactly #{MAX_DOWNLOADS} redirects, got #{successes} (#{results.tally.inspect})"
    assert_equal THREAD_COUNT - MAX_DOWNLOADS, rejections,
      "expected #{THREAD_COUNT - MAX_DOWNLOADS} limit rejections, got #{rejections}"
    assert_equal MAX_DOWNLOADS, @link.reload.download_count
    assert_equal MAX_DOWNLOADS, DownloadEvent.where(download_link: @link).count
  end

  private

  def ensure_connection_pool!(minimum)
    config = ActiveRecord::Base.connection_db_config
    hash = config.configuration_hash
    current = hash[:max_connections] || hash[:pool] || ActiveRecord::Base.connection_pool.size

    return if current >= minimum

    merged = hash.except(:pool, :max_connections).merge(max_connections: minimum)
    ActiveRecord::Base.establish_connection(merged)
  end
end
