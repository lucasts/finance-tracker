class CategoryGroup < ApplicationRecord
  has_many :categories, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
