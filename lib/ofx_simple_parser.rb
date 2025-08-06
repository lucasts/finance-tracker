# lib/ofx_simple_parser.rb
# Parser simples para arquivos OFX (apenas extrai transações, saldo e dados básicos)
require 'date'

class OfxSimpleParser
  Transaction = Struct.new(:fit_id, :amount, :posted_at, :memo, :name, :trntype, keyword_init: true)
  Account = Struct.new(:bank_id, :account_id, :balance, :transactions, keyword_init: true)

  def initialize(ofx_content)
    @ofx_content = ofx_content
  end

  def parse
    # Extrai blocos principais
    bank_id = extract_tag('BANKID')
    account_id = extract_tag('ACCTID')
    balance = extract_tag('BALAMT').to_f
    transactions = []
    @ofx_content.scan(/<STMTTRN>(.*?)<\/STMTTRN>/m).each do |block|
      block = block.first
      fit_id = extract_tag('FITID', block)
      amount_str = extract_tag('TRNAMT', block)
      begin
        # Use consistent money parsing (simplified approach for lib context)
        amount = BigDecimal(amount_str)
      rescue ArgumentError, TypeError
        raise StandardError, "Invalid amount in OFX: '#{amount_str}'"
      end
      posted_at = parse_date(extract_tag('DTPOSTED', block))
      memo = extract_tag('MEMO', block)
      name = extract_tag('NAME', block)
      trntype = extract_tag('TRNTYPE', block)
      
      # Create transaction with consistent data
      transaction = Transaction.new(
        fit_id: fit_id, 
        amount: amount,
        posted_at: posted_at, 
        memo: memo, 
        name: name, 
        trntype: trntype
      )
      transactions << transaction
    end
    Account.new(bank_id: bank_id, account_id: account_id, balance: balance, transactions: transactions)
  end

  private

  def extract_tag(tag, text = @ofx_content)
    text[/<#{tag}>([^<\r\n]*)/, 1] || ""
  end

  def parse_date(str)
    return nil unless str
    str = str[0,8] if str.length >= 8
    Date.strptime(str, '%Y%m%d') rescue nil
  end
end
