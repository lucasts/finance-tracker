class AddCategoryToInstallmentPlans < ActiveRecord::Migration[7.1]
  def change
    add_reference :installment_plans, :category, null: true, foreign_key: true
  end
end
