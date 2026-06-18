class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :file_name, null: false
      t.integer :expiry_hours, null: false
      t.integer :max_downloads, null: false

      t.timestamps
    end

    # Download settings must be strictly positive; enforce at the DB level so a
    # bad backfill or a bypassed model can't create an unusable product.
    add_check_constraint :products, "expiry_hours > 0", name: "products_expiry_hours_positive"
    add_check_constraint :products, "max_downloads > 0", name: "products_max_downloads_positive"
  end
end
