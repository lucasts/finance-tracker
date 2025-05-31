class CreditStatement < ApplicationRecord
  belongs_to :account
  has_many :transactions, dependent: :nullify

  enum status: { open: 0, paid: 1, overdue: 2 }

  validates :month, presence: true, format: { with: /\A\d{4}-\d{2}\z/ }
  validates :amount_due, :amount_paid, presence: true
  validate :account_must_be_credit_card
  
  before_save :auto_update_status
  after_save :update_amount_due

  def remaining_balance
    amount_due - amount_paid
  end

  private

  def account_must_be_credit_card
    if account&.account_type&.code != "CREDIT"
      errors.add(:account, "deve ser uma conta do tipo cartão de crédito")
    end
  end

  def auto_update_status
    if amount_paid >= amount_due
      self.status = :paid
      self.paid_on ||= Date.today
    elsif due_on.present? && due_on < Date.today && amount_paid < 0
      self.status = :overdue
    else
      self.status = :open
    end
  end

  def update_amount_due
    total = transactions.sum(:amount)
    update_column(:amount_due, total) if total != amount_due
  end
end