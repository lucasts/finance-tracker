puts "Seeding demo data..."

# Accounts (usuário)
Account.create!(name: "Itaú", account_type_id: 1)
Account.create!(name: "Nubank", account_type_id: 2)
Account.create!(name: "Carteira", account_type_id: 3)
Account.create!(name: "Poupança Inter", account_type_id: 4)

# Accounts (despesa)
Account.create!(name: "Zaffari", account_type_id: 5)
Account.create!(name: "Panvel", account_type_id: 5)
Account.create!(name: "Netflix", account_type_id: 5)
Account.create!(name: "Mariana Massagem", account_type_id: 5)

# Accounts (receita)
Account.create!(name: "Empregador", account_type_id: 6)
Account.create!(name: "Pix Joana", account_type_id: 6)

# Transaction group
TransactionGroup.create!(name: "Compra Geladeira", group_type: "installment")

# Lançamentos
puts "Seeding realistic transactions..."

Transaction.create!(
  description: "Salário mensal",
  amount: 365,
  transaction_type: "income",
  date: Date.new(2025, 5, 17),
  period: "2025-05",
  from_account_id: 10,
  to_account_id: 2,
  category_id: 5,
  status: "confirmed"
)

Transaction.create!(
  description: "Venda OLX",
  amount: 210,
  transaction_type: "income",
  date: Date.new(2025, 5, 7),
  period: "2025-05",
  from_account_id: 9,
  to_account_id: 1,
  category_id: 6,
  status: "confirmed"
)

Transaction.create!(
  description: "Freelance",
  amount: 440,
  transaction_type: "income",
  date: Date.new(2025, 5, 22),
  period: "2025-05",
  from_account_id: 10,
  to_account_id: 1,
  category_id: 5,
  status: "confirmed"
)

Transaction.create!(
  description: "Salário mensal",
  amount: 390,
  transaction_type: "income",
  date: Date.new(2025, 4, 16),
  period: "2025-04",
  from_account_id: 10,
  to_account_id: 1,
  category_id: 5,
  status: "confirmed"
)

Transaction.create!(
  description: "PIX Joana",
  amount: 150,
  transaction_type: "income",
  date: Date.new(2025, 4, 6),
  period: "2025-04",
  from_account_id: 9,
  to_account_id: 2,
  category_id: 6,
  status: "confirmed"
)

Transaction.create!(
  description: "Serviço gráfico",
  amount: 330,
  transaction_type: "income",
  date: Date.new(2025, 4, 28),
  period: "2025-04",
  from_account_id: 10,
  to_account_id: 2,
  category_id: 5,
  status: "confirmed"
)

Transaction.create!(
  description: "Salário mensal",
  amount: 375,
  transaction_type: "income",
  date: Date.new(2025, 3, 15),
  period: "2025-03",
  from_account_id: 10,
  to_account_id: 1,
  category_id: 5,
  status: "confirmed"
)

Transaction.create!(
  description: "Reembolso Uber",
  amount: 89,
  transaction_type: "income",
  date: Date.new(2025, 3, 10),
  period: "2025-03",
  from_account_id: 9,
  to_account_id: 1,
  category_id: 6,
  status: "confirmed"
)

Transaction.create!(
  description: "Serviço web",
  amount: 300,
  transaction_type: "income",
  date: Date.new(2025, 3, 23),
  period: "2025-03",
  from_account_id: 10,
  to_account_id: 2,
  category_id: 5,
  status: "confirmed"
)

# 51 despesas variadas
require 'date'
random_despesas = [
  "Supermercado Zaffari", "Farmácia Panvel", "Assinatura Netflix", "Massagem com Mariana",
  "Uber", "IFood", "Café Starbucks", "Compra Amazon", "Padaria", "Ingresso Cinema"
]
accounts_user = [1, 2]
accounts_despesa = [5, 6, 7, 8]
categorias = (1..6).to_a
meses = [3, 4, 5]

51.times do
  Transaction.create!(
    description: random_despesas.sample,
    amount: rand(35..400),
    transaction_type: "expense",
    date: Date.new(2025, meses.sample, rand(1..27)),
    period: "2025-#{meses.sample.to_s.rjust(2, '0')}",
    from_account_id: accounts_user.sample,
    to_account_id: accounts_despesa.sample,
    category_id: categorias.sample,
    status: "confirmed"
  )
end

puts "Done."

puts "Criando grupos de parcelamento"

# Grupo 1: Notebook
notebook_group = TransactionGroup.create!(
  name: "Compra notebook",
  group_type: "installment",
  installment_count: 5,
  starts_on: Date.new(2025, 3, 10)
)

5.times do |i|
  Transaction.create!(
    description: "Notebook Dell",
    amount: 450,
    transaction_type: "expense",
    date: Date.new(2025, 3 + i, 10),
    period: "2025-#{(3 + i).to_s.rjust(2, '0')}",
    from_account_id: 2,
    to_account_id: 7,
    category_id: 1,
    installment: i + 1,
    transaction_group_id: notebook_group.id,
    status: i < 3 ? "confirmed" : "pending"
  )
end

# Grupo 2: Academia
gym_group = TransactionGroup.create!(
  name: "Academia anual",
  group_type: "installment",
  installment_count: 12,
  starts_on: Date.new(2025, 1, 5)
)

12.times do |i|
  Transaction.create!(
    description: "Mensalidade academia",
    amount: 120,
    transaction_type: "expense",
    date: Date.new(2025, 1 + i, 5),
    period: "2025-#{(1 + i).to_s.rjust(2, '0')}",
    from_account_id: 1,
    to_account_id: 6,
    category_id: 4,
    installment: i + 1,
    transaction_group_id: gym_group.id,
    status: i < 5 ? "confirmed" : "pending"
  )
end

# Grupo 3: Celular
phone_group = TransactionGroup.create!(
  name: "iPhone parcelado",
  group_type: "installment",
  installment_count: 10,
  starts_on: Date.new(2025, 2, 12)
)

10.times do |i|
  Transaction.create!(
    description: "iPhone 14",
    amount: 550,
    transaction_type: "expense",
    date: Date.new(2025, 2 + i, 12),
    period: "2025-#{(2 + i).to_s.rjust(2, '0')}",
    from_account_id: 2,
    to_account_id: 8,
    category_id: 1,
    installment: i + 1,
    transaction_group_id: phone_group.id,
    status: i < 4 ? "confirmed" : "pending"
  )
end

puts "Parcelamentos criados."
