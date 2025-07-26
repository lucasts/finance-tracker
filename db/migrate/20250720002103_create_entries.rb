class CreateEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :entries do |t|
      t.references :transaction, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :entry_type, null: false

      t.timestamps
    end

    add_index :entries, [:transaction_id, :account_id]
  end
end
