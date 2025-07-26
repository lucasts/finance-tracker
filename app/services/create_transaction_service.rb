# app/services/create_transaction_service.rb
class CreateTransactionService
  def self.call(description:, amount:, event_date:, payment_date:, transaction_type:, entries_attributes:, user:, category: nil)
    transaction = user.transactions.new(
      description: description,
      amount: amount,
      event_date: event_date,
      payment_date: payment_date,
      transaction_type: transaction_type,
      entries_attributes: entries_attributes,
      category: category
    )

    ActiveRecord::Base.transaction do
      transaction.save!
      update_account_balances(transaction.entries)
    end

    transaction
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    # Retorna a transação com erros para que o controller possa lidar com eles
    transaction.errors.add(:base, e.message)
    transaction
  end

  private

  def self.update_account_balances(entries)
    entries.each do |entry|
      account = entry.account
      if entry.debit?
        account.lock!.update!(balance: account.balance + entry.amount)
      else
        account.lock!.update!(balance: account.balance - entry.amount)
      end
    end
  end
end
