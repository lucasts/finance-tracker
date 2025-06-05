class ImportedTransactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_imported_transaction

  def edit
    @matches = ImportMatchingService.new(@imported_transaction).suggest_matches
    # Tela de conciliação individual
  end

  def update
    # Salva decisão de conciliação
    action = params[:reconciliation_action]
    tx_params = params.require(:imported_transaction).permit(:description, :amount, :event_date, :payment_date, :category_id, :transaction_type)
    decision_data = tx_params.to_h
    rec_entry = @imported_transaction.reconciliation_entry || @imported_transaction.build_reconciliation_entry
    rec_entry.action = action
    rec_entry.user = current_user
    rec_entry.decided_at = Time.current
    rec_entry.decision_data = decision_data
    rec_entry.transaction_id = params[:matched_transaction_id] if action == 'associate'
    rec_entry.audit_log = "#{action} por #{current_user.email} em #{Time.current}"
    rec_entry.save!

    created_transaction = nil
    # Se criar novo, cria transação no sistema
    if action == 'create_new'
      t = Transaction.create!(user: current_user,
        description: tx_params[:description],
        amount: tx_params[:amount],
        event_date: tx_params[:event_date],
        payment_date: tx_params[:payment_date],
        from_account_id: @imported_transaction.import_session.account_id,
        to_account_id: nil,
        category_id: tx_params[:category_id],
        transaction_type: tx_params[:transaction_type],
        status: 'confirmed')
      rec_entry.linked_transaction = t
      rec_entry.save!
      created_transaction = t
    end

    # Força atualização do status da imported_transaction
    @imported_transaction.reload

    # Redireciona para a tela de importação, mas com aviso e link se criou nova transação
    if created_transaction
      redirect_to import_session_path(@import_session), notice: "Decisão de conciliação salva. <a href='#{transaction_path(created_transaction)}' target='_blank'>Ver transação criada</a>".html_safe
    else
      redirect_to import_session_path(@import_session), notice: 'Decisão de conciliação salva.'
    end
  end

  private

  def set_imported_transaction
    @imported_transaction = ImportedTransaction.find(params[:id])
    @import_session = @imported_transaction.import_session
    # authorize! :manage, @import_session # Removido: só use se tiver CanCanCan/Pundit
    unless @import_session.user_id == current_user.id
      render plain: 'Acesso negado', status: :forbidden
    end
  end
end
