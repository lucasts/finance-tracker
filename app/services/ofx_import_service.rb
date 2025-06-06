# Serviço para importar e parsear arquivos OFX
require_relative '../../lib/ofx_simple_parser'

class OfxImportService
  def initialize(file_content)
    @file_content = file_content
  end

  def parse
    # Validate content first
    if @file_content.nil? || @file_content.strip.empty?
      raise StandardError, "Empty OFX content"
    end
    
    # Basic OFX format validation
    unless @file_content.include?('OFX') || @file_content.include?('<STMTTRN>')
      raise StandardError, "Invalid OFX format: missing required OFX tags"
    end
    
    begin
      account = OfxSimpleParser.new(@file_content).parse
      if account.nil? || !account.respond_to?(:transactions) || account.transactions.nil? || account.transactions.empty?
        raise StandardError, "Invalid OFX format: missing transactions"
      end
    rescue => e
      raise StandardError, "Invalid OFX format: #{e.message}"
    end
    transactions = []
    account.transactions.each_with_index do |tx, idx|
      begin
        desc = tx.memo.presence || tx.name.presence
        description = desc.nil? || desc.to_s.strip.empty? ? nil : desc
        amount = tx.amount.nil? ? nil : BigDecimal(tx.amount.to_s)
        event_date = tx.posted_at ? tx.posted_at.to_date : nil
        payment_date = tx.posted_at ? tx.posted_at.to_date : nil
        # Transaction type: positive or zero = income, negative = expense
        transaction_type = amount && amount >= 0 ? 'income' : 'expense'
        transactions << {
          line_number: idx + 1,
          external_id: tx.fit_id,
          raw_data: tx.to_h.to_json,
          description: description,
          amount: amount,
          event_date: event_date,
          payment_date: payment_date,
          transaction_type: transaction_type,
          status: 'pending',
          parsed_data: tx.to_h
        }
      rescue => e
        raise StandardError, "Invalid OFX format: #{e.message}"
      end
    end
    transactions
  end
end
