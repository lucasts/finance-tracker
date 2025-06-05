class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associações
  has_many :transactions, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :recurring_commitments, dependent: :destroy
  has_many :installment_plans, dependent: :destroy
  has_many :import_sessions, dependent: :nullify
  has_many :reconciliation_entries, dependent: :nullify

  validates :email, presence: true, uniqueness: true
end
