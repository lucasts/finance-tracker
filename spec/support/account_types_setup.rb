# Ensure basic AccountTypes exist for tests
RSpec.configure do |config|
  config.before(:suite) do
    # Create the basic account types that the application expects
    AccountType.find_or_create_by!(code: 'CHECKING') do |at|
      at.assign_attributes(role: 'asset', name: 'Conta Corrente')
    end

    AccountType.find_or_create_by!(code: 'CREDIT_CARD') do |at|
      at.assign_attributes(role: 'asset', name: 'Cartão de Crédito')
    end

    AccountType.find_or_create_by!(code: 'CASH') do |at|
      at.assign_attributes(role: 'asset', name: 'Dinheiro')
    end

    AccountType.find_or_create_by!(code: 'SAVINGS') do |at|
      at.assign_attributes(role: 'asset', name: 'Poupança')
    end

    AccountType.find_or_create_by!(code: 'EXPENSE') do |at|
      at.assign_attributes(role: 'expense', name: 'Despesa')
    end

    AccountType.find_or_create_by!(code: 'REVENUE') do |at|
      at.assign_attributes(role: 'income', name: 'Receita')
    end
  end
end
