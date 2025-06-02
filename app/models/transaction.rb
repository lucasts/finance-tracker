class Transaction < ApplicationRecord
  belongs_to :from_account, class_name: "Account"
  belongs_to :to_account, class_name: "Account", optional: true
  belongs_to :category
  belongs_to :transaction_group, optional: true
  belongs_to :credit_statement, optional: true

  validates :description, :amount, :event_date, :payment_date, :transaction_type, presence: true
  validates :transaction_type, inclusion: { in: %w[income expense] }
  validates :status, inclusion: { in: %w[pending confirmed cancelled] }
  
  # Callbacks para automação do status
  before_validation :set_default_status, if: :new_record?
  before_save :auto_update_status_if_needed
  
  scope :income, -> { where transaction_type: :income }
  scope :expense, -> { where transaction_type: :expense }
  scope :pending, -> { where status: :pending }
  scope :confirmed, -> { where status: :confirmed }
  scope :cancelled, -> { where status: :cancelled }
  
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
  
  scope :upcoming_payments, ->(limit = 10) {
  where(status: ['pending', 'confirmed'])
    .where('event_date > ?', Date.current)
    .where('event_date <= ?', 1.months.from_now)
    .order(:event_date)
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
  
  # Método para determinar se a transação é futura
  def future_transaction?
    payment_date && payment_date > Date.current
  end
  
  # Método para verificar se deveria estar pendente
  def should_be_pending?
    future_transaction? && !cancelled?
  end
  
  # Método para verificar se deveria estar confirmada
  def should_be_confirmed?
    !future_transaction? && !cancelled?
  end
  
  private
  
  def set_default_status
    return if status.present?
    
    self.status = determine_automatic_status
  end
  
  def auto_update_status_if_needed
    # Só atualiza automaticamente se não foi explicitamente cancelada
    return if cancelled?
    
    # Se as datas mudaram, recalcula o status
    if payment_date_changed? || event_date_changed?
      new_status = determine_automatic_status
      self.status = new_status unless status == 'cancelled'
    end
  end
  
  def determine_automatic_status
    current_date = Date.current
    check_date = payment_date || event_date
    
    if check_date && check_date > current_date
      'pending'    # Transação futura
    else
      'confirmed'  # Transação atual ou passada
    end
  end
end