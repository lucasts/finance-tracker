# Use this file to easily define all of your cron jobs.
# 
# Configuração de jobs automáticos para o sistema financeiro
#

# Configura o ambiente baseado no RAILS_ENV
set :environment, ENV['RAILS_ENV'] || 'development'

# Configurações específicas por ambiente
case @environment
when 'preprod'
  # Em pré-produção, executa jobs mais frequentemente para testes
  
  # Gera transações recorrentes a cada 30 minutos (para testes)
  every 30.minutes do
    runner "GenerateRecurringTransactionsJob.perform_later"
  end

  # Gera parcelas de parcelamentos a cada hora
  every 1.hour do
    runner "GenerateInstallmentTransactionsJob.perform_later"
  end

  # Job de limpeza diário às 3:00
  every 1.day, at: '3:00 am' do
    runner "puts 'Executando limpeza de dados de teste...'"
  end

when 'production'
  # Em produção, executa nos horários padrão
  
  # Gera transações recorrentes todos os dias às 6:00
  every 1.day, at: '6:00 am' do
    runner "GenerateRecurringTransactionsJob.perform_later"
  end

  # Gera parcelas de parcelamentos todos os dias às 6:30
  every 1.day, at: '6:30 am' do
    runner "GenerateInstallmentTransactionsJob.perform_later"
  end

  # Job semanal para limpeza e manutenção (domingos às 2:00)
  every 1.week, at: '2:00 am' do
    runner "MaintenanceJob.perform_later" if defined?(MaintenanceJob)
  end

  # Job mensal para relatórios automáticos (primeiro dia do mês às 8:00)
  every '0 8 1 * *' do
    runner "MonthlyReportJob.perform_later" if defined?(MonthlyReportJob)
  end

else
  # Desenvolvimento - jobs manuais ou mais raros
  
  # Gera transações recorrentes a cada 2 horas
  every 2.hours do
    runner "GenerateRecurringTransactionsJob.perform_later"
  end

  # Gera parcelas de parcelamentos a cada 3 horas
  every 3.hours do
    runner "GenerateInstallmentTransactionsJob.perform_later"
  end

  # Job de manutenção mensal (último dia do mês às 23:55)
  every '55 23 last_day_of_month' do
    runner "MaintenanceJob.perform_later" if defined?(MaintenanceJob)
  end

  # Job de relatório manual (executar conforme necessário)
  # every :day, at: '10:00 pm' do
  #   runner "MonthlyReportJob.perform_later" if defined?(MonthlyReportJob)
  # end
end

# Em produção, você pode usar:
# set :environment, "production"
# set :output, "/path/to/my/cron_log.log"
