class CreateTransactionGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :transaction_groups do |t|
      t.string :name
      t.string :group_type

      t.timestamps
    end
  end
end
