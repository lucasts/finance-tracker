# Serviço para importar e parsear arquivos OFX
require_relative '../../lib/ofx_simple_parser'

class OfxImportService
  def initialize(file_content)
    @file_content = file_content
  end

  def parse
    account = OfxSimpleParser.new(@file_content).parse
    transactions = []
    account.transactions.each_with_index do |tx, idx|
      transactions << {
        line_number: idx + 1,
        external_id: tx.fit_id,
        raw_data: tx.to_h.to_json,
        description: tx.memo || tx.name,
        amount: tx.amount,
        event_date: tx.posted_at,
        payment_date: tx.posted_at,
        transaction_type: tx.amount.to_f > 0 ? 'income' : 'expense',
        status: 'pending',
        parsed_data: tx.to_h
      }
    end
    transactions
  end
end
