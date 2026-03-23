# frozen_string_literal: true

class AddPaymentDateIndexToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_index :transactions, [:user_id, :payment_date], name: "index_transactions_on_user_id_and_payment_date"
  end
end
