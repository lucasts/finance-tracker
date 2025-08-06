# Service to import and parse OFX files
require_relative '../../lib/ofx_simple_parser'

class OfxImportService
  def self.call(file_content:)
    new(file_content).parse
  end

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
    
    # Analyze OFX transaction patterns
    analysis = analyze_ofx_patterns(account.transactions)
    
    transactions = []
    account.transactions.each_with_index do |tx, idx|
      begin
        desc = tx.memo.presence || tx.name.presence
        description = desc.nil? || desc.to_s.strip.empty? ? nil : desc
        amount = tx.amount.nil? ? nil : FinancialConstants.safe_to_decimal(tx.amount)
        event_date = FinancialConstants.safe_to_date(tx.posted_at)
        payment_date = FinancialConstants.safe_to_date(tx.posted_at)
        
        # Apply OFX normalization based on analysis
        normalized_data = normalize_ofx_transaction_data(tx, amount, analysis)
        
        transactions << {
          line_number: idx + 1,
          external_id: tx.fit_id,
          raw_data: tx.to_h.to_json,
          description: description,
          amount: normalized_data[:amount],
          event_date: event_date,
          payment_date: payment_date,
          transaction_type: normalized_data[:transaction_type],
          status: 'pending',
          parsed_data: tx.to_h
        }
      rescue => e
        raise StandardError, "Invalid OFX format: #{e.message}"
      end
    end
    transactions
  end

  private

  def analyze_ofx_patterns(transactions)
    analysis = {
      has_negative_values: false,
      has_trntype: false,
      normalization_strategy: :none
    }
    
    # Check if OFX contains TRNTYPE fields (transaction type indicator)
    has_trntype = transactions.any? { |tx| tx.respond_to?(:trntype) && tx.trntype }
    analysis[:has_trntype] = has_trntype
    
    # Analyze for negative values
    transactions.each do |tx|
      amount = tx.amount
      next if amount.nil?
      
      if amount < 0
        analysis[:has_negative_values] = true
        break
      end
    end
    
    # Determine strategy based on OFX standards and patterns
    if analysis[:has_trntype]
      # OFX standard: use TRNTYPE field when available
      analysis[:normalization_strategy] = :use_trntype
    elsif analysis[:has_negative_values]
      # Common OFX pattern: negative amounts = debits (expenses), positive = credits (income)
      analysis[:normalization_strategy] = :negative_to_positive_with_type
    else
      # Default to using amount sign with robust inference
      analysis[:normalization_strategy] = :negative_to_positive_with_type
    end
    
    analysis
  end

  def normalize_ofx_transaction_data(tx, amount, analysis)
    case analysis[:normalization_strategy]
    when :use_trntype
      # Use OFX TRNTYPE field (CREDIT, DEBIT, etc.)
      trntype = tx.respond_to?(:trntype) ? tx.trntype : nil
      transaction_type = map_ofx_trntype_to_type(trntype, amount)
      { amount: amount&.abs, transaction_type: transaction_type }
      
    when :negative_to_positive_with_type
      # OFX standard: negative = debit (expense), positive = credit (income)
      if amount && amount < 0
        { amount: amount.abs, transaction_type: 'expense' }
      elsif amount && amount > 0
        { amount: amount, transaction_type: 'income' }
      else
        { amount: amount, transaction_type: 'expense' }
      end
      
    else
      # Default normalization: use amount sign
      if amount && amount < 0
        { amount: amount.abs, transaction_type: 'expense' }
      elsif amount && amount > 0
        { amount: amount, transaction_type: 'income' }
      else
        { amount: amount, transaction_type: 'expense' }
      end
    end
  end

  def map_ofx_trntype_to_type(trntype, amount)
    return 'expense' if trntype.nil?
    
    case trntype.to_s.upcase
    when 'CREDIT', 'DEP', 'DEPOSIT'
      'income'
    when 'DEBIT', 'PAYMENT', 'CHECK', 'WITHDRAWAL'
      'expense'
    when 'TRANSFER', 'XFER'
      'transfer'
    else
      # Fallback to amount-based logic
      amount && amount >= 0 ? 'income' : 'expense'
    end
  end
end
