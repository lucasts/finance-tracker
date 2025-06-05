class CreateImportSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :import_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :source_type, null: false # 'ofx' ou 'csv'
      t.string :original_filename
      t.string :account_type # 'BANK' ou 'CREDIT' (corrente/cartão)
      t.integer :account_id, null: false # conta destino da importação
      t.text :raw_file # arquivo original (base64 ou texto)
      t.json :metadata # informações extras do parsing
      t.datetime :imported_at
      t.timestamps
    end
  end
end
