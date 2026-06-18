require "test_helper"

class ProductTest < ActiveSupport::TestCase
  def valid_attributes
    { name: "Ebook", file_name: "ebook.pdf", expiry_hours: 24, max_downloads: 3 }
  end

  test "valid with all required attributes" do
    assert Product.new(valid_attributes).valid?
  end

  test "requires a name" do
    product = Product.new(valid_attributes.merge(name: nil))
    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
  end

  test "requires a file_name" do
    product = Product.new(valid_attributes.merge(file_name: nil))
    assert_not product.valid?
    assert_includes product.errors[:file_name], "can't be blank"
  end

  test "expiry_hours must be a positive integer" do
    assert_not Product.new(valid_attributes.merge(expiry_hours: 0)).valid?
    assert_not Product.new(valid_attributes.merge(expiry_hours: -1)).valid?
    assert_not Product.new(valid_attributes.merge(expiry_hours: 1.5)).valid?
    assert_not Product.new(valid_attributes.merge(expiry_hours: nil)).valid?
  end

  test "max_downloads must be a positive integer" do
    assert_not Product.new(valid_attributes.merge(max_downloads: 0)).valid?
    assert_not Product.new(valid_attributes.merge(max_downloads: -1)).valid?
    assert_not Product.new(valid_attributes.merge(max_downloads: 2.5)).valid?
    assert_not Product.new(valid_attributes.merge(max_downloads: nil)).valid?
  end

  test "db rejects a non-positive expiry_hours that bypasses validations" do
    product = Product.new(valid_attributes.merge(expiry_hours: 0))
    assert_raises(ActiveRecord::StatementInvalid) { product.save!(validate: false) }
  end

  test "cannot be destroyed while it has orders" do
    assert_raises(ActiveRecord::DeleteRestrictionError) { products(:ebook).destroy! }
  end
end
