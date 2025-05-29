class CreateCreditStatements < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_statements do |t|
      t.references :account, null: false, foreign_key: true
      t.string :month, null: false # format: YYYY-MM
      t.decimal :amount_due, precision: 12, scale: 2, null: false, default: 0.0
      t.decimal :amount_paid, precision: 12, scale: 2, null: false, default: 0.0
      t.integer :status, default: 0, null: false
      t.date :closed_on
      t.date :due_on
      t.date :paid_on
      t.timestamps
    end
    
    add_index :credit_statements, [:account_id, :month], unique: true
  end
end

