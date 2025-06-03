puts "Criando usuário padrão..."

# Criar usuário padrão se não existir
default_user = User.find_or_create_by(email: 'demo@finance-tracker.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
end

puts "Usuário padrão criado: #{default_user.email}"

# Atualizar registros existentes sem user_id para usar o usuário padrão
["transactions", "accounts", "categories", "recurring_commitments", "installment_plans"].each do |table|
  model_class = table.classify.constantize
  records_updated = model_class.where(user_id: nil).update_all(user_id: default_user.id)
  puts "#{table}: #{records_updated} registros atualizados"
end

puts "Setup do usuário padrão concluído!"
