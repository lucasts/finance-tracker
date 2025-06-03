puts "Seeding base structure..."

# Account Types
bank      = AccountType.find_or_create_by!(code: "BANK")    { |at| at.assign_attributes(role: "asset",   name: "Conta Corrente") }
credit    = AccountType.find_or_create_by!(code: "CREDIT")  { |at| at.assign_attributes(role: "asset",   name: "Cartão de Crédito") }
cash      = AccountType.find_or_create_by!(code: "CASH")    { |at| at.assign_attributes(role: "asset",   name: "Dinheiro") }
savings   = AccountType.find_or_create_by!(code: "SAVINGS") { |at| at.assign_attributes(role: "asset",   name: "Poupança") }
expense   = AccountType.find_or_create_by!(code: "EXPENSE") { |at| at.assign_attributes(role: "expense", name: "Despesa") }
revenue   = AccountType.find_or_create_by!(code: "REVENUE") { |at| at.assign_attributes(role: "income",  name: "Receita") }

# Default user for seeds
default_user = User.first || User.create!(email: "admin@example.com", password: "password", password_confirmation: "password")

# Categories (com user associado)
Category.find_or_create_by!(name: "Energia", user: default_user)
Category.find_or_create_by!(name: "Aluguel", user: default_user)
Category.find_or_create_by!(name: "Supermercado", user: default_user)
Category.find_or_create_by!(name: "Farmácia", user: default_user)
Category.find_or_create_by!(name: "Assinatura", user: default_user)
Category.find_or_create_by!(name: "Restaurante", user: default_user)
Category.find_or_create_by!(name: "Escola", user: default_user)
Category.find_or_create_by!(name: "Plano Saúde", user: default_user)
Category.find_or_create_by!(name: "Netflix", user: default_user)
Category.find_or_create_by!(name: "Massagem", user: default_user)
Category.find_or_create_by!(name: "Salário", user: default_user)
Category.find_or_create_by!(name: "Freelance", user: default_user)
Category.find_or_create_by!(name: "PIX Recebido", user: default_user)
Category.find_or_create_by!(name: "Compras", user: default_user)

# Sample Recurring Commitments (para demonstração)
puts "Creating sample recurring commitments..."

energia_categoria = Category.find_by(name: "Energia", user: default_user)
aluguel_categoria = Category.find_by(name: "Aluguel", user: default_user)

if energia_categoria
  RecurringCommitment.find_or_create_by!(
    name: "Conta de Energia",
    user: default_user
  ) do |rc|
    rc.assign_attributes(
      default_amount: 150.00,
      recurrence_frequency: "monthly", 
      start_date: Date.current.beginning_of_month,
      category: energia_categoria,
      status: "active"
    )
  end
end

if aluguel_categoria
  RecurringCommitment.find_or_create_by!(
    name: "Aluguel Mensal",
    user: default_user
  ) do |rc|
    rc.assign_attributes(
      default_amount: 1200.00,
      recurrence_frequency: "monthly",
      start_date: Date.current.beginning_of_month,
      category: aluguel_categoria,
      status: "active"
    )
  end
end

# Sample Installment Plans (para demonstração)
puts "Creating sample installment plans..."

compras_categoria = Category.find_by(name: "Compras", user: default_user)

if compras_categoria
  InstallmentPlan.find_or_create_by!(
    name: "Televisão Nova",
    user: default_user
  ) do |ip|
    ip.assign_attributes(
      total_amount: 2400.00,
      installment_count: 12,
      recurrence_frequency: "monthly",
      starts_on: Date.current,
      status: "active"
    )
  end
end

puts "Setup seed complete."