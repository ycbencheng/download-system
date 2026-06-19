class AddOutcomeToDownloadEvents < ActiveRecord::Migration[8.1]
  # default: "success" keeps every existing audit row (seeds, fixtures, prior
  # successful downloads) valid without a backfill. New failure attempts against
  # an existing link write expired / limit_reached / revoked.
  def change
    add_column :download_events, :outcome, :string, null: false, default: "success"
  end
end
