# Ambiente de Pré-produção - Zeno Finance Tracker

## 🎯 Objetivo

Este ambiente de pré-produção foi projetado para simular um ambiente de produção similar ao Heroku, permitindo testes completos antes do deploy real.

## 🏗️ Arquitetura

### Serviços Docker
- **PostgreSQL 15**: Banco de dados principal
- **Redis 7**: Cache e queue para background jobs
- **Rails App**: Aplicação principal (porta 3001)
- **Sidekiq**: Processamento de background jobs
- **MailCatcher**: Servidor de email para testes (porta 1080)

### Portas Expostas
- `3001`: Aplicação Rails
- `5433`: PostgreSQL
- `6380`: Redis
- `1080`: MailCatcher Web UI
- `1025`: MailCatcher SMTP

## 🚀 Como Usar

### Inicialização Completa
```bash
# Primeira vez ou reset completo
./run-pre-prod.sh
```

### Comandos Utilitários
```bash
# Ver ajuda
./preprod-utils.sh help

# Comandos mais usados
./preprod-utils.sh start     # Inicia ambiente
./preprod-utils.sh stop      # Para ambiente
./preprod-utils.sh logs      # Ver logs
./preprod-utils.sh console   # Rails console
./preprod-utils.sh jobs      # Executar jobs manualmente
./preprod-utils.sh reset     # Reset completo do banco
```

### Health Check
```bash
./health-check.sh
```

## 🔧 Configurações

### Variáveis de Ambiente
O ambiente usa `.env.preprod` que simula configurações Heroku-like:
- Database URL formato Heroku
- Redis URL
- Feature flags
- Configurações de performance

### Background Jobs
- **Sidekiq** configurado com Redis
- Jobs automáticos via `config/schedule.rb`
- Web UI disponível em `/sidekiq`

### Email Testing
- MailCatcher captura todos os emails
- Interface web em `http://localhost:1080`
- SMTP simulado na porta 1025

## 📊 Monitoramento

### URLs Importantes
- **App**: http://localhost:3001
- **Sidekiq**: http://localhost:3001/sidekiq
- **MailCatcher**: http://localhost:1080

### Dados de Teste
O ambiente carrega automaticamente dados realistas via `db/seeds/demo_realistic.rb`:
- Contas bancárias e cartões
- 12 meses de transações
- Parcelamentos ativos
- Compromissos recorrentes

## 🔄 Automação

### Jobs Configurados
1. **GenerateRecurringTransactionsJob**
   - Produção: Diário às 6:00
   - Preprod: A cada 30 minutos (para testes)

2. **GenerateInstallmentTransactionsJob**
   - Produção: Diário às 6:30
   - Preprod: A cada hora

### Comandos Manuais
```bash
# Executar jobs específicos
./preprod-utils.sh jobs

# Via Rails console
./preprod-utils.sh console
> GenerateRecurringTransactionsJob.perform_now
> GenerateInstallmentTransactionsJob.perform_now
```

## 🛠️ Troubleshooting

### Container não inicia
```bash
# Verificar logs
./preprod-utils.sh logs

# Rebuild completo
./preprod-utils.sh stop
./run-pre-prod.sh
```

### Banco de dados
```bash
# Conectar diretamente
./preprod-utils.sh db

# Reset completo
./preprod-utils.sh reset
```

### Performance
```bash
# Ver status detalhado
./preprod-utils.sh status

# Health check completo
./health-check.sh
```

## 🎯 Diferenças do Heroku Real

### Similitudes
✅ PostgreSQL como database  
✅ Redis para background jobs  
✅ Sidekiq para processamento  
✅ Variáveis de ambiente  
✅ Procfile para definir processos  
✅ Asset compilation automática  
✅ Logs estruturados  

### Diferenças (limitações locais)
❌ SSL/TLS (desabilitado para desenvolvimento)  
❌ CDN para assets  
❌ Dyno scaling automático  
❌ Add-ons externos (SendGrid, etc)  
❌ Heroku Scheduler (simulado com whenever)  

## 🔒 Segurança

Para desenvolvimento local:
- SSL desabilitado
- Senhas padrão nos bancos
- Secret keys fixas
- CORS permissivo

**⚠️ NÃO usar em produção real!**

## 📝 Logs

Todos os containers logam para STDOUT/STDERR, permitindo:
```bash
# Logs específicos
docker-compose -f docker-compose.preprod.yml logs app
docker-compose -f docker-compose.preprod.yml logs sidekiq

# Logs em tempo real
./preprod-utils.sh logs
```

## 🎉 Pronto para Produção

Este ambiente prepara a aplicação para deploy em:
- Heroku
- Railway
- Render
- DigitalOcean App Platform
- Qualquer PaaS compatível com Rails

Todos os aspectos críticos são testados:
- Conexões de banco
- Background jobs
- Asset pipeline
- Email delivery
- Variáveis de ambiente
- Performance básica
