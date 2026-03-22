# frozen_string_literal: true

# Concern responsible for managing cached balance in accounts
# Updates balance automatically when entries change
module BalanceCache
  extend ActiveSupport::Concern

  included do
    # Update balance after any entry change
    after_save :update_account_balance!
    after_destroy :update_account_balance!
  end

  private

  def update_account_balance!
    return unless account_id.present?

    # Update the balance for the affected account
    account.update_balance_cache!
  end
end
