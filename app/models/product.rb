class Product < ApplicationRecord
  has_many :orders, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :file_name, presence: true
  validates :expiry_hours, presence: true,
    numericality: { only_integer: true, greater_than: 0 }
  validates :max_downloads, presence: true,
    numericality: { only_integer: true, greater_than: 0 }
end
