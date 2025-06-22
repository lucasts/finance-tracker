# Service to handle credit card statement creation and management
# Ensures statements exist for transactions and handles bulk operations
class CreditStatementService
  class << self
    # Main method: finds or creates a credit statement for a transaction
    def find_or_create_for_transaction(transaction)
      return nil unless credit_card_transaction?(transaction)
      
      period = calculate_period_for_transaction(transaction)
      find_or_create_statement(transaction.from_account, period)
    end

    # Finds or creates a credit statement for a specific account and period
    def find_or_create_statement(account, period)
      return nil unless account&.account_type&.code == "CREDIT"
      
      CreditStatement.find_or_create_by(account: account, month: period) do |statement|
        initialize_statement(statement, account, period)
      end
    end

    # Creates statements for multiple future periods (useful for installments)
    def ensure_statements_for_periods(account, periods)
      return [] unless account&.account_type&.code == "CREDIT"
      
      periods.map do |period|
        find_or_create_statement(account, period)
      end.compact
    end

    # Creates statements for the next N months for an account
    def create_future_statements(account, months_ahead = 12)
      return [] unless account&.account_type&.code == "CREDIT"
      
      current_date = Date.current
      periods = (0..months_ahead).map do |offset|
        (current_date + offset.months).strftime("%Y-%m")
      end
      
      ensure_statements_for_periods(account, periods)
    end

    # Calculates which periods would be needed for an installment plan
    def calculate_periods_for_installment(start_date, installment_count, frequency = 'monthly')
      periods = []
      current_date = start_date
      
      installment_count.times do
        periods << current_date.strftime("%Y-%m")
        current_date = next_period_date(current_date, frequency)
      end
      
      periods
    end

    private

    # Checks if transaction is from a credit card
    def credit_card_transaction?(transaction)
      transaction&.from_account&.account_type&.code == "CREDIT"
    end

    # Calculates the statement period for a transaction based on closing day
    def calculate_period_for_transaction(transaction)
      date = transaction.event_date
      account = transaction.from_account
      
      if account.closing_day.present?
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
      when 'monthly'
        date + 1.month
      when 'weekly'
        date + 1.week
      when 'yearly', 'annual'
        date + 1.year
      else
        date + 1.month # Default to monthly
      end
    end
  end
end
