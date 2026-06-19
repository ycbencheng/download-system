require "test_helper"

class Api::V1::ProductsControllerTest < ActionDispatch::IntegrationTest
  test "POST /api/v1/products creates a product" do
    assert_difference "Product.count", 1 do
      post api_v1_products_url,
        params: {
          product: {
            name: "New Ebook",
            file_name: "new.pdf",
            expiry_hours: 48,
            max_downloads: 5
          }
        },
        as: :json
    end

    assert_response :created

    body = response.parsed_body
    assert_equal "New Ebook", body["name"]
    assert_equal "new.pdf", body["file_name"]
    assert_equal 48, body["expiry_hours"]
    assert_equal 5, body["max_downloads"]
    assert body["id"].present?
    assert body["created_at"].present?
  end

  test "POST /api/v1/products accepts flat params" do
    assert_difference "Product.count", 1 do
      post api_v1_products_url,
        params: {
          name: "Flat Product",
          file_name: "flat.pdf",
          expiry_hours: 24,
          max_downloads: 3
        },
        as: :json
    end

    assert_response :created
    assert_equal "Flat Product", response.parsed_body["name"]
  end

  test "POST /api/v1/products returns 422 for missing name" do
    assert_no_difference "Product.count" do
      post api_v1_products_url,
        params: { product: { file_name: "x.pdf", expiry_hours: 24, max_downloads: 3 } },
        as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
  end

  test "POST /api/v1/products returns 422 for invalid expiry_hours" do
    assert_no_difference "Product.count" do
      post api_v1_products_url,
        params: {
          product: {
            name: "Bad",
            file_name: "x.pdf",
            expiry_hours: 0,
            max_downloads: 3
          }
        },
        as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
  end
end
