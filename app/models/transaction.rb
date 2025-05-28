class Transaction < ApplicationRecord
  belongs_to :from_account, class_name: "Account"
  belongs_to :to_account, class_name: "Account", optional: true
  belongs_to :category
  belongs_to :transaction_group, optional: true

  validates :description, :amount, :event_date, :payment_date, :transaction_type, presence: true
  validates :transaction_type, inclusion: { in: %w[income expense] }

  scope :income, -> { where transaction_type: :income }
  scope :expense, -> { where transaction_type: :expense }
  scope :in_competence_month, ->(ym) { where("strftime('%Y-%m', event_date) = ?", ym) }
  scope :in_payment_month, ->(ym) { where("strftime('%Y-%m', payment_date) = ?", ym) }

  enum :status, { pending: 0, confirmed: 1, cancelled: 2 }
  enum :recurrence_type, { single: 0, fixed: 1, recurring: 2 }
  
  # Deriva competência (YYYY-MM) a partir do event_date
  def competence_month
    event_date.strftime('%Y-%m') if event_date.present?
  end

  # # Deriva o mês do pagamento (padrão: payment_date, fallback para event_date)
  def payment_month
    (payment_date || event_date)&.strftime('%Y-%m')
  end
end