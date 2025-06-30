# Correção de campos duplicados E padronização de nomenclatura
# Problemas encontrados:
# 1. transaction_groups tinha installment_count E installments_count (duplicação)
# 2. Inconsistência: installment_plans usa "installment_count" (singular)
#    mas transaction_groups usava "installments_count" (plural)
class FixDuplicateInstallmentCountFields < ActiveRecord::Migration[8.0]
  def up
    # FASE 1: Corrigir duplicação - manter apenas um campo
    if column_exists?(:transaction_groups, :installment_count) && 
       column_exists?(:transaction_groups, :installments_count)
      
      # Migra dados para o campo que será mantido (installments_count temporariamente)
      execute <<-SQL
        UPDATE transaction_groups 
        SET installments_count = COALESCE(installments_count, installment_count, 1)
        WHERE installments_count IS NULL OR installments_count = 0
      SQL
      
      # Remove o campo duplicado
      remove_column :transaction_groups, :installment_count
    end
    
    # FASE 2: Padronização de nomenclatura - renomear para consistência
    # installment_plans usa "installment_count", então padronizamos para singular
    if column_exists?(:transaction_groups, :installments_count)
      rename_column :transaction_groups, :installments_count, :installment_count
    end
  end

  def down
    # FASE 1: Reverter padronização de nomenclatura
    if column_exists?(:transaction_groups, :installment_count)
      rename_column :transaction_groups, :installment_count, :installments_count  
    end
    
    # FASE 2: Restaurar campo duplicado para rollback completo
    if column_exists?(:transaction_groups, :installments_count) && 
       !column_exists?(:transaction_groups, :installment_count)
      
      add_column :transaction_groups, :installment_count, :integer, default: 1
      
      # Migra dados de volta
      execute <<-SQL
        UPDATE transaction_groups 
        SET installment_count = COALESCE(installments_count, 1)
      SQL
    end
  end
end
