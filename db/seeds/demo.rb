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
40.times do |i|
  day = (i % 28) + 1
  month = 4 + (i / 15)
  amount = 100 + (i % 10) * 23.5
  tx_type = i.even? ? "income" : "expense"
  category_id = (i % 6) + 1
  period = format("2025-%02d", month)
  description = "Lançamento #{i + 1}"

  from_id, to_id =
    if tx_type == "income"
      from = (i % 4 == 1) ? 10 : 9
      [from, 1]
    else
      [1, 5 + (i % 4)]
    end

  tx = Transaction.new(
    description: description,
    amount: amount,
    transaction_type: tx_type,
    date: Date.new(2025, month, day),
    period: period,
    from_account_id: from_id,
    to_account_id: to_id,
    category_id: category_id,
    status: "confirmed"
  )

  if i % 7 == 0
    tx.transaction_group_id = 1
    tx.installment = "#{(i % 5) + 1}/5"
  end

  tx.save!
end

puts "Demo seed complete."
