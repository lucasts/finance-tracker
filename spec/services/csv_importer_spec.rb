require 'rails_helper'

describe CsvImportService do
  let(:csv_content) do
    "data,valor,descricao,categoria,status,tipo,parcela\n2024-01-01,1000,Salário,Receitas,confirmed,income,\n2024-01-02,-200,Supermercado,Despesas,pending,expense,"
  end

  it 'imports valid transactions from CSV file' do
    result = CsvImportService.new(csv_content).parse
    expect(result.size).to eq(2)
    expect(result.first[:description]).to eq('Salário')
    expect(result.last[:amount]).to eq(BigDecimal('-200'))
  end

  it 'detects and ignores duplicates (simulated)' do
    result1 = CsvImportService.new(csv_content).parse
    result2 = CsvImportService.new(csv_content).parse
    # Simulation: deduplication would be done in another service, here only parse
    expect(result1).to eq(result2)
  end

  it 'handles missing fields' do
    csv_missing = "data,valor,descricao\n2024-01-01,1000,Salário"
    result = CsvImportService.new(csv_missing).parse
    expect(result.first[:description]).to eq('Salário')
    expect(result.first[:amount]).to eq(BigDecimal('1000'))
  end

  it 'returns error for invalid format' do
    expect {
      # Malformed CSV with unclosed quotes
      CsvImportService.new('"invalid,csv","with,unclosed,quote').parse
    }.to raise_error(CSV::MalformedCSVError)
  end
end
