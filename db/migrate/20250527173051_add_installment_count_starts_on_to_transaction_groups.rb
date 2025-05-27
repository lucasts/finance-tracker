class AddInstallmentCountStartsOnToTransactionGroups < ActiveRecord::Migration[7.1]
  def change
    add_column :transaction_groups, :installment_count, :integer, default: 1
    add_column :transaction_groups, :starts_on, :date
  end
end
