class MakeCategoryNotNullOnInstallmentPlans < ActiveRecord::Migration[7.1]
  def change
    change_column_null :installment_plans, :category_id, false
  end
end
