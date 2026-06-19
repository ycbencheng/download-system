# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_18_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "download_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "download_link_id", null: false
    t.string "ip"
    t.string "user_agent"
    t.index ["download_link_id", "created_at"], name: "index_download_events_on_download_link_id_and_created_at"
    t.index ["download_link_id"], name: "index_download_events_on_download_link_id"
  end

  create_table "download_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "download_count", default: 0, null: false
    t.datetime "expires_at", null: false
    t.integer "max_downloads", null: false
    t.bigint "order_id", null: false
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_download_links_on_order_id", unique: true
    t.index ["token_digest"], name: "index_download_links_on_token_digest", unique: true
    t.check_constraint "download_count <= max_downloads", name: "download_links_count_within_max"
    t.check_constraint "download_count >= 0", name: "download_links_count_non_negative"
  end

  create_table "orders", force: :cascade do |t|
    t.string "buyer_email", null: false
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_orders_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "expiry_hours", null: false
    t.string "file_name", null: false
    t.integer "max_downloads", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "expiry_hours > 0", name: "products_expiry_hours_positive"
    t.check_constraint "max_downloads > 0", name: "products_max_downloads_positive"
  end

  add_foreign_key "download_events", "download_links", on_delete: :restrict
  add_foreign_key "download_links", "orders", on_delete: :restrict
  add_foreign_key "orders", "products", on_delete: :restrict
end
