class Category < ApplicationRecord
  has_many :transactions, dependent: :restrict_with_error

  validates :name, presence: true
end
