puts "Seeding essential system data..."

# Account Types - Essential for the system to work
puts "Creating account types..."
AccountType.find_or_create_by!(code: "CHECKING")    { |at| at.assign_attributes(role: "asset",   name: "Conta Corrente") }
AccountType.find_or_create_by!(code: "CREDIT_CARD") { |at| at.assign_attributes(role: "asset",   name: "Cartão de Crédito") }
AccountType.find_or_create_by!(code: "CASH")    { |at| at.assign_attributes(role: "asset",   name: "Dinheiro") }
AccountType.find_or_create_by!(code: "SAVINGS") { |at| at.assign_attributes(role: "asset",   name: "Poupança") }
AccountType.find_or_create_by!(code: "EXPENSE") { |at| at.assign_attributes(role: "expense", name: "Despesa") }
AccountType.find_or_create_by!(code: "REVENUE") { |at| at.assign_attributes(role: "income",  name: "Receita") }

puts "Essential setup complete - #{AccountType.count} account types created."