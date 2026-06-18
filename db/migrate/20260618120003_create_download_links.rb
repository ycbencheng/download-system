class CreateDownloadLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :download_links do |t|
      t.references :order, null: false, foreign_key: { on_delete: :restrict }
      # We store only SHA256(token); the raw token lives in the emailed URL.
      # Unique index doubles as the lookup path (indexed equality on the digest).
      t.string :token_digest, null: false
      # Snapshot of the product's settings at issue time so later product edits
      # never change the terms of an already-issued link.
      t.datetime :expires_at, null: false
      t.integer :max_downloads, null: false
      t.integer :download_count, null: false, default: 0
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :download_links, :token_digest, unique: true
    # The atomic confirm UPDATE relies on the count never going negative; the DB
    # CHECK is the last line of defense behind the conditional WHERE clause.
    add_check_constraint :download_links, "download_count >= 0", name: "download_links_count_non_negative"
  end
end
