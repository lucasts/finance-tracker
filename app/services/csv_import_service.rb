# Serviço para importar e parsear arquivos CSV
require 'csv'

class CsvImportService
  # Espera-se header: data,valor,descricao,categoria,status,tipo,parcela
  def initialize(file_content)
    @file_content = file_content
  end

  def parse
    csv = CSV.parse(@file_content, headers: true, col_sep: ',')
    transactions = []
    csv.each_with_index do |row, idx|
      transactions << {
        line_number: idx + 1,
        external_id: nil,
        raw_data: row.to_h.to_json,
        description: row['descricao'],
        amount: row['valor'],
        event_date: row['data'],
        payment_date: row['data'],
        transaction_type: row['tipo'] || infer_type(row),
        status: row['status'] || 'pending',
        parsed_data: row.to_h
      }
    end
    transactions
  end

  private

  def infer_type(row)
    v = row['valor'].to_f
    v > 0 ? 'income' : 'expense'
  end
end
