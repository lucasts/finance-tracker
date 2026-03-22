namespace :db do
  namespace :seed do
    desc "Load demo data (realistic sample transactions, accounts, etc.)"
    task demo: :environment do
      puts "🎭 Carregando dados de demonstração..."
      puts ""

      # Verificar se já existem dados
      if User.exists? && Transaction.exists?
        print "⚠️  Já existem dados no banco. Deseja continuar? (isso pode duplicar dados) [y/N]: "
        begin
          response = STDIN.gets.chomp.downcase
        rescue
          response = "n" # Default para ambientes não interativos
        end
        unless [ "y", "yes", "s", "sim" ].include?(response)
          puts "❌ Operação cancelada."
          exit
        end
      end

      # Carregar dados de demonstração
      load Rails.root.join("db", "seeds", "demo_realistic.rb")

      puts ""
      puts "✅ Dados de demonstração carregados com sucesso!"
      puts ""
      puts "📊 Resumo:"
      puts "   Usuários: #{User.count}"
      puts "   Contas: #{Account.count}"
      puts "   Categorias: #{Category.count}"
      puts "   Transações: #{Transaction.count}"
      puts "   Planos de Parcelamento: #{InstallmentPlan.count}"
      puts "   Compromissos Recorrentes: #{RecurringCommitment.count}"
      puts "   Faturas de Cartão: #{CreditStatement.count}"
      puts ""
      puts "🚀 Acesse http://localhost:3000 para ver os dados em ação!"
    end

    desc "Reset database and load only essential data (no demo data)"
    task reset: :environment do
      puts "🔄 Resetando banco de dados..."

      Rake::Task["db:drop"].invoke
      Rake::Task["db:create"].invoke
      Rake::Task["db:migrate"].invoke
      Rake::Task["db:seed"].invoke  # Só vai carregar dados essenciais

      puts "✅ Banco resetado com dados essenciais!"
      puts "💡 Para adicionar dados de demonstração: rails db:seed:demo"
    end

    desc "Reset database and load demo data"
    task demo_full: :environment do
      puts "🔄 Resetando banco e carregando dados de demonstração..."

      Rake::Task["db:drop"].invoke
      Rake::Task["db:create"].invoke
      Rake::Task["db:migrate"].invoke
      Rake::Task["db:seed"].invoke
      Rake::Task["db:seed:demo"].invoke

      puts "✅ Banco resetado com dados de demonstração completos!"
    end
  end
end
