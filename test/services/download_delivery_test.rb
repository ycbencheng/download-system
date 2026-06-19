require "test_helper"

class DownloadDeliveryTest < ActiveSupport::TestCase
  test "returns public path when product file exists under public/downloads" do
    product = products(:ebook)
    public_path = Rails.public_path.join("downloads", product.file_name)

    FileUtils.mkdir_p(public_path.dirname)
    FileUtils.cp(Rails.public_path.join("downloads", "sample.pdf"), public_path)

    assert_equal "/downloads/#{product.file_name}", DownloadDelivery.path_for(product)
  ensure
    public_path.delete if public_path&.exist?
  end

  test "falls back to sample.pdf when product file is absent" do
    product = Product.new(file_name: "missing-on-disk.zip")

    assert_equal DownloadDelivery::FALLBACK_PATH, DownloadDelivery.path_for(product)
  end
end
