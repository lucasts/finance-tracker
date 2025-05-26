class Category < ApplicationRecord
  belongs_to :category_group
  has_many :transactions, dependent: :restrict_with_error

  validates :name, presence: true
  validates :category_group_id, presence: true

  default_scope { includes(:category_group).order(:name) }
end
