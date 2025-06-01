class AddInstallmentFieldsToTransactionGroups < ActiveRecord::Migration[7.1]
  def change
    add_column :transaction_groups, :total_amount, :decimal, precision: 15, scale: 2
    add_column :transaction_groups, :installments_count, :integer
  end
end
