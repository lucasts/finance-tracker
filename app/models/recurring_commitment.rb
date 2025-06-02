# == RecurringCommitment
# Compromisso recorrente (fixo ou variável)
# - name: string
# - category_id: referência obrigatória
# - default_amount: decimal (opcional)
# - recurrence_frequency: string (ex: 'monthly', 'weekly', 'annual')
# - start_date: date
# - end_date: date (opcional)
# - status: enum { active: 0, paused: 1, closed: 2 }
# - notes: text (opcional)
#
# Relacionamento: tem muitas transactions (via recurring_commitment_id)
class RecurringCommitment < ApplicationRecord
  belongs_to :category
  has_many :transactions, dependent: :restrict_with_error

  enum status: { active: 0, paused: 1, closed: 2 }

  validates :name, :category_id, :recurrence_frequency, :start_date, :status, presence: true
  validates :recurrence_frequency, inclusion: { in: %w[monthly weekly annual] }, allow_blank: true
  validates :default_amount, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes úteis
  scope :active_commitments, -> { where(status: :active) }
  scope :by_frequency, ->(freq) { where(recurrence_frequency: freq) }
  scope :monthly_commitments, -> { where(recurrence_frequency: 'monthly') }
  scope :with_default_amount, -> { where.not(default_amount: nil) }

  # Commitments que ainda estão no período ativo
  scope :current_active, -> do
    where(status: :active)
      .where('start_date <= ?', Date.current)
      .where('end_date IS NULL OR end_date >= ?', Date.current)
  end

  # Próxima data de vencimento baseada na frequência
  def next_occurrence_date(from_date = Date.current)
    return nil if closed? || (end_date && from_date > end_date)

    case recurrence_frequency
    when 'weekly'
      from_date.next_week
    when 'monthly'
      from_date.next_month
    when 'annual'
      from_date.next_year
    else
      from_date.next_month # default monthly
    end
  end

  # Verifica se está ativo no período
  def active_on?(date = Date.current)
    active? &&
      date >= start_date &&
      (end_date.nil? || date <= end_date)
  end

  # Valor médio das transações associadas
  def average_amount
    return default_amount if transactions.empty? && default_amount.present?

    confirmed_transactions = transactions.where(status: 'confirmed')
    return 0 if confirmed_transactions.empty?

    confirmed_transactions.average(:amount)&.round(2) || 0
  end

  # Total gasto neste compromisso
  def total_spent
    transactions.where(status: 'confirmed').sum(:amount)
  end

  # Última transação registrada
  def last_transaction
    transactions.order(:payment_date).last
  end

  # Próxima transação esperada (se houver)
  def next_expected_transaction
    transactions.where('payment_date > ?', Date.current).order(:payment_date).first
  end

  # Status resumido do compromisso
  def summary_status
    return 'expired' if end_date && end_date < Date.current
    return 'inactive' unless active?
    return 'not_started' if start_date > Date.current

    last_tx = last_transaction
    if last_tx
      next_due = next_occurrence_date(last_tx.payment_date)
      return 'overdue' if next_due && next_due < Date.current
    end

    'active'
  end

  # Calculate next occurrence after a specific date
  def next_occurrence_after(date)
    case frequency
    when 'weekly'
      date + 1.week
    when 'monthly'
      date + 1.month
    when 'quarterly'
      date + 3.months
    when 'yearly'
      date + 1.year
    else
      date + 1.month # default to monthly
    end
  end

  # Get analysis for this commitment's spending pattern
  def expense_analysis(timeframe_months: 12)
    return nil unless category.present?

    VariableExpenseAnalysisService.new(
      category,
      timeframe_months: timeframe_months
    ).call
  end

  # Check if this commitment generates variable expenses that should be analyzed
  def generates_variable_expenses?
    variable_categories = ['supermercado', 'farmácia', 'gasolina', 'consultas', 'mercado', 'combustível']
    variable_categories.any? { |keyword| name.downcase.include?(keyword) || category.name.downcase.include?(keyword) }
  end

  # Documentação:
  # - O valor padrão pode ser sobrescrito por cada transação (recorrente variável)
  # - O sistema gera transações periodicamente conforme frequência e status
end