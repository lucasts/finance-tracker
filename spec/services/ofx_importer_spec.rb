require 'rails_helper'

RSpec.describe OfxImportService, type: :service do
  describe '#parse' do
    context 'with valid OFX file' do
      let(:ofx_content) do
        File.read(Rails.root.join('spec/fixtures/files/sample.ofx'))
      end

      it 'parses transactions correctly' do
        service = OfxImportService.new(ofx_content)
        result = service.parse

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        # First transaction (Supermarket - debit)
        first_transaction = result[0]
        expect(first_transaction[:line_number]).to eq(1)
        expect(first_transaction[:external_id]).to eq('1')
        expect(first_transaction[:description]).to eq('Supermercado')
        expect(first_transaction[:amount]).to eq(-200.00)
        expect(first_transaction[:event_date]).to eq(Date.new(2024, 1, 2))
        expect(first_transaction[:payment_date]).to eq(Date.new(2024, 1, 2))
        expect(first_transaction[:transaction_type]).to eq('expense')
        expect(first_transaction[:status]).to eq('pending')
        expect(first_transaction[:raw_data]).to be_present
        expect(first_transaction[:parsed_data]).to be_a(Hash)

        # Second transaction (Salary - credit)
        second_transaction = result[1]
        expect(second_transaction[:line_number]).to eq(2)
        expect(second_transaction[:external_id]).to eq('2')
        expect(second_transaction[:description]).to eq('Salario')
        expect(second_transaction[:amount]).to eq(1000.00)
        expect(second_transaction[:transaction_type]).to eq('income')
        expect(second_transaction[:status]).to eq('pending')
      end

      it 'preserves original data in raw_data' do
        service = OfxImportService.new(ofx_content)
        result = service.parse

        first_transaction = result[0]
        raw_data = JSON.parse(first_transaction[:raw_data])
        
        expect([raw_data['amount'], raw_data['amount'].to_f]).to include(-200.00)
        expect(raw_data).to include(
          'fit_id' => '1',
          'posted_at' => '2024-01-02'
        )
      end
    end

    context 'com OFX customizado' do
      let(:custom_ofx) do
        <<~OFX
          OFXHEADER:100
          DATA:OFXSGML
          VERSION:102

          <OFX>
          <BANKMSGSRSV1>
          <STMTTRNRS>
          <STMTRS>
          <CURDEF>BRL
          <BANKACCTFROM>
          <BANKID>0001
          <ACCTID>123456
          </BANKACCTFROM>
          <BANKTRANLIST>
          <STMTTRN>
          <TRNTYPE>CREDIT
          <DTPOSTED>20250605
          <TRNAMT>500.50
          <FITID>TEST001
          <MEMO>Transfer from savings
          <NAME>Internal Transfer
          </STMTTRN>
          <STMTTRN>
          <TRNTYPE>DEBIT
          <DTPOSTED>20250604
          <TRNAMT>-25.75
          <FITID>TEST002
          <MEMO>ATM withdrawal
          </STMTTRN>
          </BANKTRANLIST>
          <LEDGERBAL>
          <BALAMT>474.75
          </LEDGERBAL>
          </STMTRS>
          </STMTTRNRS>
          </BANKMSGSRSV1>
          </OFX>
        OFX
      end

      it 'parses transactions with memo and name' do
        service = OfxImportService.new(custom_ofx)
        result = service.parse

        expect(result.length).to eq(2)

        # First transaction with memo and name
        first_transaction = result[0]
        expect(first_transaction[:description]).to eq('Transfer from savings')
        expect(first_transaction[:amount]).to eq(500.50)
        expect(first_transaction[:transaction_type]).to eq('income')
        expect(first_transaction[:external_id]).to eq('TEST001')

        # Second transaction with memo only
        second_transaction = result[1]
        expect(second_transaction[:description]).to eq('ATM withdrawal')
        expect(second_transaction[:amount]).to eq(-25.75)
        expect(second_transaction[:transaction_type]).to eq('expense')
      end
    end

    context 'error cases' do
      it 'raises error for empty content' do
        expect {
          OfxImportService.new('').parse
        }.to raise_error(StandardError, 'Empty OFX content')
      end

      it 'raises error for nil content' do
        expect {
          OfxImportService.new(nil).parse
        }.to raise_error(StandardError, 'Empty OFX content')
      end

      it 'raises error for invalid format without OFX tags' do
        expect {
          OfxImportService.new('not an ofx file').parse
        }.to raise_error(StandardError, /Invalid OFX format: missing required OFX tags/)
      end

      it 'raises error for malformed OFX' do
        malformed_ofx = <<~OFX
          <OFX>
          <BANKMSGSRSV1>
          <STMTTRNRS>
          <STMTRS>
          <BANKTRANLIST>
          <STMTTRN>
          <TRNAMT>invalid_amount
          </STMTTRN>
          </BANKTRANLIST>
          </STMTRS>
          </STMTTRNRS>
          </BANKMSGSRSV1>
          </OFX>
        OFX

        expect {
          OfxImportService.new(malformed_ofx).parse
        }.to raise_error(StandardError, /Invalid OFX format:/)
      end
    end

    context 'edge cases' do
      let(:edge_case_ofx) do
        <<~OFX
          <OFX>
          <BANKMSGSRSV1>
          <STMTTRNRS>
          <STMTRS>
          <BANKTRANLIST>
          <STMTTRN>
          <DTPOSTED>20250605
          <TRNAMT>0.01
          <FITID>EDGE001
          </STMTTRN>
          <STMTTRN>
          <DTPOSTED>20250604
          <TRNAMT>-999999.99
          <FITID>EDGE002
          <MEMO>Large expense transaction
          </STMTTRN>
          <STMTTRN>
          <DTPOSTED>20250603
          <TRNAMT>1000000.00
          <FITID>EDGE003
          <NAME>Large income transaction
          </STMTTRN>
          </BANKTRANLIST>
          </STMTRS>
          </STMTTRNRS>
          </BANKMSGSRSV1>
          </OFX>
        OFX
      end

      it 'lida com valores extremos' do
        service = OfxImportService.new(edge_case_ofx)
        result = service.parse

        expect(result.length).to eq(3)
        
        # Valor muito pequeno
        expect(result[0][:amount]).to eq(0.01)
        expect(result[0][:transaction_type]).to eq('income')
        
        # Valor negativo grande
        expect(result[1][:amount]).to eq(-999999.99)
        expect(result[1][:transaction_type]).to eq('expense')
        
        # Valor positivo grande
        expect(result[2][:amount]).to eq(1000000.00)
        expect(result[2][:transaction_type]).to eq('income')
      end

      it 'handles transactions without description' do
        ofx_without_description = <<~OFX
          <OFX>
          <BANKMSGSRSV1>
          <STMTTRNRS>
          <STMTRS>
          <BANKTRANLIST>
          <STMTTRN>
          <DTPOSTED>20250605
          <TRNAMT>100.00
          <FITID>NO_DESC
          </STMTTRN>
          </BANKTRANLIST>
          </STMTRS>
          </STMTTRNRS>
          </BANKMSGSRSV1>
          </OFX>
        OFX

        service = OfxImportService.new(ofx_without_description)
        result = service.parse

        expect(result.length).to eq(1)
        expect(result[0][:description]).to be_nil
      end

      it 'handles dates in different formats' do
        ofx_with_dates = <<~OFX
          <OFX>
          <BANKMSGSRSV1>
          <STMTTRNRS>
          <STMTRS>
          <BANKTRANLIST>
          <STMTTRN>
          <DTPOSTED>20250605120000
          <TRNAMT>100.00
          <FITID>DATETIME1
          </STMTTRN>
          <STMTTRN>
          <DTPOSTED>20250604
          <TRNAMT>-50.00
          <FITID>DATE1
          </STMTTRN>
          </BANKTRANLIST>
          </STMTRS>
          </STMTTRNRS>
          </BANKMSGSRSV1>
          </OFX>
        OFX

        service = OfxImportService.new(ofx_with_dates)
        result = service.parse

        expect(result.length).to eq(2)
        expect(result[0][:event_date]).to eq(Date.new(2025, 6, 5))
        expect(result[1][:event_date]).to eq(Date.new(2025, 6, 4))
      end
    end

    context 'transaction type validation' do
      let(:type_test_ofx) do
        <<~OFX
          <OFX>
          <BANKMSGSRSV1>
          <STMTTRNRS>
          <STMTRS>
          <BANKTRANLIST>
          <STMTTRN>
          <DTPOSTED>20250605
          <TRNAMT>0
          <FITID>ZERO_AMOUNT
          </STMTTRN>
          <STMTTRN>
          <DTPOSTED>20250605
          <TRNAMT>100.50
          <FITID>POSITIVE
          </STMTTRN>
          <STMTTRN>
          <DTPOSTED>20250605
          <TRNAMT>-75.25
          <FITID>NEGATIVE
          </STMTTRN>
          </BANKTRANLIST>
          </STMTRS>
          </STMTTRNRS>
          </BANKMSGSRSV1>
          </OFX>
        OFX
      end

      it 'classifies transaction types correctly' do
        service = OfxImportService.new(type_test_ofx)
        result = service.parse

        expect(result.length).to eq(3)
        
        # Zero value should be treated as income
        expect(result[0][:transaction_type]).to eq('income')
        
        # Positive value is income
        expect(result[1][:transaction_type]).to eq('income')
        
        # Negative value is expense
        expect(result[2][:transaction_type]).to eq('expense')
      end
    end

    context 'multiple transactions' do
      it 'numbers lines correctly' do
        service = OfxImportService.new(File.read(Rails.root.join('spec/fixtures/files/sample.ofx')))
        result = service.parse

        expect(result[0][:line_number]).to eq(1)
        expect(result[1][:line_number]).to eq(2)
      end

      it 'maintains transaction order' do
        service = OfxImportService.new(File.read(Rails.root.join('spec/fixtures/files/sample.ofx')))
        result = service.parse

        # Verifies if date order is correct according to file
        expect(result[0][:event_date]).to eq(Date.new(2024, 1, 2))
        expect(result[1][:event_date]).to eq(Date.new(2024, 1, 1))
      end
    end
  end
end
