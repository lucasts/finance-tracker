#!/usr/bin/env ruby
# Sample data for testing

user = User.find_by(email: 'demo@finance-tracker.com')
if user.nil?
  puts "Demo user not found!"
  exit 1
end

# Get existing accounts and categories
checking = user.accounts.first
food = user.categories.find_by(name: 'Alimentação')
transport = user.categories.find_by(name: 'Transporte')
rent = user.categories.find_by(name: 'Aluguel')
salary = user.categories.find_by(name: 'Salário')

if checking.nil? || food.nil? || transport.nil? || rent.nil? || salary.nil?
  puts "Required accounts or categories not found!"
  exit 1
end

# Create sample transactions for current month and previous months to test projections
current_month = Date.current.beginning_of_month

# Previous months for historical data
(1..3).each do |months_ago|
  month_start = current_month - months_ago.months
  
  # Food expenses (varying amounts for projection)
  unless user.transactions.exists?(description: "Supermercado #{month_start.strftime('%b/%Y')}")
    user.transactions.create!(
      description: "Supermercado #{month_start.strftime('%b/%Y')}",
      date: month_start + rand(1..5).days,
      amount: 280 + rand(100),
      transaction_type: 'expense',
      account: checking,
      category: food
    )
  end
  
  # Transport expenses
  unless user.transactions.exists?(description: "Transporte #{month_start.strftime('%b/%Y')}")
    user.transactions.create!(
      description: "Transporte #{month_start.strftime('%b/%Y')}",
      date: month_start + rand(6..10).days,
      amount: 100 + rand(50),
      transaction_type: 'expense',
      account: checking,
      category: transport
    )
  end
  
  # Rent (fixed)
  unless user.transactions.exists?(description: "Aluguel #{month_start.strftime('%b/%Y')}")
    user.transactions.create!(
      description: "Aluguel #{month_start.strftime('%b/%Y')}",
      date: month_start + rand(11..15).days,
      amount: 1200,
      transaction_type: 'expense',
      account: checking,
      category: rent
    )
  end
end

# Current month transactions (partial)
unless user.transactions.exists?(description: 'Salário Junho 2025')
  user.transactions.create!(
    description: 'Salário Junho 2025',
    date: current_month + 1.day,
    amount: 5000.0,
    transaction_type: 'income',
    account: checking,
    category: salary
  )
end

unless user.transactions.exists?(description: 'Supermercado - início mês')
  user.transactions.create!(
    description: 'Supermercado - início mês',
    date: current_month + 3.days,
    amount: 150.0,
    transaction_type: 'expense',
    account: checking,
    category: food
  )
end

puts "Transações de exemplo criadas!"
puts "Total de transações do usuário: #{user.transactions.count}"
puts "Transações do mês atual: #{user.transactions.where('date >= ?', current_month).count}"
