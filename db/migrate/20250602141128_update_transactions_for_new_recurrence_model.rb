class UpdateTransactionsForNewRecurrenceModel < ActiveRecord::Migration[7.1]
  def change
    # Adicionar novas referências para o novo modelo
    add_reference :transactions, :recurring_commitment, null: true, foreign_key: true
    add_reference :transactions, :installment_plan, null: true, foreign_key: true
    
    # Adicionar novos campos para controle de recorrência
    add_column :transactions, :recurrence_pattern, :string
    add_column :transactions, :recurrence_frequency, :string
    add_column :transactions, :installment_number, :integer
    
    # Atualizar enum de recurrence_type para novos valores
    # Como já existe, vamos apenas documentar os novos valores possíveis:
    # single: 0, recurring: 1, installment: 2
    
    # Adicionar índices para performance (add_reference já cria índices para FK)
    add_index :transactions, :recurrence_pattern
    add_index :transactions, :installment_number
    
    # Adicionar constraint para garantir exclusividade mútua
    # Uma transação só pode pertencer a UM dos seguintes:
    # - recurring_commitment_id
    # - installment_plan_id  
    # - transaction_group_id (legado, manter por compatibilidade)
    # Isso será validado no model
  end
end
