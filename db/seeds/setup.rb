puts "Seeding base structure..."

# Account Types
AccountType.create!(code: "BANK", role: "asset", name: "Conta Corrente")
AccountType.create!(code: "CREDIT", role: "asset", name: "Cartão de Crédito")
AccountType.create!(code: "CASH", role: "asset", name: "Dinheiro")
AccountType.create!(code: "SAVINGS", role: "asset", name: "Poupança")
AccountType.create!(code: "EXPENSE", role: "expense", name: "Despesa")
AccountType.create!(code: "REVENUE", role: "income", name: "Receita")

# Category Groups
CategoryGroup.create!(code: "FIXED", name: "Fixa")
CategoryGroup.create!(code: "RECURRING", name: "Recorrente")
CategoryGroup.create!(code: "OCCASIONAL", name: "Ocasional")

# Categories
Category.create!(name: "Energia", category_group_id: 1)
Category.create!(name: "Supermercado", category_group_id: 2)
Category.create!(name: "Farmácia", category_group_id: 2)
Category.create!(name: "Assinatura", category_group_id: 1)
Category.create!(name: "Restaurante", category_group_id: 3)
Category.create!(name: "Salário", category_group_id: 1)

puts "Setup seed complete."
