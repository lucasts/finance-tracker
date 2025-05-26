class CreateTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transactions do |t|
      t.string :description
      t.decimal :amount
      t.string :transaction_type
      t.date :date
      t.string :period
      t.references :from_account, null: false, foreign_key: { to_table: :accounts }      
      t.references :to_account, foreign_key: { to_table: :accounts }, null: true
      t.references :category, null: false, foreign_key: true
      t.string :installment
      t.string :status
      t.references :transaction_group, null: true, foreign_key: true

      t.timestamps
    end
  end
end
