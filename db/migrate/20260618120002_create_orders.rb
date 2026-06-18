class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      # on_delete: :restrict — an order is a financial record; deleting a product
      # out from under its orders would orphan history, so the DB blocks it.
      t.references :product, null: false, foreign_key: { on_delete: :restrict }
      t.string :buyer_email, null: false

      t.timestamps
    end
  end
end
