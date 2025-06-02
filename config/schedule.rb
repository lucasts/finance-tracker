# Use this file to easily define all of your cron jobs.
# 
# Configuração de jobs automáticos para o sistema financeiro
#

# Configura o ambiente
set :environment, "development"

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

# Em produção, você pode usar:
# set :environment, "production"
# set :output, "/path/to/my/cron_log.log"
