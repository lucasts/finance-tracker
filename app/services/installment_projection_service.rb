# frozen_string_literal: true

# InstallmentProjectionService
# Gera projeções de futuras parcelas (não persistidas) para planos ativos.
# Apenas cria projeções para parcelas que ainda não possuem transação criada.
# Mantém separação competência (event_date) vs caixa (payment_date) – hoje iguais.
class InstallmentProjectionService
  DEFAULT_HORIZON_MONTHS = 6

  def self.call(months_ahead: DEFAULT_HORIZON_MONTHS, as_of: Date.today)
    new(months_ahead: months_ahead, as_of: as_of).projected_installments
  end

  def initialize(months_ahead: DEFAULT_HORIZON_MONTHS, as_of: Date.today)
    @as_of = as_of
    horizon_date = as_of.advance(months: months_ahead)
  @months_ahead = months_ahead
  @horizon_end = (months_ahead.zero? ? as_of.end_of_month : horizon_date.end_of_month)
  end

  # Retorna array de hashes de projeções de parcelas
  def projected_installments
    InstallmentPlan.where(status: :active).flat_map { |plan| project_plan(plan) }
  end

  private

  def project_plan(plan)
  # If plan starts after horizon end, skip
  return [] if plan.starts_on > @horizon_end
    amount_per = plan.installment_amount
    return [] unless amount_per.positive?

    existing_numbers = plan.transactions.pluck(:installment_number).compact.to_set
    projections = []

    (1..plan.installment_count).each do |number|
      next if existing_numbers.include?(number)
      installment_date = plan.next_installment_date(number)
      next unless installment_date
      # For horizon zero (current month focus), allow projecting installments inside the month even if
      # the installment date is earlier in the month but after start and not yet materialized (edge case)
      if installment_date < @as_of
        next unless @months_ahead.zero? && installment_date.month == @as_of.month && installment_date.year == @as_of.year
      end
      break if installment_date > @horizon_end

      projections << build_projection_hash(plan, number, installment_date, amount_per)
    end

    projections
  end

  def build_projection_hash(plan, number, date, amount)
    {
      id: "installment-proj-#{plan.id}-#{number}",
      date: date,
      payment_date: date,
      amount: amount.round(2),
      description: "#{plan.name} (#{number}/#{plan.installment_count})",
      category_id: plan.category_id,
      account_id: plan.from_account_id,
      to_account_id: plan.to_account_id,
      installment_plan_id: plan.id,
      installment_number: number,
      projected: true,
      projection_type: 'installment'
    }
  end
end
