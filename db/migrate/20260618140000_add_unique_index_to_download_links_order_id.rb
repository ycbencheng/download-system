class AddUniqueIndexToDownloadLinksOrderId < ActiveRecord::Migration[8.1]
  def up
    say_with_time "deduplicating download_links per order (keep newest)" do
      execute <<~SQL.squish
        DELETE FROM download_events
        WHERE download_link_id IN (
          SELECT id FROM download_links
          WHERE id NOT IN (
            SELECT MAX(id) FROM download_links GROUP BY order_id
          )
        )
      SQL

      execute <<~SQL.squish
        DELETE FROM download_links
        WHERE id NOT IN (
          SELECT MAX(id) FROM download_links GROUP BY order_id
        )
      SQL
    end

    remove_index :download_links, :order_id, if_exists: true
    add_index :download_links, :order_id, unique: true
  end

  def down
    remove_index :download_links, :order_id
    add_index :download_links, :order_id
  end
end
