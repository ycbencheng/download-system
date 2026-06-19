require "test_helper"

class DownloadDeliveryTest < ActiveSupport::TestCase
  test "returns the absolute path under storage/product_files when the file exists" do
    product = products(:ebook) # file_name: sample.pdf, present on disk

    path = DownloadDelivery.path_for(product)

    assert_equal DownloadDelivery::ROOT.join("sample.pdf"), path
    assert path.file?, "resolved path should point at a real file"
  end

  test "returns nil when the product file is absent (no silent fallback)" do
    product = Product.new(file_name: "missing-on-disk.zip")

    assert_nil DownloadDelivery.path_for(product)
  end

  test "returns nil when the product has no file_name" do
    assert_nil DownloadDelivery.path_for(Product.new(file_name: nil))
    assert_nil DownloadDelivery.path_for(Product.new(file_name: ""))
  end

  test "strips path traversal from file_name" do
    product = Product.new(file_name: "../../config/database.yml")

    # File.basename collapses to database.yml, which is not under ROOT, so nil.
    assert_nil DownloadDelivery.path_for(product)
  end
end
