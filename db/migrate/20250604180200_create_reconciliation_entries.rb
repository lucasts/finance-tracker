class CreateReconciliationEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :reconciliation_entries do |t|
      t.references :imported_transaction, null: false, foreign_key: true
      t.references :transaction, foreign_key: true # transação do sistema
      t.string :action, null: false # associate, create_new, ignore, edit
      t.json :decision_data # campos editados pelo usuário
      t.integer :user_id, null: false # quem tomou a decisão
      t.datetime :decided_at, null: false
      t.text :audit_log # texto livre para rastreabilidade
      t.timestamps
    end
    add_foreign_key :reconciliation_entries, :users
  end
end
