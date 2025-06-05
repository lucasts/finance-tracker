# lib/ofx_simple_parser.rb
# Parser simples para arquivos OFX (apenas extrai transações, saldo e dados básicos)
require 'date'

class OfxSimpleParser
  Transaction = Struct.new(:fit_id, :amount, :posted_at, :memo, :name, keyword_init: true)
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
      amount = extract_tag('TRNAMT', block).to_f
      posted_at = parse_date(extract_tag('DTPOSTED', block))
      memo = extract_tag('MEMO', block)
      name = extract_tag('NAME', block)
      transactions << Transaction.new(fit_id: fit_id, amount: amount, posted_at: posted_at, memo: memo, name: name)
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
