# Service para edição avançada de compromissos recorrentes
# Permite modificar compromissos existentes com diferentes estratégias
class RecurringCommitmentEditorService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :recurring_commitment
  attribute :edit_strategy, :string, default: 'future_only'
  attribute :effective_date, :date, default: -> { Date.current }
  attribute :new_attributes, :hash, default: -> { {} }

  validates :recurring_commitment, presence: true
  validates :edit_strategy, inclusion: { in: %w[future_only all_transactions split_commitment] }
  validates :effective_date, presence: true
  validates :new_attributes, presence: true

  # Estratégias de edição:
  # - future_only: Aplica mudanças apenas às transações futuras
  # - all_transactions: Aplica mudanças a todas as transações (passadas e futuras)
  # - split_commitment: Cria um novo compromisso a partir da data efetiva
  
  def call
    return false unless valid?
    
    ActiveRecord::Base.transaction do
      case edit_strategy
      when 'future_only'
        edit_future_transactions_only
      when 'all_transactions'
        edit_all_transactions
      when 'split_commitment'
        split_commitment
      end
    end
    
    true
  rescue StandardError => e
    errors.add(:base, "Erro ao editar compromisso: #{e.message}")
    false
  end

  private

  def edit_future_transactions_only
    # Atualiza o compromisso com os novos atributos
    recurring_commitment.update!(filtered_new_attributes)
    
    # Atualiza transações futuras (incluindo a data efetiva)
    future_transactions = recurring_commitment.transactions.where('date >= ?', effective_date)
    
    future_transactions.find_each do |transaction|
      update_transaction_attributes(transaction)
    end
    
    Rails.logger.info "Updated #{future_transactions.count} future transactions for commitment #{recurring_commitment.id}"
  end

  def edit_all_transactions
    # Atualiza o compromisso com os novos atributos
    recurring_commitment.update!(filtered_new_attributes)
    
    # Atualiza todas as transações do compromisso
    all_transactions = recurring_commitment.transactions
    
    all_transactions.find_each do |transaction|
      update_transaction_attributes(transaction)
    end
    
    Rails.logger.info "Updated #{all_transactions.count} transactions for commitment #{recurring_commitment.id}"
  end

  def split_commitment
    # Desativa o compromisso original na data efetiva
    original_end_date = effective_date - 1.day
    recurring_commitment.update!(end_date: original_end_date)
    
    # Cria novo compromisso com os novos atributos
    new_commitment_attributes = recurring_commitment.attributes.except('id', 'created_at', 'updated_at')
                                                    .merge(filtered_new_attributes)
                                                    .merge(start_date: effective_date, end_date: nil)
    
    new_commitment = RecurringCommitment.create!(new_commitment_attributes)
    
    # Move transações futuras para o novo compromisso
    future_transactions = recurring_commitment.transactions.where('date >= ?', effective_date)
    
    future_transactions.find_each do |transaction|
      transaction.update!(recurring_commitment: new_commitment)
      update_transaction_attributes(transaction)
    end
    
    Rails.logger.info "Split commitment #{recurring_commitment.id}. Created new commitment #{new_commitment.id} with #{future_transactions.count} transactions"
    
    @new_commitment = new_commitment
  end

  def update_transaction_attributes(transaction)
    # Atualiza atributos da transação baseados nos novos atributos do compromisso
    transaction_updates = {}
    
    transaction_updates[:description] = new_attributes[:name] if new_attributes[:name].present?
    transaction_updates[:amount] = new_attributes[:amount] if new_attributes[:amount].present?
    transaction_updates[:transaction_type] = new_attributes[:transaction_type] if new_attributes[:transaction_type].present?
    transaction_updates[:account_id] = new_attributes[:account_id] if new_attributes[:account_id].present?
    transaction_updates[:category_id] = new_attributes[:category_id] if new_attributes[:category_id].present?
    
    transaction.update!(transaction_updates) if transaction_updates.any?
  end

  def filtered_new_attributes
    # Remove atributos que não devem ser aplicados diretamente ao modelo
    new_attributes.except('edit_strategy', 'effective_date')
  end

  # Getter para o novo compromisso criado (quando strategy é split_commitment)
  def new_commitment
    @new_commitment
  end

  # Métodos de conveniência para usar o service
  class << self
    def edit_future_only(commitment, new_attributes, effective_date = Date.current)
      new(
        recurring_commitment: commitment,
        edit_strategy: 'future_only',
        effective_date: effective_date,
        new_attributes: new_attributes
      ).call
    end

    def edit_all_transactions(commitment, new_attributes)
      new(
        recurring_commitment: commitment,
        edit_strategy: 'all_transactions',
        effective_date: Date.current,
        new_attributes: new_attributes
      ).call
    end

    def split_commitment(commitment, new_attributes, effective_date)
      service = new(
        recurring_commitment: commitment,
        edit_strategy: 'split_commitment',
        effective_date: effective_date,
        new_attributes: new_attributes
      )
      
      result = service.call
      [result, service.new_commitment]
    end
  end
end
