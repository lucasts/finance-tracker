class Transaction < ApplicationRecord
  # Associações de usuário
  belongs_to :user
  
  # Associações existentes
  belongs_to :from_account, class_name: "Account"
  belongs_to :to_account, class_name: "Account", optional: true
  belongs_to :category, optional: true
  belongs_to :credit_statement, optional: true
  
  # Associações para o modelo robusto
  belongs_to :recurring_commitment, optional: true
  belongs_to :installment_plan, optional: true

  validates :description, :amount, :event_date, :payment_date, :transaction_type, presence: true
  validates :status, inclusion: { in: %w[pending confirmed cancelled] }
  
  # Validação de exclusividade mútua - transação só pode pertencer a UM tipo
  validate :exclusive_association_validation
  
  # Validação para garantir compatibilidade entre transaction_type e category_type
  validate :category_type_compatibility
  
  # Validações específicas para transferências
  validate :accounts_for_transfer
  validate :category_for_transaction_type
  
  # Callbacks para automação do status
  before_validation :set_default_status, if: :new_record?
  before_save :auto_update_status_if_needed
  
  scope :income, -> { where transaction_type: :income }
  scope :expense, -> { where transaction_type: :expense }
  scope :transfer, -> { where transaction_type: :transfer }
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
  enum :transaction_type, { income: 0, expense: 1, transfer: 2 }
  enum :recurrence_type, { single: 0, recurring: 1, installment: 2 }
  
  scope :income, -> { where transaction_type: :income }
  scope :expense, -> { where transaction_type: :expense }
  scope :transfer, -> { where transaction_type: :transfer }
  scope :single_transactions, -> { where recurrence_type: :single }
  scope :from_recurring_commitment, ->(commitment) { where(recurring_commitment: commitment) }
  scope :from_installment_plan, ->(plan) { where(installment_plan: plan) }
  
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
  
  # Métodos auxiliares para classificação de transação
  def single_transaction?
    recurrence_type == 'single'
  end
  
  def recurring_transaction?
    recurrence_type == 'recurring' && recurring_commitment.present?
  end
  
  def installment_transaction?
    recurrence_type == 'installment' && installment_plan.present?
  end
  
  # Status de parcelamento (se aplicável)
  def installment_status
    return nil unless installment_transaction?
    return nil unless installment_plan.present?
    
    "#{installment_number}/#{installment_plan.installment_count}"
  end
  
  # Nome do compromisso ou plano associado
  def recurring_name
    return installment_plan.name if installment_transaction?
    return recurring_commitment.name if recurring_transaction?
    nil
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
      # Para parcelas de planos de parcelamento, usar lógica diferente
      if installment_plan.present? && installment_number.present?
        # Primeira parcela pode ser confirmada se for no passado/presente
        # Demais parcelas sempre pending até serem pagas manualmente
        if installment_number == 1 && check_date <= current_date
          'confirmed'
        else
          'pending'
        end
      else
        'confirmed'  # Transação atual ou passada (exceto parcelamentos)
      end
    end
  end
  
  # Validação de exclusividade mútua: uma transação só pode pertencer a um tipo
  def exclusive_association_validation
    associations = [recurring_commitment_id, installment_plan_id].compact
    
    if associations.size > 1
      errors.add(:base, "Transaction can only belong to one type: recurring commitment or installment plan")
    end
    
    # Validar consistência entre recurrence_type e associações
    case recurrence_type
    when 'recurring'
      unless recurring_commitment_id.present?
        errors.add(:recurring_commitment, "must be present for recurring transactions")
      end
    when 'installment'
      unless installment_plan_id.present?
        errors.add(:installment_plan, "must be present for installment transactions")
      end
    when 'single'
      if recurring_commitment_id.present? || installment_plan_id.present?
        errors.add(:base, "Single transactions cannot have recurring commitment or installment plan")
      end
    end
  end
  
  private
  
  def category_type_compatibility
    return unless category && transaction_type
    return if transfer? # Transferências não têm categoria
    
    expected_category_type = transaction_type == 'income' ? 'income' : 'expense'
    
    unless category.category_type == expected_category_type
      category_type_label = category.category_type == 'income' ? 'receita' : 'despesa'
      transaction_type_label = transaction_type == 'income' ? 'receita' : 'despesa'
      
      errors.add(:category, "é do tipo #{category_type_label}, mas a transação é do tipo #{transaction_type_label}")
    end
  end

  def accounts_for_transfer
    if transfer?
      if from_account_id.blank? || to_account_id.blank?
        errors.add(:base, "É necessário informar conta de origem e destino para transferências")
      end
      if from_account_id == to_account_id
        errors.add(:base, "Conta de origem e destino não podem ser iguais em uma transferência")
      end
    end
  end

  def category_for_transaction_type
    if transfer?
      errors.add(:category_id, "Transferência não deve ter categoria") if category_id.present?
    else
      errors.add(:category_id, "Categoria obrigatória") if category_id.blank?
    end
  end
end