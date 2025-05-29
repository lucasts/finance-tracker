puts "Seeding demo data..."

require 'date'

accounts = {
  itau:      Account.create!(name: "Itaú", account_type: AccountType.find_by(code: "BANK")),
  nubank:    Account.create!(name: "Nubank", account_type: AccountType.find_by(code: "CREDIT"), closing_day: 28, due_day: 5),
  carteira:  Account.create!(name: "Carteira", account_type: AccountType.find_by(code: "CASH")),
  poupanca:  Account.create!(name: "Poupança Inter", account_type: AccountType.find_by(code: "SAVINGS")),
  zaffari:   Account.create!(name: "Zaffari", account_type: AccountType.find_by(code: "EXPENSE")),
  panvel:    Account.create!(name: "Panvel", account_type: AccountType.find_by(code: "EXPENSE")),
  netflix:   Account.create!(name: "Netflix", account_type: AccountType.find_by(code: "EXPENSE")),
  massagem:  Account.create!(name: "Mariana Massagem", account_type: AccountType.find_by(code: "EXPENSE")),
  empregador:Account.create!(name: "Empregador", account_type: AccountType.find_by(code: "REVENUE")),
  pix_joana: Account.create!(name: "Pix Joana", account_type: AccountType.find_by(code: "REVENUE"))
}

categories = Category.all.index_by(&:name)

puts "Seeding realistic transactions..."

random_despesas = [
  "Supermercado Zaffari", "Farmácia Panvel", "Assinatura Netflix", "Massagem com Mariana",
  "Uber", "IFood", "Café Starbucks", "Compra Amazon", "Padaria", "Ingresso Cinema"
]
accounts_user = [accounts[:itau], accounts[:nubank]]
accounts_despesa = [accounts[:zaffari], accounts[:panvel], accounts[:netflix], accounts[:massagem]]
meses = [3, 4, 5]

# Receitas e despesas variadas, e exemplos de recorrência
income_descriptions = [
  ["Salário mensal", "Salário", "fixed"],
  ["Freelance", "Freelance", "single"],
  ["PIX Joana", "PIX Recebido", "single"]
]

income_count = {5 => 0, 4 => 0, 3 => 0}
60.times do |i|
  mes = meses.sample
  if income_count[mes] < 3
    desc, cat_code, recurrence = income_descriptions.sample
    event_date = Date.new(2025, mes, rand(1..28))
    amount = rand(350..700)
    Transaction.create!(
      description: desc,
      amount: amount,
      transaction_type: "income",
      event_date: event_date,
      payment_date: event_date,
      from_account: accounts[:empregador],
      to_account: [accounts[:itau], accounts[:nubank]].sample,
      category: categories[cat_code],
      recurrence_type: recurrence,
      status: "confirmed"
    )
    income_count[mes] += 1
  else
    event_date = Date.new(2025, mes, rand(1..28))
    amount = rand(35..400)
    from_account = accounts_user.sample
    is_credit = (from_account == accounts[:nubank])
    payment_date = is_credit ? event_date.next_month.change(day: 5) : event_date
    Transaction.create!(
      description: random_despesas.sample,
      amount: amount,
      transaction_type: "expense",
      event_date: event_date,
      payment_date: payment_date,
      from_account: from_account,
      to_account: accounts_despesa.sample,
      category: categories.values.sample,
      recurrence_type: ["fixed", "recurring", "single"].sample,
      status: "confirmed"
    )
  end
end

puts "Criando grupos de parcelamento..."

notebook_group = TransactionGroup.create!(
  name: "Compra notebook",
  group_type: "installment",
  installment_count: 5,
  starts_on: Date.new(2025, 3, 10)
)
5.times do |i|
  event_date = Date.new(2025, 3 + i, 10)
  payment_date = event_date.next_month.change(day: 5)
  Transaction.create!(
    description: "Notebook Dell",
    amount: 450,
    transaction_type: "expense",
    event_date: event_date,
    payment_date: payment_date,
    from_account: accounts[:nubank],
    to_account: accounts[:netflix],
    category: categories["Compras"],
    recurrence_type: "fixed",
    installment: i + 1,
    transaction_group: notebook_group,
    status: i < 3 ? "confirmed" : "pending"
  )
end

gym_group = TransactionGroup.create!(
  name: "Academia anual",
  group_type: "installment",
  installment_count: 12,
  starts_on: Date.new(2025, 1, 5)
)
12.times do |i|
  event_date = Date.new(2025, 1 + i, 5)
  Transaction.create!(
    description: "Mensalidade academia",
    amount: 120,
    transaction_type: "expense",
    event_date: event_date,
    payment_date: event_date,
    from_account: accounts[:itau],
    to_account: accounts[:panvel],
    category: categories["Farmácia"],
    recurrence_type: "fixed",
    installment: i + 1,
    transaction_group: gym_group,
    status: i < 5 ? "confirmed" : "pending"
  )
end

phone_group = TransactionGroup.create!(
  name: "iPhone parcelado",
  group_type: "installment",
  installment_count: 10,
  starts_on: Date.new(2025, 2, 12)
)
10.times do |i|
  event_date = Date.new(2025, 2 + i, 12)
  payment_date = event_date.next_month.change(day: 5)
  Transaction.create!(
    description: "iPhone 14",
    amount: 550,
    transaction_type: "expense",
    event_date: event_date,
    payment_date: payment_date,
    from_account: accounts[:nubank],
    to_account: accounts[:massagem],
    category: categories["Compras"],
    recurrence_type: "fixed",
    installment: i + 1,
    transaction_group: phone_group,
    status: i < 4 ? "confirmed" : "pending"
  )
end

# Exemplos de status pending e cancelled
Transaction.create!(
  description: "Viagem futura (prevista)",
  amount: 2800,
  transaction_type: "expense",
  event_date: Date.new(2025, 6, 20),
  payment_date: Date.new(2025, 7, 10),
  from_account: accounts[:nubank],
  to_account: accounts[:zaffari],
  category: categories["Restaurante"],
  recurrence_type: "single",
  status: "pending"
)
Transaction.create!(
  description: "Compra cancelada",
  amount: 430,
  transaction_type: "expense",
  event_date: Date.new(2025, 5, 15),
  payment_date: Date.new(2025, 5, 15),
  from_account: accounts[:itau],
  to_account: accounts[:zaffari],
  category: categories["Compras"],
  recurrence_type: "single",
  status: "cancelled"
)

# Pix entre contas do usuário
Transaction.create!(
  description: "Transferência Poupança > Itaú",
  amount: 1200,
  transaction_type: "income",
  event_date: Date.new(2025, 5, 12),
  payment_date: Date.new(2025, 5, 12),
  from_account: accounts[:poupanca],
  to_account: accounts[:itau],
  category: categories["PIX Recebido"],
  recurrence_type: "single",
  status: "confirmed"
)

# === Faturas de cartão de crédito (CreditStatement) ===
# Cria faturas Nubank para março, abril e maio de 2025
statements = {}
[3, 4, 5].each do |month|
  year_month = "2025-#{format('%02d', month)}"
  closed_on = Date.new(2025, month, accounts[:nubank].closing_day)
  due_on = Date.new(2025, month + 1, accounts[:nubank].due_day)
  # Inicialmente, amount_due será atualizado depois
  statements[month] = CreditStatement.create!(
    account: accounts[:nubank],
    month: year_month,
    amount_due: 0,
    amount_paid: month == 3 ? 0 : 0, # só será atualizado depois
    status: month == 3 ? :paid : (month == 4 ? :overdue : :open),
    closed_on: closed_on,
    due_on: due_on,
    paid_on: (month == 3 ? due_on : nil)
  )
end

# Associa despesas Nubank às faturas corretas e soma valores
statement_sums = {3 => 0, 4 => 0, 5 => 0}
Transaction.where(from_account: accounts[:nubank]).find_each do |tx|
  month = tx.event_date.month
  if statements[month]
    # Se existir credit_statement_id, associe aqui
    if tx.respond_to?(:credit_statement_id)
      tx.update!(credit_statement_id: statements[month].id)
    end
    statement_sums[month] += tx.amount
  end
end

# Atualiza o amount_due de cada fatura e amount_paid para a de março
statements.each do |month, statement|
  statement.update!(
    amount_due: statement_sums[month],
    amount_paid: (month == 3 ? statement_sums[month] : 0)
  )
end

# Exemplo: pagamento da fatura de março (status: paid)
Transaction.create!(
  description: "Pagamento fatura Nubank Março",
  amount: statements[3].amount_due,
  transaction_type: "expense",
  event_date: statements[3].due_on,
  payment_date: statements[3].due_on,
  from_account: accounts[:itau],
  to_account: accounts[:nubank],
  category: categories["Pagamentos"] || categories.values.sample,
  recurrence_type: "single",
  status: "confirmed"
)

puts "Parcelamentos criados."
puts "Faturas de cartão criadas."
puts "Demo seed finalizado com sucesso."