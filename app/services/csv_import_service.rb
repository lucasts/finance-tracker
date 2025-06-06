# Serviço para importar e parsear arquivos CSV
require 'csv'

class CsvImportService
  # Espera-se header: data,valor,descricao,categoria,status,tipo,parcela
  def initialize(file_content)
    @file_content = file_content
  end

  def parse
    # Fallback: single-line CSV without headers, only if not obviously malformed
    if @file_content.to_s.strip.empty?
      return []
    end
    lines = @file_content.to_s.lines
    if lines.size == 1 && lines.first !~ /^data,valor/i && lines.first.count('"') % 2 == 0
      return [{
        line_number: 1,
        external_id: nil,
        raw_data: @file_content.strip,
        description: nil,
        amount: nil,
        event_date: nil,
        payment_date: nil,
        transaction_type: 'pending',
        status: nil,
        parsed_data: {}
      }]
    end
    csv = CSV.parse(@file_content, headers: true, col_sep: ',')
    transactions = []
    csv.each_with_index do |row, idx|
      valor = row['valor']
      amount = parse_amount(valor)
      desc = row['descricao']
      description = desc.nil? || desc.to_s.strip.empty? ? nil : desc
      transactions << {
        line_number: idx + 1,
        external_id: nil,
        raw_data: row.to_h.to_json,
        description: description,
        amount: amount,
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

  def parse_amount(valor)
    return nil if valor.nil? || valor.to_s.strip.empty?
    BigDecimal(valor.to_s.strip)
  end

  def infer_type(row)
    v = row['valor'].to_f
    v > 0 ? 'income' : 'expense'
  end
end
