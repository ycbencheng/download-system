class CreateDownloadEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :download_events do |t|
      t.references :download_link, null: false, foreign_key: { on_delete: :restrict }
      t.string :ip
      t.string :user_agent

      # Audit rows are append-only and best-effort; created_at is all we need
      # (no updated_at).
      t.datetime :created_at, null: false
    end

    add_index :download_events, [ :download_link_id, :created_at ]
  end
end
