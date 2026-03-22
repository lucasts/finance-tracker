require 'rails_helper'

RSpec.describe 'Installment Status Logic', type: :model do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category, :expense, user: user) }

  describe 'installment plan with future installments' do
    it 'creates first installment as confirmed and future ones as pending' do
      # Criar um plano de parcelamento que começa ontem
      plan = create(:installment_plan,
        user: user,
        category: category,
        installment_count: 3,
        total_amount: 300.00,
        starts_on: 1.day.ago
      )

      # Criar as transações do parcelamento
      plan.create_installment_transactions!(
        description_base: "Compra parcelada",
        transaction_type: 'expense',
        from_account_id: account.id,
        to_account_id: create(:account, user: user).id
      )

      transactions = plan.transactions.order(:installment_number)

      # Primeira parcela (ontem) deve ser confirmed
      expect(transactions.first.status).to eq('confirmed')
      expect(transactions.first.payment_date).to be <= Date.current

      # Segunda parcela (mês que vem) deve ser pending
      expect(transactions.second.status).to eq('pending')
      expect(transactions.second.payment_date).to be > Date.current

      # Terceira parcela (2 meses no futuro) deve ser pending
      expect(transactions.third.status).to eq('pending')
      expect(transactions.third.payment_date).to be > transactions.second.payment_date
    end

    it 'creates all installments as pending when plan starts in the future' do
      # Criar um plano que começa no futuro
      plan = create(:installment_plan,
        user: user,
        category: category,
        installment_count: 3,
        total_amount: 300.00,
        starts_on: 1.month.from_now
      )

      # Criar as transações do parcelamento
      plan.create_installment_transactions!(
        description_base: "Compra futura parcelada",
        transaction_type: 'expense',
        from_account_id: account.id,
        to_account_id: create(:account, user: user).id
      )

      transactions = plan.transactions.order(:installment_number)

      # Todas as parcelas devem ser pending pois todas são futuras
      transactions.each do |transaction|
        expect(transaction.status).to eq('pending')
        expect(transaction.payment_date).to be > Date.current
      end
    end
  end

  describe 'single transaction automatic status' do
    it 'creates pending status for future transactions' do
      transaction = create(:transaction, :expense,
        user: user,
        from_account: account,
        category: category,
        payment_date: 1.week.from_now,
        status: nil # Let it determine automatically
      )

      expect(transaction.status).to eq('pending')
    end

    it 'creates confirmed status for past transactions' do
      transaction = create(:transaction, :expense,
        user: user,
        from_account: account,
        category: category,
        payment_date: 1.week.ago,
        status: nil # Let it determine automatically
      )

      expect(transaction.status).to eq('confirmed')
    end
  end
end
