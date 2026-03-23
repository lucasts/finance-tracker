# frozen_string_literal: true

class CreateTransactionService
  def self.call(description:, amount:, event_date:, payment_date:, transaction_type:, entries_attributes:, user:, category: nil, **other_params)
    transaction = user.transactions.new(
      description: description,
      amount: amount,
      event_date: event_date,
      payment_date: payment_date,
      transaction_type: transaction_type,
      entries_attributes: entries_attributes,
      category: category,
      **other_params
    )

    ActiveRecord::Base.transaction do
      transaction.save!
    end

    transaction
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    # Retorna a transação com erros para que o controller possa lidar com eles
    transaction.errors.add(:base, e.message)
    transaction
  end
end
