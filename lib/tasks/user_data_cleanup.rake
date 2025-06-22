namespace :user do
  desc "Limpa dados financeiros de um usuário (apenas em desenvolvimento)"
  task :cleanup_financial_data, [:email] => :environment do |task, args|
    # Verificação de segurança - apenas em desenvolvimento
    unless Rails.env.development?
      puts "❌ Esta task só pode ser executada em ambiente de desenvolvimento!"
      puts "   Ambiente atual: #{Rails.env}"
      exit 1
    end

    # Validação do parâmetro email
    email = args[:email]
    if email.blank?
      puts "❌ É necessário informar o email do usuário"
      puts "   Uso: rake user:cleanup_financial_data[usuario@exemplo.com]"
      exit 1
    end

    # Buscar o usuário
    user = User.find_by(email: email)
    if user.nil?
      puts "❌ Usuário não encontrado: #{email}"
      exit 1
    end

    puts "🔄 Iniciando limpeza de dados financeiros para o usuário: #{user.email}"
    puts "   ID: #{user.id}"
    puts

    # Contadores para relatório
    deleted_counts = {}

    # Transação para garantir consistência
    ActiveRecord::Base.transaction do
      # 1. Limpar transações
      transactions_count = user.transactions.count
      if transactions_count > 0
        puts "🗑️  Removendo #{transactions_count} transações..."
        user.transactions.destroy_all
        deleted_counts[:transactions] = transactions_count
      end

      # 2. Limpar planos de parcelamento
      installment_plans_count = user.installment_plans.count
      if installment_plans_count > 0
        puts "🗑️  Removendo #{installment_plans_count} planos de parcelamento..."
        user.installment_plans.destroy_all
        deleted_counts[:installment_plans] = installment_plans_count
      end

      # 3. Limpar compromissos recorrentes
      recurring_commitments_count = user.recurring_commitments.count
      if recurring_commitments_count > 0
        puts "🗑️  Removendo #{recurring_commitments_count} compromissos recorrentes..."
        user.recurring_commitments.destroy_all
        deleted_counts[:recurring_commitments] = recurring_commitments_count
      end

      # 4. Limpar faturas de cartão de crédito
      credit_statements_count = 0
      user.accounts.joins(:account_type).where(account_types: { code: 'CREDIT_CARD' }).each do |account|
        statements_count = account.credit_statements.count
        if statements_count > 0
          puts "🗑️  Removendo #{statements_count} faturas do cartão #{account.name}..."
          account.credit_statements.destroy_all
          credit_statements_count += statements_count
        end
      end
      deleted_counts[:credit_statements] = credit_statements_count if credit_statements_count > 0

      # 5. Limpar sessões de importação
      import_sessions_count = user.accounts.joins(:import_sessions).count('import_sessions.id')
      if import_sessions_count > 0
        puts "🗑️  Removendo #{import_sessions_count} sessões de importação..."
        ImportSession.where(account: user.accounts).destroy_all
        deleted_counts[:import_sessions] = import_sessions_count
      end

      puts
      puts "✅ Limpeza concluída com sucesso!"
      puts
      puts "📊 Resumo da limpeza:"
      puts "   • Transações: #{deleted_counts[:transactions] || 0}"
      puts "   • Planos de parcelamento: #{deleted_counts[:installment_plans] || 0}"
      puts "   • Compromissos recorrentes: #{deleted_counts[:recurring_commitments] || 0}"
      puts "   • Faturas de cartão: #{deleted_counts[:credit_statements] || 0}"
      puts "   • Sessões de importação: #{deleted_counts[:import_sessions] || 0}"
      puts
      puts "🔧 Configurações mantidas:"
      puts "   • Contas (#{user.accounts.count})"
      puts "   • Categorias (#{user.categories.count})"
      puts "   • Tipos de conta disponíveis"
      puts "   • Configurações do usuário"
      puts
      puts "🎯 O usuário #{user.email} está pronto para recomeçar com dados limpos!"
    end

  rescue => e
    puts "❌ Erro durante a limpeza: #{e.message}"
    puts "   Todas as operações foram revertidas."
    exit 1
  end

  desc "Lista usuários disponíveis para limpeza"
  task :list => :environment do
    unless Rails.env.development?
      puts "❌ Esta task só pode ser executada em ambiente de desenvolvimento!"
      exit 1
    end

    puts "👥 Usuários disponíveis no sistema:"
    puts

    User.includes(:accounts, :categories, :transactions).each do |user|
      puts "📧 #{user.email} (ID: #{user.id})"
      puts "   • Contas: #{user.accounts.count}"
      puts "   • Categorias: #{user.categories.count}"
      puts "   • Transações: #{user.transactions.count}"
      puts "   • Parcelamentos: #{user.installment_plans.count}"
      puts "   • Compromissos recorrentes: #{user.recurring_commitments.count}"
      puts
    end

    if User.count == 0
      puts "Nenhum usuário encontrado no sistema."
    end
  end

  desc "Mostra informações detalhadas de um usuário"
  task :info, [:email] => :environment do |task, args|
    unless Rails.env.development?
      puts "❌ Esta task só pode ser executada em ambiente de desenvolvimento!"
      exit 1
    end

    email = args[:email]
    if email.blank?
      puts "❌ É necessário informar o email do usuário"
      puts "   Uso: rake user:info[usuario@exemplo.com]"
      exit 1
    end

    user = User.find_by(email: email)
    if user.nil?
      puts "❌ Usuário não encontrado: #{email}"
      exit 1
    end

    puts "👤 Informações detalhadas do usuário: #{user.email}"
    puts "   ID: #{user.id}"
    puts "   Criado em: #{user.created_at.strftime('%d/%m/%Y às %H:%M')}"
    puts

    puts "🏦 Contas (#{user.accounts.count}):"
    user.accounts.includes(:account_type).each do |account|
      puts "   • #{account.name} (#{account.account_type.name})"
    end
    puts

    puts "🏷️  Categorias (#{user.categories.count}):"
    user.categories.order(:name).each do |category|
      puts "   • #{category.name}"
    end
    puts

    puts "💰 Dados financeiros:"
    puts "   • Transações: #{user.transactions.count}"
    puts "   • Planos de parcelamento: #{user.installment_plans.count}"
    puts "   • Compromissos recorrentes: #{user.recurring_commitments.count}"
    
    credit_statements_count = CreditStatement.joins(:account).where(account: { user: user }).count
    puts "   • Faturas de cartão: #{credit_statements_count}"
    
    import_sessions_count = ImportSession.joins(:account).where(account: { user: user }).count
    puts "   • Sessões de importação: #{import_sessions_count}"
    puts
  end

  desc "Mostra ajuda sobre como usar as tasks de usuário"
  task :help => :environment do
    puts "🔧 Tasks de Gerenciamento de Usuário"
    puts "=================================="
    puts
    puts "📋 Tasks disponíveis:"
    puts
    puts "🔍 rake user:list"
    puts "   Lista todos os usuários do sistema com resumo de dados"
    puts
    puts "🔍 rake user:info[email]"
    puts "   Mostra informações detalhadas de um usuário específico"
    puts "   Exemplo: rake user:info[admin@example.com]"
    puts
    puts "🗑️  rake user:cleanup_financial_data[email]"
    puts "   Limpa TODOS os dados financeiros de um usuário, mantendo apenas:"
    puts "   • Contas configuradas"
    puts "   • Categorias"
    puts "   • Configurações do usuário"
    puts "   Remove:"
    puts "   • Transações"
    puts "   • Planos de parcelamento"
    puts "   • Compromissos recorrentes"
    puts "   • Faturas de cartão"
    puts "   • Sessões de importação"
    puts "   Exemplo: rake user:cleanup_financial_data[test@example.com]"
    puts
    puts "⚠️  IMPORTANTE:"
    puts "   • Essas tasks só funcionam em ambiente de DESENVOLVIMENTO"
    puts "   • A limpeza de dados é IRREVERSÍVEL"
    puts "   • Sempre verifique os dados do usuário antes de limpar"
    puts "   • Use 'user:info[email]' para verificar os dados antes da limpeza"
    puts
    puts "💡 Fluxo recomendado:"
    puts "   1. rake user:list                          # Ver usuários disponíveis"
    puts "   2. rake user:info[email]                   # Verificar dados do usuário"
    puts "   3. rake user:cleanup_financial_data[email] # Limpar se necessário"
    puts "   4. rake user:info[email]                   # Confirmar limpeza"
    puts
  end
end
