require 'rails_helper'

RSpec.describe DefaultCategoriesService, type: :service do
  describe '.create_for_user' do
    context 'when creating default categories for a new user' do
      let(:user) { create(:user) }

      before do
        # Limpa categorias que podem ter sido criadas pelo callback
        user.categories.destroy_all
        # Permite criar categorias padrão mesmo em ambiente de teste para este spec
        allow(Rails.env).to receive(:test?).and_return(false)
      end

      it 'creates expense categories with descriptions' do
        expect {
          described_class.create_for_user(user)
        }.to change { user.categories.expense.count }.from(0).to(11)
      end

      it 'creates income categories with descriptions' do
        expect {
          described_class.create_for_user(user)
        }.to change { user.categories.income.count }.from(0).to(3)
      end

      it 'creates categories with proper descriptions' do
        described_class.create_for_user(user)

        habitacao = user.categories.find_by(name: 'Habitação')
        expect(habitacao).to be_present
        expect(habitacao.description).to include('Aluguel')
        expect(habitacao.category_type).to eq('expense')

        salario = user.categories.find_by(name: 'Salário')
        expect(salario).to be_present
        expect(salario.description).to include('trabalho')
        expect(salario.category_type).to eq('income')
      end

      it 'does not create duplicate categories' do
        # Primeiro chamada
        described_class.create_for_user(user)
        initial_count = user.categories.count

        # Segunda chamada não deve criar duplicatas
        described_class.create_for_user(user)
        expect(user.categories.count).to eq(initial_count)
      end
    end

    context 'in test environment' do
      let(:user) { create(:user) }

      before do
        user.categories.destroy_all
        allow(Rails.env).to receive(:test?).and_return(true)
      end

      it 'does not create categories to avoid test conflicts' do
        expect {
          described_class.create_for_user(user)
        }.not_to change { user.categories.count }
      end
    end
  end
end
