class InstallmentPlansController < ApplicationController
  include FinancialConstants
  
  before_action :set_installment_plan, only: [:show, :edit, :update, :destroy, :toggle_active]
  
  def index
    @installment_plans = current_user_scope(InstallmentPlan).includes(
                           transactions: [:from_account, :to_account, :category]
                         ).order(created_at: :desc)
    
    @plan_summaries = @installment_plans.map do |plan|
      paid_installments = plan.transactions.where(status: 'confirmed').count
      remaining_installments = plan.installment_count - paid_installments
      total_paid = plan.transactions.where(status: 'confirmed').sum(:amount)
      remaining_amount = plan.total_amount - total_paid
      next_due_date = calculate_next_due_date(plan)
      
      {
        plan: plan,
        paid_installments: paid_installments,
        remaining_installments: remaining_installments,
        total_paid: total_paid,
        remaining_amount: remaining_amount,
        next_due_date: next_due_date,
        progress_percentage: FinancialConstants.calculate_percentage(paid_installments.to_f, plan.installment_count)
      }
    end
  end
  
  def show
    @transactions = @installment_plan.transactions.order(:installment_number)
    @progress = calculate_progress(@installment_plan)
    @next_installments = calculate_next_installments(@installment_plan, 3)
  end
  
  def new
    @installment_plan = current_user.installment_plans.build
    @accounts = current_user_scope(Account).all
    @categories = current_user_scope(Category).all
  end
  
  def create
    @installment_plan = current_user.installment_plans.build(installment_plan_params)
    
    if @installment_plan.save
      # Generate the first installment if the start date has already passed
      if @installment_plan.starts_on <= Date.current
        generate_first_installment
      end
      
      redirect_to @installment_plan, notice: 'Plano de parcelamento criado com sucesso.'
    else
      @accounts = current_user_scope(Account).all
      @categories = current_user_scope(Category).all
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @accounts = current_user_scope(Account).all
    @categories = current_user_scope(Category).all
  end
  
  def update
    if @installment_plan.update(installment_plan_params)
      redirect_to @installment_plan, notice: 'Plano de parcelamento atualizado com sucesso.'
    else
      @accounts = current_user_scope(Account).all
      @categories = current_user_scope(Category).all
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @installment_plan.update!(active: false)
    redirect_to installment_plans_path, notice: 'Plano de parcelamento desativado com sucesso.'
  end
  
  def toggle_active
    @installment_plan.update!(active: !@installment_plan.active)
    status = @installment_plan.active? ? 'ativado' : 'desativado'
    redirect_to installment_plans_path, notice: "Plano #{status} com sucesso."
  end
  
  def generate_missing_installments
    set_installment_plan
    
    job = GenerateInstallmentTransactionsJob.perform_later(Date.current)
    
    redirect_to @installment_plan, notice: 'Geração de parcelas em andamento. As parcelas pendentes serão criadas em breve.'
  end
  
  def payment_schedule
    set_installment_plan
    
    schedule = []
    (1..@installment_plan.installment_count).each do |installment_number|
      due_date = calculate_installment_date(@installment_plan, installment_number)
      existing_transaction = @installment_plan.transactions.find_by(installment_number: installment_number)
      
      schedule << {
        installment_number: installment_number,
        due_date: due_date,
        amount: @installment_plan.installment_amount,
        status: existing_transaction ? 'paid' : (due_date <= Date.current ? 'overdue' : 'pending'),
        transaction_id: existing_transaction&.id,
        paid_date: existing_transaction&.date
      }
    end
    
    render json: {
      plan: {
        id: @installment_plan.id,
        name: @installment_plan.name,
        installment_count: @installment_plan.installment_count,
        installment_amount: @installment_plan.installment_amount
      },
      schedule: schedule
    }
  end
  
  private
  
  def set_installment_plan
    @installment_plan = current_user_scope(InstallmentPlan).find(params[:id])
  end
  
  def installment_plan_params
    permitted = params.require(:installment_plan).permit(
      :name, :total_amount, :installment_count,
      :starts_on, :recurrence_frequency, :transaction_type,
      :account_id, :category_id, :notes, :active
    )
    
    permitted[:total_amount] = InstallmentPlan.normalize_amount_param(permitted[:total_amount]) if permitted[:total_amount].present?
    permitted
  end
  
  def calculate_next_due_date(plan)
    paid_count = plan.transactions.where(status: 'confirmed').count
    return nil if paid_count >= plan.installment_count
    
    next_installment_number = paid_count + 1
    calculate_installment_date(plan, next_installment_number)
  end
  
  def calculate_installment_date(plan, installment_number)
    case plan.recurrence_frequency
    when 'monthly'
      plan.starts_on + (installment_number - 1).months
    when 'weekly'
      plan.starts_on + (installment_number - 1).weeks
    when 'daily'
      plan.starts_on + (installment_number - 1).days
    else
      plan.starts_on + (installment_number - 1).months
    end
  end
  
  def calculate_progress(plan)
    paid_installments = plan.transactions.where(status: 'confirmed').count
    total_paid = plan.transactions.where(status: 'confirmed').sum(:amount)
    next_due_date = calculate_next_due_date(plan)
    
    {
      paid_installments: paid_installments,
      installment_count: plan.installment_count,
      progress_percentage: FinancialConstants.calculate_percentage(paid_installments.to_f, plan.installment_count),
      total_paid: total_paid,
      total_amount: plan.total_amount,
      remaining_installments: plan.installment_count - paid_installments,
      remaining_amount: plan.total_amount - total_paid,
      next_due_date: next_due_date
    }
  end
  
  def calculate_next_installments(plan, count = 3)
    paid_count = plan.transactions.where(status: 'confirmed').count
    next_installments = []
    
    (1..count).each do |i|
      installment_number = paid_count + i
      break if installment_number > plan.installment_count
      
      due_date = calculate_installment_date(plan, installment_number)
      days_diff = (due_date - Date.current).to_i
      
      next_installments << {
        number: installment_number,
        date: due_date,
        amount: plan.installment_amount,
        overdue: days_diff < 0,
        due_soon: days_diff >= 0 && days_diff <= 7
      }
    end
    
    next_installments
  end
  
  def generate_first_installment
    current_user.transactions.create!(
      description: "#{@installment_plan.name} (1/#{@installment_plan.installment_count})",
      amount: @installment_plan.installment_amount,
      transaction_type: @installment_plan.transaction_type,
      date: @installment_plan.starts_on,
      account: @installment_plan.account,
      category: @installment_plan.category,
      installment_plan: @installment_plan,
      installment_number: 1,
      notes: "Primeira parcela gerada automaticamente"
    )
  end
end
