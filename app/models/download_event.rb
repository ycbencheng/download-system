class DownloadEvent < ApplicationRecord
  belongs_to :download_link

  # Append-only audit table — only created_at exists (no updated_at column).
  def self.timestamp_attributes_for_update
    []
  end
end
