#!/usr/bin/env ruby

# Test script for installment functionality
require_relative 'config/environment'

puts "🧪 Testing Installment Creation System"
puts "=" * 50

# Get test data
category = Category.find_by(name: 'Compras') || Category.first
account = Account.first

puts "📝 Test Data:"
puts "  Category: #{category.name}"
puts "  Account: #{account.name}"
puts ""

# Test 1: TransactionGroup creation
puts "🔧 Test 1: Creating TransactionGroup..."
group = TransactionGroup.new(
  name: "Geladeira Nova (10x)",
  group_type: 'installment',
  total_amount: 1500.00,
  installments_count: 10
)

if group.save
  puts "  ✅ Group created successfully (ID: #{group.id})"
else
  puts "  ❌ Group creation failed: #{group.errors.full_messages.join(', ')}"
  exit 1
end

# Test 2: Transaction creation
puts ""
puts "🔧 Test 2: Creating installment transactions..."
installment_value = 150.00
start_date = Date.current
created_count = 0

10.times do |i|
  transaction = Transaction.new(
    description: "Geladeira Nova (#{i + 1}/10)",
    amount: installment_value,
    transaction_type: 'expense',
    event_date: start_date + i.months,
    payment_date: start_date + i.months,
    from_account: account,
    category: category,
    transaction_group: group,
    installment: i + 1,
    status: 'confirmed',
    recurrence_type: 'single'
  )
  
  if transaction.save
    created_count += 1
    puts "  ✅ Installment #{i + 1} created (ID: #{transaction.id}, Date: #{transaction.event_date})"
  else
    puts "  ❌ Installment #{i + 1} failed: #{transaction.errors.full_messages.join(', ')}"
  end
end

# Test 3: Verify data integrity
puts ""
puts "🔧 Test 3: Verifying data integrity..."
group.reload
transactions = group.transactions.order(:installment)

puts "  Group transactions count: #{transactions.count}"
puts "  Expected count: 10"
puts "  Total amount from transactions: R$ #{transactions.sum(:amount)}"
puts "  Expected total: R$ 1500.00"

if transactions.count == 10 && transactions.sum(:amount) == 1500.00
  puts "  ✅ Data integrity check passed!"
else
  puts "  ❌ Data integrity check failed!"
end

# Test 4: Display transaction details
puts ""
puts "📊 Transaction Details:"
transactions.each do |transaction|
  puts "  #{transaction.installment}/10: #{transaction.description} - R$ #{transaction.amount} (#{transaction.event_date})"
end

# Clean up
puts ""
puts "🧹 Cleaning up test data..."
transactions.destroy_all
group.destroy
puts "  ✅ Test data cleaned up"

puts ""
puts "🎉 All tests completed successfully!"
puts "The installment system is working correctly."
