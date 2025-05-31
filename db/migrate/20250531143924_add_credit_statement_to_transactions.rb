class AddCreditStatementToTransactions < ActiveRecord::Migration[7.1]
  def change
    add_reference :transactions, :credit_statement, foreign_key: true, null: true
  end
end