class CreateImportedTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :imported_transactions do |t|
      t.references :import_session, null: false, foreign_key: true
      t.integer :line_number # linha do arquivo
      t.string :external_id # FITID (OFX) ou outro identificador
      t.string :raw_data, null: false # linha original (JSON ou texto)
      t.string :description
      t.decimal :amount, precision: 15, scale: 2
      t.date :event_date
      t.date :payment_date
      t.string :transaction_type # income/expense/transfer
      t.string :status # pending/confirmed/cancelled
      t.string :category_guess
      t.string :installment_info # ex: "3/10"
      t.integer :installment_plan_id
      t.integer :recurring_commitment_id
      t.integer :matched_transaction_id
      t.json :parsed_data # todos os campos parseados
      t.timestamps
    end
    add_foreign_key :imported_transactions, :installment_plans
    add_foreign_key :imported_transactions, :recurring_commitments
    add_foreign_key :imported_transactions, :transactions, column: :matched_transaction_id
  end
end
