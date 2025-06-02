puts "Seeding base structure..."

# Account Types
bank      = AccountType.find_or_create_by!(code: "BANK")    { |at| at.assign_attributes(role: "asset",   name: "Conta Corrente") }
credit    = AccountType.find_or_create_by!(code: "CREDIT")  { |at| at.assign_attributes(role: "asset",   name: "Cartão de Crédito") }
cash      = AccountType.find_or_create_by!(code: "CASH")    { |at| at.assign_attributes(role: "asset",   name: "Dinheiro") }
savings   = AccountType.find_or_create_by!(code: "SAVINGS") { |at| at.assign_attributes(role: "asset",   name: "Poupança") }
expense   = AccountType.find_or_create_by!(code: "EXPENSE") { |at| at.assign_attributes(role: "expense", name: "Despesa") }
revenue   = AccountType.find_or_create_by!(code: "REVENUE") { |at| at.assign_attributes(role: "income",  name: "Receita") }

# Categories (sem grupo)
Category.find_or_create_by!(name: "Energia")
Category.find_or_create_by!(name: "Aluguel")
Category.find_or_create_by!(name: "Supermercado")
Category.find_or_create_by!(name: "Farmácia")
Category.find_or_create_by!(name: "Assinatura")
Category.find_or_create_by!(name: "Restaurante")
Category.find_or_create_by!(name: "Escola")
Category.find_or_create_by!(name: "Plano Saúde")
Category.find_or_create_by!(name: "Netflix")
Category.find_or_create_by!(name: "Massagem")
Category.find_or_create_by!(name: "Salário")
Category.find_or_create_by!(name: "Freelance")
Category.find_or_create_by!(name: "PIX Recebido")
Category.find_or_create_by!(name: "Compras")

# Sample Recurring Commitments (para demonstração)
puts "Creating sample recurring commitments..."

energia_categoria = Category.find_by(name: "Energia")
aluguel_categoria = Category.find_by(name: "Aluguel")

if energia_categoria
  RecurringCommitment.create!(
    name: "Conta de Energia",
    default_amount: 150.00,
    recurrence_frequency: "monthly", 
    start_date: Date.current.beginning_of_month,
    category: energia_categoria,
    status: "active"
  )
end

if aluguel_categoria
  RecurringCommitment.create!(
    name: "Aluguel Mensal",
    default_amount: 1200.00,
    recurrence_frequency: "monthly",
    start_date: Date.current.beginning_of_month,
    category: aluguel_categoria,
    status: "active"
  )
end

# Sample Installment Plans (para demonstração)
puts "Creating sample installment plans..."

compras_categoria = Category.find_by(name: "Compras")

if compras_categoria
  InstallmentPlan.create!(
    name: "Televisão Nova",
    total_amount: 2400.00,
    installment_count: 12,
    recurrence_frequency: "monthly",
    starts_on: Date.current,
    status: "active"
  )
end

puts "Setup seed complete."
