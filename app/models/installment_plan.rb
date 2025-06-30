# InstallmentPlan - Installment Plans
# 
# Represents a purchase or expense divided into fixed installments
# (e.g., refrigerator purchase in 12x, car financing in 48x)
# 
# Status: active (active), paused (paused), closed (closed)
# Frequency: monthly (default), weekly, annual etc.
#
class InstallmentPlan < ApplicationRecord
  include PaidAmountCalculations
  
  # User association
  belongs_to :user
  belongs_to :category
  
  has_many :transactions, dependent: :nullify
  
  validates :name, presence: true
  validates :installment_count, presence: true, numericality: { 
    greater_than: 0, less_than_or_equal_to: 120 
  }
  validates :recurrence_frequency, presence: true, inclusion: { 
    in: %w[weekly monthly quarterly annual] 
  }
  validates :starts_on, presence: true
  validates :status, presence: true
  validates :total_amount, numericality: { greater_than: 0 }, allow_blank: true
  
  enum :status, { active: 0, paused: 1, closed: 2 }
  
  scope :active_plans, -> { where(status: :active) }
  scope :by_frequency, ->(freq) { where(recurrence_frequency: freq) }
  scope :monthly_plans, -> { where(recurrence_frequency: 'monthly') }
  
  # Plans that still have pending installments
  scope :with_pending_installments, -> do
    joins(:transactions)
      .where(transactions: { status: ['pending', 'confirmed'] })
      .where(status: :active)
      .distinct
  end
  
  # Calculate value per installment based on total
  def installment_amount
    return 0 unless total_amount && installment_count > 0
    (total_amount / installment_count).round(2)
  end
  
  # Date of next installment based on frequency
  def next_installment_date(installment_number)
    return nil if installment_number > installment_count
    
    case recurrence_frequency
    when 'weekly'
      starts_on + (installment_number - 1).weeks
    when 'monthly'
      starts_on + (installment_number - 1).months
    when 'quarterly'
      starts_on + ((installment_number - 1) * 3).months
    when 'annual'
      starts_on + (installment_number - 1).years
    else
      starts_on + (installment_number - 1).months # default monthly
    end
  end
  
  # Number of paid installments (specific to installment plans)
  def installments_paid
    transactions.where(status: 'confirmed').count
  end
  
  # Number of pending installments
  def installments_pending
    installment_count - installments_paid
  end
  
  # Summary status of the plan
  def summary_status
    if installments_paid == installment_count
      'completed'
    elsif installments_paid > 0
      'in_progress'
    else
      'not_started'
    end
  end
  
  # Expected completion date
  def expected_completion_date
    next_installment_date(installment_count)
  end
  
  # Next installment due
  def next_due_installment
    transactions
      .where(status: 'pending')
      .order(:payment_date)
      .first
  end
  
  # Check if all installments have been created
  def all_installments_created?
    transactions.count >= installment_count
  end
  
  # Create all installment transactions
  def generate_installments!(transaction_params)
    return false if all_installments_created?
    
    (1..installment_count).each do |number|
      # Check if the installment already exists
      next if transactions.exists?(installment_number: number)
      
      installment_date = next_installment_date(number)
      amount = installment_amount
      
      Transaction.create!(
        **transaction_params.except(:amount),
        installment_plan: self,
        installment_number: number,
        amount: amount,
        payment_date: installment_date,
        event_date: installment_date,
        recurrence_type: 'installment',
        recurrence_frequency: recurrence_frequency,
        description: "#{transaction_params[:description]} (#{number}/#{installment_count})"
      )
    end
    
    true
  end

  # Cria todas as transações do parcelamento - versão mais robusta
  def create_installment_transactions!(transaction_params)
    return false if all_installments_created?
    
    ActiveRecord::Base.transaction do
      (1..installment_count).each do |number|
        # Verifica se a parcela já existe
        next if transactions.exists?(installment_number: number)
        
        installment_date = next_installment_date(number)
        amount = installment_amount
        
        # Ajusta o valor da última parcela para compensar arredondamentos
        if number == installment_count
          paid_so_far = (number - 1) * installment_amount
          amount = total_amount - paid_so_far
        end
        
        transaction = Transaction.new(
          description: "#{transaction_params[:description_base]} (#{number}/#{installment_count})",
          amount: amount.round(2),
          transaction_type: transaction_params[:transaction_type],
          from_account_id: transaction_params[:from_account_id],
          to_account_id: transaction_params[:to_account_id],
          category: category,
          installment_plan: self,
          installment_number: number,
          payment_date: installment_date,
          event_date: installment_date,
          recurrence_type: 'installment',
          user: user  # Add the user from the installment plan
        )
        
        # Aplicar lógica de status específica para parcelas
        # Primeira parcela: confirmed se for atual/passada, senão pending
        # Demais parcelas: sempre pending
        if number == 1 && installment_date <= Date.current
          transaction.status = 'confirmed'
        else
          transaction.status = 'pending'
        end
        
        transaction.save!
      end
    end
    
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create installment transactions: #{e.message}"
    false
  end

  # Get detailed payment status for UI display
  def payment_summary
    {
      installment_count: installment_count,
      paid_installments: installments_paid,
      pending_installments: installments_pending,
      total_amount: total_amount,
      amount_paid: amount_paid,
      amount_pending: amount_pending,
      percentage_complete: percentage_paid,
      next_due_date: next_due_installment&.payment_date,
      next_due_amount: next_due_installment&.amount,
      status: summary_status,
      estimated_completion: expected_completion_date
    }
  end

  # Get timeline view for UI
  def installment_timeline
    transactions.order(:installment_number).map do |transaction|
      {
        installment_number: transaction.installment_number,
        amount: transaction.amount,
        due_date: transaction.payment_date,
        status: transaction.status,
        paid_date: transaction.status == 'confirmed' ? transaction.updated_at.to_date : nil,
        description: transaction.description
      }
    end
  end

  # Check if installment plan is complete
  def completed?
    summary_status == 'completed'
  end

  # Check if installment plan is behind schedule
  def behind_schedule?
    overdue_installments = transactions.where(status: 'pending')
                                     .where('payment_date < ?', Date.current)
    overdue_installments.any?
  end
end