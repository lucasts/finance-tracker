class AddUserIdToTables < ActiveRecord::Migration[7.1]
  def change
    # Adicionar user_id às tabelas principais
    add_reference :transactions, :user, null: false, foreign_key: true, default: 1
    add_reference :accounts, :user, null: false, foreign_key: true, default: 1
    add_reference :categories, :user, null: false, foreign_key: true, default: 1
    add_reference :recurring_commitments, :user, null: false, foreign_key: true, default: 1
    add_reference :installment_plans, :user, null: false, foreign_key: true, default: 1
    
    # Remover default após migration para forçar user_id em novos registros
    change_column_default :transactions, :user_id, nil
    change_column_default :accounts, :user_id, nil
    change_column_default :categories, :user_id, nil
    change_column_default :recurring_commitments, :user_id, nil
    change_column_default :installment_plans, :user_id, nil
  end
end
