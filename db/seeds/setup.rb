puts "Seeding base structure..."

# Account Types
bank      = AccountType.create!(code: "BANK",    role: "asset",   name: "Conta Corrente")
credit    = AccountType.create!(code: "CREDIT",  role: "asset",   name: "Cartão de Crédito")
cash      = AccountType.create!(code: "CASH",    role: "asset",   name: "Dinheiro")
savings   = AccountType.create!(code: "SAVINGS", role: "asset",   name: "Poupança")
expense   = AccountType.create!(code: "EXPENSE", role: "expense", name: "Despesa")
revenue   = AccountType.create!(code: "REVENUE", role: "income",  name: "Receita")

# Categories (sem grupo)
Category.create!(name: "Energia")
Category.create!(name: "Aluguel")
Category.create!(name: "Supermercado")
Category.create!(name: "Farmácia")
Category.create!(name: "Assinatura")
Category.create!(name: "Restaurante")
Category.create!(name: "Escola")
Category.create!(name: "Plano Saúde")
Category.create!(name: "Netflix")
Category.create!(name: "Massagem")
Category.create!(name: "Salário")
Category.create!(name: "Freelance")
Category.create!(name: "PIX Recebido")
Category.create!(name: "Compras")

puts "Setup seed complete."
