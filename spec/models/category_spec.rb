require 'rails_helper'

RSpec.describe Category, type: :model do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }

  describe 'validations' do
    it { should validate_presence_of(:name) }
    
    it 'accepts valid names' do
      expect(build(:category, name: 'Alimentação', user: user)).to be_valid
      expect(build(:category, name: 'Transporte', user: user)).to be_valid
      expect(build(:category, name: 'Saúde', user: user)).to be_valid
    end
    
    it 'rejects empty names' do
      expect(build(:category, name: '', user: user)).not_to be_valid
      expect(build(:category, name: nil, user: user)).not_to be_valid
      expect(build(:category, name: '   ', user: user)).not_to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:transactions).dependent(:restrict_with_error) }
    
    it 'belongs to a user' do
      expect(category.user).to be_present
      expect(category.user).to be_a(User)
    end
    
    it 'can have multiple transactions' do
      transaction1 = create(:transaction, category: category, user: user)
      transaction2 = create(:transaction, category: category, user: user)
      
      expect(category.transactions).to include(transaction1, transaction2)
      expect(category.transactions.count).to eq(2)
    end
    
    it 'does not allow deletion if there are transactions' do
      create(:transaction, category: category, user: user)
      
      expect { category.destroy }.not_to change(Category, :count)
      expect(category.errors[:base]).to be_present
    end
  end

  describe 'business methods' do
    describe '#variable_expense_category?' do
      it 'identifies variable expense categories' do
        variable_category = create(:category, name: 'Supermercado Teste', user: user)
        fixed_category = create(:category, name: 'Aluguel', user: user)
        
        expect(variable_category.variable_expense_category?).to be true
        expect(fixed_category.variable_expense_category?).to be false
      end
      
      it 'recognizes variable expense keywords' do
        keywords = ['supermercado', 'mercado', 'farmácia', 'gasolina', 'combustível', 'consulta', 'médico', 'restaurante']
        
        keywords.each do |keyword|
          category = create(:category, name: "Categoria #{keyword.capitalize}", user: user)
          expect(category.variable_expense_category?).to be true
        end
      end
      
      it 'is case insensitive' do
        category = create(:category, name: 'SUPERMERCADO GRANDE', user: user)
        expect(category.variable_expense_category?).to be true
      end
    end

    describe '#monthly_average' do
      before do
        # Create transactions from last 3 months
        3.times do |i|
          month_date = (i + 1).months.ago.beginning_of_month + 15.days
          create(:transaction, :confirmed, 
                 category: category, 
                 user: user,
                 amount: 100 + (i * 50),
                 event_date: month_date)
        end
      end
      
      it 'calculates monthly average correctly' do
        # Average of 100 + 150 + 200 = 150
        expect(category.monthly_average(months_back: 6)).to eq(150.0)
      end
      
      it 'returns zero when there are no transactions' do
        empty_category = create(:category, user: user)
        expect(empty_category.monthly_average).to eq(0)
      end
      
      it 'considers only confirmed transactions' do
        create(:transaction, :pending, 
               category: category, 
               user: user,
               amount: 999,
               event_date: 1.month.ago)
               
        # Não deve incluir a transação pendente
        expect(category.monthly_average(months_back: 6)).to eq(150.0)
      end
    end

    describe '#expense_analysis' do
      it 'calls analysis service with correct parameters' do
        analysis_service = double('VariableExpenseAnalysisService')
        allow(VariableExpenseAnalysisService).to receive(:new).and_return(analysis_service)
        allow(analysis_service).to receive(:call).and_return({ average: 150, variance: 25 })
        
        result = category.expense_analysis(timeframe_months: 6, analysis_date: Date.current)
        
        expect(VariableExpenseAnalysisService).to have_received(:new).with(
          category,
          timeframe_months: 6,
          analysis_date: Date.current
        )
        expect(result).to eq({ average: 150, variance: 25 })
      end
    end

    describe '#projected_expense' do
      it 'calls projection service correctly' do
        allow(VariableExpenseAnalyzerService).to receive(:projected_expense_for_category)
          .and_return(250.0)
        
        result = category.projected_expense(2, user)
        
        expect(VariableExpenseAnalyzerService).to have_received(:projected_expense_for_category)
          .with(category, 2, user)
        expect(result).to eq(250.0)
      end
      
      it 'uses category user when not specified' do
        allow(VariableExpenseAnalyzerService).to receive(:projected_expense_for_category)
          .and_return(250.0)
        
        category.projected_expense(1)
        
        expect(VariableExpenseAnalyzerService).to have_received(:projected_expense_for_category)
          .with(category, 1, category.user)
      end
    end
  end

  describe 'edge cases' do
    it 'handles very long names' do
      long_name = 'a' * 255
      category = build(:category, name: long_name, user: user)
      expect(category).to be_valid
    end
    
    it 'handles special characters in name' do
      special_names = ['Café & Restaurante', 'Saúde (médico)', 'Transporte - Uber/99']
      
      special_names.each do |name|
        category = build(:category, name: name, user: user)
        expect(category).to be_valid
      end
    end
    
    it 'calculates averages with decimal values' do
      create(:transaction, :confirmed,
             category: category,
             user: user,
             amount: 33.33,
             event_date: 1.month.ago)
             
      create(:transaction, :confirmed,
             category: category,
             user: user,
             amount: 66.67,
             event_date: 2.months.ago)
             
      expect(category.monthly_average(months_back: 6)).to eq(50.0)
    end
  end
end
