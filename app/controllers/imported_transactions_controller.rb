class ImportedTransactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_imported_transaction

  def edit
    @matches = ImportMatchingService.new(@imported_transaction).suggest_matches
    # Individual reconciliation screen
  end

  def update
    # Save reconciliation decision
    action = params[:reconciliation_action]
    tx_params = params.require(:imported_transaction).permit(:description, :amount, :event_date, :payment_date, :category_id, :transaction_type)
    decision_data = tx_params.to_h
    rec_entry = @imported_transaction.reconciliation_entry || @imported_transaction.build_reconciliation_entry
    rec_entry.action = action
    rec_entry.user = current_user
    rec_entry.decided_at = Time.current
    rec_entry.decision_data = decision_data
    rec_entry.transaction_id = params[:matched_transaction_id] if action == "associate"
    rec_entry.audit_log = "#{action} por #{current_user.email} em #{Time.current}"
    rec_entry.save!

    created_transaction = nil
    # If creating new, create transaction in the system
    if action == "create_new"
      # Determine accounts based on transaction type
      amount = FinancialConstants.safe_to_decimal(tx_params[:amount]).abs
      transaction_type = tx_params[:transaction_type]
      account_id = @imported_transaction.import_session.account_id

      # Find or create appropriate external account
      external_account = Account.find_or_create_by(
        user: current_user,
        name: transaction_type == "income" ? "Receitas Externas" : "Gastos Externos",
        account_type: AccountType.find_by(code: transaction_type == "income" ? "INCOME_SOURCE" : "EXPENSE_DESTINATION")
      )

      # Set the correct account IDs
      if transaction_type == "income"
        from_account_id = external_account.id
        to_account_id = account_id
      else
        from_account_id = account_id
        to_account_id = external_account.id
      end

      # Build entries based on transaction type
      entries_attributes = case transaction_type
      when "income"
        [
          { account_id: to_account_id, entry_type: "debit", amount: amount },
          { account_id: from_account_id, entry_type: "credit", amount: amount }
        ]
      when "expense"
        [
          { account_id: from_account_id, entry_type: "debit", amount: amount },
          { account_id: to_account_id, entry_type: "credit", amount: amount }
        ]
      when "transfer"
        [
          { account_id: to_account_id, entry_type: "debit", amount: amount },
          { account_id: from_account_id, entry_type: "credit", amount: amount }
        ]
      else
        # Default to expense pattern
        [
          { account_id: from_account_id, entry_type: "debit", amount: amount },
          { account_id: to_account_id, entry_type: "credit", amount: amount }
        ]
      end

      t = CreateTransactionService.call(
        user: current_user,
        description: tx_params[:description],
        amount: amount,
        event_date: tx_params[:event_date],
        payment_date: tx_params[:payment_date],
        category_id: tx_params[:category_id],
        transaction_type: transaction_type,
        entries_attributes: entries_attributes
      )
      rec_entry.linked_transaction = t
      rec_entry.save!
      created_transaction = t
    end

    # Force update of imported_transaction status
    @imported_transaction.reload

    # Redirect to import screen, but with notice and link if a new transaction was created
    if created_transaction
      redirect_to import_session_path(@import_session), notice: "Decisão de conciliação salva. <a href='#{transaction_path(created_transaction)}' target='_blank'>Ver transação criada</a>".html_safe
    else
      redirect_to import_session_path(@import_session), notice: "Decisão de conciliação salva."
    end
  end

  private

  def set_imported_transaction
    @imported_transaction = ImportedTransaction.find(params[:id])
    @import_session = @imported_transaction.import_session
    # authorize! :manage, @import_session # Removido: só use se tiver CanCanCan/Pundit
    unless @import_session.user_id == current_user.id
      render plain: "Acesso negado", status: :forbidden
    end
  end
end
