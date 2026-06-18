class DownloadLink < ApplicationRecord
  belongs_to :order
  has_many :download_events, dependent: :restrict_with_exception

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :max_downloads, presence: true,
    numericality: { only_integer: true, greater_than: 0 }
  validates :download_count, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def revoked?
    revoked_at.present?
  end

  # Refund/chargeback kill switch. Enforcement of revocation happens atomically
  # in the confirm UPDATE (revoked_at IS NULL in the WHERE clause); this just
  # stamps the row. Triggered from console/rake — the dashboard stays read-only.
  def revoke!
    update!(revoked_at: Time.current)
  end
end
