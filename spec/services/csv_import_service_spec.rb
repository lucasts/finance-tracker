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

      it 'parses the expected number of transactions' do
        result = described_class.new(valid_csv_content).parse
        expect(result).to be_an(Array)
        expect(result.length).to eq(3)
      end

      it 'parses first transaction (income) correctly' do
        salary = described_class.new(valid_csv_content).parse[0]
        expect(salary[:line_number]).to eq(1)
        expect(salary[:description]).to eq('Salary')
        expect(salary[:amount]).to eq(BigDecimal('3000.00'))
        expect(salary[:event_date]).to eq('2025-06-01')
        expect(salary[:payment_date]).to eq('2025-06-01')
        expect(salary[:transaction_type]).to eq('income')
        expect(salary[:status]).to eq('confirmed')
        expect(salary[:raw_data]).to be_present
        expect(salary[:parsed_data]).to be_a(Hash)
      end

      it 'parses subsequent transactions (expense) correctly' do
        groceries = described_class.new(valid_csv_content).parse[1]
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

        service = described_class.new(csv_without_type)
        result = service.parse

        expect(result[0][:transaction_type]).to eq('income')
        expect(result[1][:transaction_type]).to eq('expense')
      end
    end

    context 'with malformed or invalid CSV' do
      it 'handles CSV without headers' do
        csv_without_headers = "2025-06-01,100.00,Test Transaction"

        service = described_class.new(csv_without_headers)
        result = service.parse

        expect(result).to be_an(Array)
        # First line will be treated as data since there's no header
        expect(result.length).to eq(1)
      end

      it 'handles lines with missing data' do
        incomplete_csv = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                        "2025-06-01,,Missing Amount,,,,\n" \
                        ",50.00,Missing Date,,,,"

        service = described_class.new(incomplete_csv)
        result = service.parse

        expect(result.length).to eq(2)
        expect(result[0][:amount]).to be_nil
        expect(result[1][:event_date]).to be_nil
      end

      it 'handles empty file' do
        empty_csv = ""

        service = described_class.new(empty_csv)
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

        service = described_class.new(numeric_csv)
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

        service = described_class.new(special_csv)
        result = service.parse

        expect(result.length).to eq(2)
        expect(result[0][:description]).to eq('Açaí com çédilha')
        expect(result[1][:description]).to eq('Тест кириллица')
      end

      it 'preserves original data in raw_data' do
        csv_content = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                     "2025-06-01,100.00,Test,Cat1,confirmed,income,1"

        service = described_class.new(csv_content)
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

        service = described_class.new(csv_content)
        result = service.parse

        # Single positive value with no type specified, infers income
        expect(result[0][:transaction_type]).to eq('income')
      end

      it 'infers expense for negative amounts when no type and mixed signs detected' do
        csv_content = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                     "2025-06-01,-50.25,Negative Amount,,,,"

        service = described_class.new(csv_content)
        result = service.parse

        # Single negative value, pattern detected, converts to expense
        expect(result[0][:transaction_type]).to eq('expense')
        expect(result[0][:amount]).to eq(BigDecimal('50.25'))
      end

      it 'uses specified type when present' do
        csv_content = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                     "2025-06-01,100.00,Specified Type,,,expense,"

        service = described_class.new(csv_content)
        result = service.parse

        expect(result[0][:transaction_type]).to eq('expense')
      end

      it 'uses default pending status when not specified' do
        csv_content = "data,valor,descricao,categoria,status,tipo,parcela\n" \
                     "2025-06-01,100.00,No Status,,,,"

        service = described_class.new(csv_content)
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

        service = described_class.new(multi_line_csv)
        result = service.parse

        expect(result.length).to eq(3)
        expect(result[0][:line_number]).to eq(1)
        expect(result[1][:line_number]).to eq(2)
        expect(result[2][:line_number]).to eq(3)
      end
    end

    context 'with semicolon-delimited headerless bank export (Brazilian format)' do
      let(:bank_export) do
        "21/11/2025;REND PAGO APLIC AUT MAIS;0,04\n" \
        "21/11/2025;CEEE      0000050970208;-336,68\n" \
        "27/11/2025;REMUNERACAO/SALARIO;28546,15"
      end

      it 'auto-detects semicolon delimiter and parses all rows' do
        result = described_class.new(bank_export).parse
        expect(result.length).to eq(3)
      end

      it 'extracts description from second column' do
        result = described_class.new(bank_export).parse
        expect(result[0][:description]).to eq('REND PAGO APLIC AUT MAIS')
        expect(result[1][:description]).to eq('CEEE      0000050970208')
        expect(result[2][:description]).to eq('REMUNERACAO/SALARIO')
      end

      it 'parses Brazilian-format amounts (comma decimal separator)' do
        result = described_class.new(bank_export).parse
        expect(result[0][:amount]).to eq(BigDecimal('0.04'))
        expect(result[1][:amount]).to eq(BigDecimal('336.68'))
        expect(result[2][:amount]).to eq(BigDecimal('28546.15'))
      end

      it 'parses DD/MM/YYYY dates into event_date and payment_date' do
        result = described_class.new(bank_export).parse
        expect(result[0][:event_date]).to eq('2025-11-21')
        expect(result[0][:payment_date]).to eq('2025-11-21')
        expect(result[2][:event_date]).to eq('2025-11-27')
      end

      it 'infers transaction type from sign' do
        result = described_class.new(bank_export).parse
        expect(result[0][:transaction_type]).to eq('income')
        expect(result[1][:transaction_type]).to eq('expense')
        expect(result[2][:transaction_type]).to eq('income')
      end

      it 'numbers lines correctly' do
        result = described_class.new(bank_export).parse
        expect(result[0][:line_number]).to eq(1)
        expect(result[1][:line_number]).to eq(2)
        expect(result[2][:line_number]).to eq(3)
      end

      it 'stores raw data' do
        result = described_class.new(bank_export).parse
        expect(result[0][:raw_data]).to be_present
      end
    end

    context 'with credit card CSV format (lançamento header)' do
      let(:credit_card_csv) do
        "data,lançamento,valor\n" \
        "2025-12-02,IOF COMPRA INTERNACIONA,1.47\n" \
        "2025-12-01,BACKBLAZE INC,41.64\n" \
        "2025-11-30,Google One,9.99\n" \
        "2025-11-18,AMAZON SERVICOS DE VAR,0.99\n" \
        "2025-11-14,NETFLIX ENTRETENIMENTO,44.9\n" \
        "2025-11-10,PAGAMENTO EFETUADO,-156.97"
      end

      it 'auto-detects credit card CSV format and parses all rows' do
        result = described_class.new(credit_card_csv).parse
        expect(result.length).to eq(6)
      end

      it 'extracts description from lançamento column' do
        result = described_class.new(credit_card_csv).parse
        expect(result[0][:description]).to eq('IOF COMPRA INTERNACIONA')
        expect(result[1][:description]).to eq('BACKBLAZE INC')
        expect(result[4][:description]).to eq('NETFLIX ENTRETENIMENTO')
        expect(result[5][:description]).to eq('PAGAMENTO EFETUADO')
      end

      it 'parses amounts correctly' do
        result = described_class.new(credit_card_csv).parse
        expect(result[0][:amount]).to eq(BigDecimal('1.47'))
        expect(result[1][:amount]).to eq(BigDecimal('41.64'))
        expect(result[4][:amount]).to eq(BigDecimal('44.9'))
        expect(result[5][:amount]).to eq(BigDecimal('156.97'))
      end

      it 'treats positive values as expenses (credit card charges)' do
        result = described_class.new(credit_card_csv).parse
        expect(result[0][:transaction_type]).to eq('expense')
        expect(result[1][:transaction_type]).to eq('expense')
        expect(result[2][:transaction_type]).to eq('expense')
      end

      it 'treats negative values as income (payments/credits)' do
        result = described_class.new(credit_card_csv).parse
        expect(result[5][:transaction_type]).to eq('income')
      end

      it 'parses ISO dates into event_date and payment_date' do
        result = described_class.new(credit_card_csv).parse
        expect(result[0][:event_date]).to eq('2025-12-02')
        expect(result[0][:payment_date]).to eq('2025-12-02')
        expect(result[5][:event_date]).to eq('2025-11-10')
      end

      it 'numbers lines correctly' do
        result = described_class.new(credit_card_csv).parse
        expect(result[0][:line_number]).to eq(1)
        expect(result[5][:line_number]).to eq(6)
      end

      it 'stores raw data and parsed_data' do
        result = described_class.new(credit_card_csv).parse
        expect(result[0][:raw_data]).to be_present
        parsed = JSON.parse(result[0][:raw_data])
        expect(parsed["lançamento"]).to eq('IOF COMPRA INTERNACIONA')
        expect(result[0][:parsed_data]).to be_a(Hash)
      end

      it 'defaults status to pending' do
        result = described_class.new(credit_card_csv).parse
        result.each { |t| expect(t[:status]).to eq('pending') }
      end

      it 'handles lancamento header without cedilla' do
        csv = "data,lancamento,valor\n2025-12-01,TEST PURCHASE,25.00"
        result = described_class.new(csv).parse
        expect(result.length).to eq(1)
        expect(result[0][:description]).to eq('TEST PURCHASE')
        expect(result[0][:transaction_type]).to eq('expense')
      end

      it 'handles lancamento header with cedilla stripped by encoding (lanamento)' do
        csv = "data,lanamento,valor\n2025-12-01,ENCODING TEST,15.00"
        result = described_class.new(csv).parse
        expect(result.length).to eq(1)
        expect(result[0][:description]).to eq('ENCODING TEST')
        expect(result[0][:transaction_type]).to eq('expense')
      end

      it 'handles content with BOM stripped and cedilla mangled' do
        csv = "data,lanamento,valor\r\n2025-12-02,IOF COMPRA,1.47\r\n2025-11-10,PAGAMENTO EFETUADO,-156.97"
        result = described_class.new(csv).parse
        expect(result.length).to eq(2)
        expect(result[0][:description]).to eq('IOF COMPRA')
        expect(result[0][:transaction_type]).to eq('expense')
        expect(result[1][:transaction_type]).to eq('income')
      end
    end

    context 'delimiter auto-detection edge cases' do
      it 'still handles comma-delimited files with headers' do
        csv = "data,valor,descricao,categoria,status,tipo,parcela\n" \
              "2025-06-01,3000.00,Salary,Trabalho,confirmed,income,"
        result = described_class.new(csv).parse
        expect(result.length).to eq(1)
        expect(result[0][:description]).to eq('Salary')
        expect(result[0][:amount]).to eq(BigDecimal('3000.00'))
      end

      it 'handles semicolon file with trailing blank lines' do
        csv = "01/01/2026;PIX TRANSF LUCAS TEI;-2100,00\n\n"
        result = described_class.new(csv).parse
        expect(result.length).to eq(1)
        expect(result[0][:description]).to eq('PIX TRANSF LUCAS TEI')
        expect(result[0][:amount]).to eq(BigDecimal('2100.00'))
      end

      it 'handles semicolon file with a single line' do
        csv = "05/12/2025;DEB AUTOR SPORT CLUB INT;-9,00"
        result = described_class.new(csv).parse
        expect(result.length).to eq(1)
        expect(result[0][:description]).to eq('DEB AUTOR SPORT CLUB INT')
        expect(result[0][:amount]).to eq(BigDecimal('9.00'))
        expect(result[0][:event_date]).to eq('2025-12-05')
      end
    end
  end
end
