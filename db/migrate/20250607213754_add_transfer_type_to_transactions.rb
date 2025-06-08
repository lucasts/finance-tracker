class AddTransferTypeToTransactions < ActiveRecord::Migration[8.0]
  def up
    # Primeiro, adiciona uma coluna temporária para o novo tipo
    add_column :transactions, :transaction_type_temp, :integer
    
    # Migra os dados existentes
    execute <<-SQL
      UPDATE transactions 
      SET transaction_type_temp = CASE 
        WHEN transaction_type = 'income' THEN 0
        WHEN transaction_type = 'expense' THEN 1
        ELSE 1
      END
    SQL
    
    # Remove a coluna antiga e renomeia a nova
    remove_column :transactions, :transaction_type
    rename_column :transactions, :transaction_type_temp, :transaction_type
    
    # Adiciona default e not null
    change_column :transactions, :transaction_type, :integer, default: 1, null: false
    
    # Adiciona índice para performance
    add_index :transactions, :transaction_type
  end
  
  def down
    # Converte de volta para string
    add_column :transactions, :transaction_type_temp, :string
    
    execute <<-SQL
      UPDATE transactions 
      SET transaction_type_temp = CASE 
        WHEN transaction_type = 0 THEN 'income'
        WHEN transaction_type = 1 THEN 'expense'
        WHEN transaction_type = 2 THEN 'transfer'
        ELSE 'expense'
      END
    SQL
    
    remove_index :transactions, :transaction_type
    remove_column :transactions, :transaction_type
    rename_column :transactions, :transaction_type_temp, :transaction_type
  end
end
