class Transaction < ApplicationRecord
  belongs_to :from_account, class_name: "Account"
  belongs_to :to_account, class_name: "Account", optional: true
  belongs_to :category
  belongs_to :transaction_group, optional: true

  validates :description, :amount, :event_date, :payment_date, :transaction_type, presence: true
  validates :transaction_type, inclusion: { in: %w[income expense] }

  scope :income, -> { where transaction_type: :income }
  scope :expense, -> { where transaction_type: :expense }
  scope :pending, -> { where status: :pending }
  scope :confirmed, -> { where status: :confirmed }
  
  # Scopes que trabalham com Date usando ranges (mais eficiente)
  scope :in_competence_month, ->(date) { 
    month_start = date.beginning_of_month
    month_end = date.end_of_month
    where(event_date: month_start..month_end)
  }
  scope :in_payment_month, ->(date) { 
    month_start = date.beginning_of_month
    month_end = date.end_of_month
    where(payment_date: month_start..month_end)
  }
  
  # Scope para próximos compromissos
  scope :upcoming_payments, ->(limit = 5) {
    where(status: :pending)
      .where('payment_date >= ?', Date.current)
      .order(:payment_date)
      .limit(limit)
  }

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