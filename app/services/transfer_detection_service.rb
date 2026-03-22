class TransferDetectionService
  # Detects potential transfers between accounts for the same user
  # Heuristics:
  # - Same amount (within 0.01 tolerance)
  # - Date within 2 days
  # - Different accounts belonging to same user
  # - Opposite signs preferred but not required

  AMOUNT_TOLERANCE = BigDecimal("0.01")
  DATE_TOLERANCE_DAYS = 2

  def self.call(user:)
    new(user).process
  end

  def initialize(user)
    @user = user
  end

  def process
    # Get all imported transactions for this user across all their accounts
    transactions = ImportedTransaction.joins(import_session: :account)
                                    .where(accounts: { user_id: @user.id })
                                    .where(transfer_candidate: false) # Don't reprocess
                                    .includes(import_session: :account)
                                    .order(:event_date)

    # Group by potential transfer windows (amount + date proximity)
    transactions.each do |tx1|
      next unless tx1.amount && tx1.event_date

      # Find potential transfer partners
      candidates = find_transfer_candidates(tx1, transactions)

      candidates.each do |tx2|
        next if tx1.id == tx2.id
        next if tx1.import_session.account_id == tx2.import_session.account_id # Same account

        # Mark both as transfer candidates
        tx1.update_columns(
          transfer_candidate: true,
          potential_transfer_with_id: tx2.id
        )
        tx2.update_columns(
          transfer_candidate: true,
          potential_transfer_with_id: tx1.id
        )

        break # Each transaction can only be paired with one other
      end
    end
  end

  private

  def find_transfer_candidates(base_tx, all_transactions)
    all_transactions.select do |candidate|
      next false unless candidate.amount && candidate.event_date
      next false if candidate.id == base_tx.id
      next false if candidate.transfer_candidate # Already processed

      # Different account but same user (already filtered in main query)
      next false if candidate.import_session.account_id == base_tx.import_session.account_id

      # Amount match (within tolerance, prefer opposite signs)
      amount_matches = amount_match?(base_tx.amount, candidate.amount)
      next false unless amount_matches

      # Date proximity
      date_diff = (base_tx.event_date - candidate.event_date).abs
      next false if date_diff > DATE_TOLERANCE_DAYS

      true
    end
  end

  def amount_match?(amount1, amount2)
    # Prefer opposite signs (transfer out vs transfer in)
    abs_amount1 = amount1.abs
    abs_amount2 = amount2.abs

    # Check if amounts are within tolerance
    (abs_amount1 - abs_amount2).abs <= AMOUNT_TOLERANCE
  end
end
