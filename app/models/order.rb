class Order < ApplicationRecord
  belongs_to :product
  has_one :download_link, dependent: :restrict_with_exception

  # Standard-library email format check — rejects obvious invalid addresses.
  validates :buyer_email, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
end
