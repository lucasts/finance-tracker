# Service to handle credit card statement creation and management
# Ensures statements exist for transactions and handles bulk operations
class CreditStatementService
  class << self
    # Main method: finds or creates a credit statement for a transaction
    def find_or_create_for_transaction(transaction)
      return nil unless credit_card_transaction?(transaction)

      # Find the credit card account from the transaction entries
      credit_card_account = find_credit_card_account(transaction)
      return nil unless credit_card_account

      period = calculate_period_for_transaction(transaction)
      find_or_create_statement(credit_card_account, period)
    end

    # Finds or creates a credit statement for a specific account and period
    def find_or_create_statement(account, period)
      return nil unless account&.account_type&.code == "CREDIT_CARD"

      existing = CreditStatement.find_by(account: account, month: period)
      return existing if existing

      # Create new statement with defaults, skipping amount_due calculation initially
      statement = CreditStatement.new(account: account, month: period)
      initialize_statement(statement, account, period)
      statement.skip_amount_update = true
      statement.save!

      # Now enable updates and trigger a calculation to get the correct amount_due
      statement.skip_amount_update = false
      statement.save!
      statement
    end

    # Creates statements for multiple future periods (useful for installments)
    def ensure_statements_for_periods(account, periods)
      return [] unless account&.account_type&.code == "CREDIT_CARD"

      periods.map do |period|
        find_or_create_statement(account, period)
      end.compact
    end

    # Creates statements for the next N months for an account
    def create_future_statements(account, months_ahead = 12)
      return [] unless account&.account_type&.code == "CREDIT_CARD"

      current_date = Date.current
      periods = (0..months_ahead).map do |offset|
        (current_date + offset.months).strftime("%Y-%m")
      end

      ensure_statements_for_periods(account, periods)
    end

    # Updates the amount_due for a credit statement based on its transactions
    def update_statement_amount(statement)
      return false unless statement.is_a?(CreditStatement)

      total = statement.transactions.sum(:amount)
      if total != statement.amount_due
        statement.update_column(:amount_due, total)
        total  # Return the new amount
      else
        statement.amount_due  # Return current amount
      end
    end

    # Calculates which periods would be needed for an installment plan
    def calculate_periods_for_installment(start_date, installment_count, frequency = "monthly")
      periods = []
      current_date = start_date

      installment_count.times do
        periods << current_date.strftime("%Y-%m")
        current_date = next_period_date(current_date, frequency)
      end

      periods
    end

    private

    # Finds the credit card account from transaction entries
    def find_credit_card_account(transaction)
      transaction.entries.joins(:account).find do |entry|
        entry.entry_type == "credit" && entry.account.account_type.code == "CREDIT_CARD"
      end&.account
    end

    # Checks if transaction involves a credit card
    def credit_card_transaction?(transaction)
      find_credit_card_account(transaction).present?
    end

    # Calculates the statement period for a transaction based on closing day
    def calculate_period_for_transaction(transaction)
      date = transaction.event_date
      account = find_credit_card_account(transaction)

      if account&.closing_day.present?
        cutoff = Date.new(date.year, date.month, account.closing_day)
        ref_date = (date <= cutoff) ? date : date + 1.month
        ref_date.strftime("%Y-%m")
      else
        date.strftime("%Y-%m")
      end
    end

    # Initialize a new statement with sensible defaults
    def initialize_statement(statement, account, period)
      period_date = Date.parse("#{period}-01")

      statement.amount_due = 0.0
      statement.amount_paid = 0.0
      statement.status = :open

      # Set closing and due dates based on account configuration
      if account.closing_day.present?
        statement.closed_on = Date.new(period_date.year, period_date.month, account.closing_day)
      end

      if account.due_day.present?
        due_month = period_date + 1.month
        statement.due_on = Date.new(due_month.year, due_month.month, account.due_day)
      end
    rescue Date::Error
      # Handle invalid dates gracefully (e.g., Feb 30th)
      Rails.logger.warn "Invalid date configuration for account #{account.id}: closing_day=#{account.closing_day}, due_day=#{account.due_day}"
    end

    # Calculate next period date based on frequency
    def next_period_date(date, frequency)
      case frequency.to_s.downcase
      when "monthly"
        date + 1.month
      when "weekly"
        date + 1.week
      when "yearly", "annual"
        date + 1.year
      else
        date + 1.month # Default to monthly
      end
    end
  end
end
