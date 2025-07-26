class CreateTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transactions do |t|
      t.string :description
      t.decimal :amount
      t.string :transaction_type
      t.date :date
      t.string :period
      t.references :category, null: false, foreign_key: true
      t.integer :installment
      t.integer :status, default:0
      t.integer :recurrence_type, default:0
      t.references :transaction_group, null: true, foreign_key: true

      t.timestamps
    end
  end
end
