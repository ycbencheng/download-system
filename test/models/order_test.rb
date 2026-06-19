require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "valid with a product and a well-formed email" do
    assert Order.new(product: products(:ebook), buyer_email: "buyer@example.com").valid?
  end

  test "requires a product" do
    order = Order.new(buyer_email: "buyer@example.com")
    assert_not order.valid?
    assert_includes order.errors[:product], "must exist"
  end

  test "requires a buyer_email" do
    order = Order.new(product: products(:ebook), buyer_email: nil)
    assert_not order.valid?
    assert_includes order.errors[:buyer_email], "can't be blank"
  end

  test "rejects malformed buyer_email" do
    %w[nope buyer@ @example.com buyer example.com buyer@@example.com].each do |bad|
      order = Order.new(product: products(:ebook), buyer_email: bad)
      assert_not order.valid?, "expected #{bad.inspect} to be invalid"
    end
  end

  test "accepts a variety of well-formed emails" do
    %w[a@b.co buyer+tag@sub.example.com first.last@example.io].each do |ok|
      order = Order.new(product: products(:ebook), buyer_email: ok)
      assert order.valid?, "expected #{ok.inspect} to be valid"
    end
  end

  test "cannot be destroyed while it has a download link" do
    assert_raises(ActiveRecord::DeleteRestrictionError) { orders(:alice).destroy! }
  end
end
