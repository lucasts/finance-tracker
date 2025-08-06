class ImportSessionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @import_sessions = current_user.import_sessions.order(created_at: :desc)
  end

  def new
    @import_session = ImportSession.new
  end

  def create
    @import_session = current_user.import_sessions.build(import_session_params)
    file = params[:import_session][:file]
    if file.present?
      @import_session.original_filename = file.original_filename
      content = file.read
      # Force UTF-8 encoding to avoid encoding errors
      content = content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      @import_session.raw_file = content
      @import_session.source_type = params[:import_session][:source_type]
      @import_session.account_id = params[:import_session][:account_id]
      @import_session.imported_at = nil
      if @import_session.save
        # Parsing and creation of ImportedTransaction
        transactions =
          if @import_session.source_type == 'ofx'
            OfxImportService.call(file_content: @import_session.raw_file)
          else
            CsvImportService.call(file_content: @import_session.raw_file)
          end
        transactions.each do |tx|
          @import_session.imported_transactions.create!(tx)
        end
        redirect_to import_session_path(@import_session), notice: 'Arquivo importado com sucesso. Prossiga para conciliação.'
      else
        render :new, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = 'Selecione um arquivo para importar.'
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @import_session = current_user.import_sessions.find(params[:id])
    @imported_transactions = @import_session.imported_transactions
  end

  def confirm
    @import_session = current_user.import_sessions.find(params[:id])
  end

  def finalize
    @import_session = current_user.import_sessions.find(params[:id])
    @import_session.update!(imported_at: Time.current)
    redirect_to import_sessions_path, notice: 'Importação finalizada com sucesso!'
  end

  def batch_process_pending
    @import_session = current_user.import_sessions.find(params[:id])
    
    # Find all pending transactions (without reconciliation entries)
    pending_transactions = @import_session.imported_transactions
                                          .left_joins(:reconciliation_entry)
                                          .where(reconciliation_entries: { id: nil })
    
    batch_action = params[:action_type] || 'create_new'
    
    if pending_transactions.empty?
      render json: { success: false, message: 'Não há transações pendentes para processar.' }
      return
    end

    processed_count = 0
    errors = []

    pending_transactions.each do |imported_tx|
      begin
        case batch_action
        when 'create_new'
          # Determine category (use a default category or nil)
          default_category = Category.where(user: current_user).first || Category.first
          
          # Create new transaction with proper field mapping
          # Determine accounts based on transaction type
          amount = imported_tx.amount.abs
          transaction_type = imported_tx.amount >= 0 ? 'income' : 'expense'
          
          # For income: external source -> user account
          # For expense: user account -> external destination
          if transaction_type == 'income'
            from_account_id = nil # External source (we'll create a default one)
            to_account_id = @import_session.account.id
          else
            from_account_id = @import_session.account.id
            to_account_id = nil # External destination (we'll create a default one)
          end

          # Find or create appropriate external account
          external_account = Account.find_or_create_by(
            user: current_user,
            name: transaction_type == 'income' ? 'Receitas Externas' : 'Gastos Externos',
            account_type: AccountType.find_by(code: transaction_type == 'income' ? 'INCOME_SOURCE' : 'EXPENSE_DESTINATION')
          )

          # Set the correct account IDs
          if transaction_type == 'income'
            from_account_id = external_account.id
          else
            to_account_id = external_account.id
          end

          transaction = CreateTransactionService.call(
            user: current_user,
            category: default_category,
            description: imported_tx.description,
            amount: amount,
            event_date: imported_tx.event_date || imported_tx.payment_date || Date.current,
            payment_date: imported_tx.payment_date || imported_tx.event_date || Date.current,
            transaction_type: transaction_type,
            entries_attributes: [
              { account_id: to_account_id, entry_type: 'debit', amount: amount },
              { account_id: from_account_id, entry_type: 'credit', amount: amount }
            ]
          )
          
          # Create reconciliation entry
          ReconciliationEntry.create!(
            imported_transaction: imported_tx,
            linked_transaction: transaction,
            action: 'create_new',
            user: current_user,
            decided_at: Time.current,
            decision_data: {
              description: imported_tx.description,
              amount: imported_tx.amount,
              event_date: transaction.event_date,
              payment_date: transaction.payment_date,
              category_id: default_category&.id,
              transaction_type: transaction.transaction_type
            },
            audit_log: "Processamento em lote: create_new por #{current_user.email} em #{Time.current}"
          )
          
          processed_count += 1
          
        when 'ignore'
          # Create reconciliation entry with ignore action
          ReconciliationEntry.create!(
            imported_transaction: imported_tx,
            action: 'ignore',
            user: current_user,
            decided_at: Time.current,
            decision_data: {},
            audit_log: "Processamento em lote: ignore por #{current_user.email} em #{Time.current}"
          )
          
          processed_count += 1
        end
      rescue => e
        errors << "Linha #{imported_tx.line_number}: #{e.message}"
      end
    end

    if errors.empty?
      render json: { 
        success: true, 
        message: "#{processed_count} transação(ões) processada(s) com sucesso.",
        processed_count: processed_count 
      }
    else
      render json: { 
        success: false, 
        message: "Alguns erros ocorreram durante o processamento.",
        errors: errors,
        processed_count: processed_count
      }
    end
  end

  private

  def import_session_params
    params.require(:import_session).permit(:source_type, :account_id)
  end
end
