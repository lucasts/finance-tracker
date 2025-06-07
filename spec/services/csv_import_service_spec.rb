require 'rails_helper'

RSpec.describe CsvImportService, type: :service do
  describe '#parse' do
    context 'with valid CSV file using expected headers' do
      let(:valid_csv_content) do
        "data,valor,descricao,categoria,status,tipo,parcela\n" \
        "2025-06-01,3000.00,Salary,Trabalho,confirmed,income,\n" \
        "2025-06-02,-150.75,Groceries,Alimentação,pending,expense,\n" \
        "2025-06-03,-45.20,Gas,Transporte,confirmed,expense,"
      end
      
      it 'parses transactions correctly' do
        service = CsvImportService.new(valid_csv_content)
        result = service.parse
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(3)
        
        # Test first transaction (Salary)
        salary = result[0]
        expect(salary[:line_number]).to eq(1)
        expect(salary[:description]).to eq('Salary')
        expect(salary[:amount]).to eq(BigDecimal('3000.00'))
        expect(salary[:event_date]).to eq('2025-06-01')
        expect(salary[:payment_date]).to eq('2025-06-01')
        expect(salary[:transaction_type]).to eq('income')
        expect(salary[:status]).to eq('confirmed')
        expect(salary[:raw_data]).to be_present
        expect(salary[:parsed_data]).to be_a(Hash)
        
        # Test second transaction (Groceries)  
        groceries = result[1]
        expect(groceries[:line_number]).to eq(2)
        expect(groceries[:description]).to eq('Groceries')
        expect(groceries[:amount]).to eq(BigDecimal('150.75'))
        expect(groceries[:transaction_type]).to eq('expense')
        expect(groceries[:status]).to eq('pending')
      end
      
      it 'infers transaction type from amount sign when no type specified' do
        csv_without_type = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                          "2025-06-01,100.50,Income Test,,confirmed,,\n" \
                          "2025-06-02,-50.25,Expense Test,,pending,,"
        
        service = CsvImportService.new(csv_without_type)
        result = service.parse
        
        expect(result[0][:transaction_type]).to eq('income')
        expect(result[1][:transaction_type]).to eq('expense')
      end
    end
    
    context 'with malformed or invalid CSV' do
      it 'handles CSV without headers' do
        csv_without_headers = "2025-06-01,100.00,Test Transaction"
        
        service = CsvImportService.new(csv_without_headers)
        result = service.parse
        
        expect(result).to be_an(Array)
        # First line will be treated as data since there's no header
        expect(result.length).to eq(1)
      end
      
      it 'handles lines with missing data' do
        incomplete_csv = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                        "2025-06-01,,Missing Amount,,,,\n" \
                        ",50.00,Missing Date,,,,"
        
        service = CsvImportService.new(incomplete_csv)
        result = service.parse
        
        expect(result.length).to eq(2)
        expect(result[0][:amount]).to be_nil
        expect(result[1][:event_date]).to be_nil
      end
      
      it 'handles empty file' do
        empty_csv = ""
        
        service = CsvImportService.new(empty_csv)
        result = service.parse
        
        expect(result).to be_an(Array)
        expect(result).to be_empty
      end
    end
    
    context 'edge cases' do
      it 'handles numeric values in different formats' do
        numeric_csv = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                     "2025-06-01,1000,Integer Value,,,,\n" \
                     "2025-06-02,50.25,Decimal Value,,,,\n" \
                     "2025-06-03,-75.50,Negative Value,,,,"
        
        service = CsvImportService.new(numeric_csv)
        result = service.parse
        
        expect(result.length).to eq(3)
        expect(result[0][:amount]).to eq(BigDecimal('1000'))
        expect(result[1][:amount]).to eq(BigDecimal('50.25'))
        expect(result[2][:amount]).to eq(BigDecimal('75.50'))
      end
      
      it 'handles special characters in description' do
        special_csv = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                     "2025-06-01,100.00,Açaí com çédilha,,,,\n" \
                     "2025-06-02,75.25,Тест кириллица,,,,"
        
        service = CsvImportService.new(special_csv)
        result = service.parse
        
        expect(result.length).to eq(2)
        expect(result[0][:description]).to eq('Açaí com çédilha')
        expect(result[1][:description]).to eq('Тест кириллица')
      end
      
      it 'preserves original data in raw_data' do
        csv_content = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                     "2025-06-01,100.00,Test,Cat1,confirmed,income,1"
        
        service = CsvImportService.new(csv_content)
        result = service.parse
        
        expect(result[0][:raw_data]).to be_present
        raw_data = JSON.parse(result[0][:raw_data])
        expect(raw_data).to include(
          'data' => '2025-06-01',
          'valor' => '100.00',
          'descricao' => 'Test',
          'categoria' => 'Cat1',
          'status' => 'confirmed',
          'tipo' => 'income',
          'parcela' => '1'
        )
      end
    end
    
    context 'transaction type behavior' do
      it 'infers income for positive amounts when no type and no negative values in file' do
        csv_content = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                     "2025-06-01,100.50,Positive Amount,,,,"
        
        service = CsvImportService.new(csv_content)
        result = service.parse
        
        # Single positive value, uses legacy inference, infers income
        expect(result[0][:transaction_type]).to eq('income')
      end
      
      it 'infers expense for negative amounts when no type and mixed signs detected' do
        csv_content = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                     "2025-06-01,-50.25,Negative Amount,,,,"
        
        service = CsvImportService.new(csv_content)
        result = service.parse
        
        # Single negative value, pattern detected, converts to expense
        expect(result[0][:transaction_type]).to eq('expense')
        expect(result[0][:amount]).to eq(BigDecimal('50.25'))
      end
      
      it 'uses specified type when present' do
        csv_content = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                     "2025-06-01,100.00,Specified Type,,,expense,"
        
        service = CsvImportService.new(csv_content)
        result = service.parse
        
        expect(result[0][:transaction_type]).to eq('expense')
      end
      
      it 'uses default pending status when not specified' do
        csv_content = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                     "2025-06-01,100.00,No Status,,,,"
        
        service = CsvImportService.new(csv_content)
        result = service.parse
        
        expect(result[0][:status]).to eq('pending')
      end
    end
    
    context 'multiple lines' do
      it 'numbers lines correctly' do
        multi_line_csv = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                        "2025-06-01,100.00,First,,,,\n" \
                        "2025-06-02,200.00,Second,,,,\n" \
                        "2025-06-03,300.00,Third,,,,"
        
        service = CsvImportService.new(multi_line_csv)
        result = service.parse
        
        expect(result.length).to eq(3)
        expect(result[0][:line_number]).to eq(1)
        expect(result[1][:line_number]).to eq(2)
        expect(result[2][:line_number]).to eq(3)
      end
    end
  end
end
