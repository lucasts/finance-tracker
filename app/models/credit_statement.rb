# app/models/credit_statement.rb
class CreditStatement
  attr_reader :month, :card, :transactions

  def initialize(card:, date:)
    @card = card
    @date = date
    @transactions = Transaction
      .confirmed
      .where(from_account: card)
      .in_payment_month(date.strftime('%Y-%m'))
  end

  def total
    transactions.sum(&:amount)
  end

  def due_date
    Date.new(@date.year, @date.month, card.due_day)
  end

  def closing_date
    Date.new(@date.year, @date.month, card.closing_day)
  end

  def label
    I18n.l(due_date, format: "%B de %Y")
  end

  def any?
    transactions.any?
  end
end