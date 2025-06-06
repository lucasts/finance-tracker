# 💰 Zeno Finance Tracker

Sistema completo de gestão financeira familiar com separação entre competência de cartão de crédito e fluxo de caixa real, projeções futuras e automação de transações recorrentes.

## 🎯 Funcionalidades Principais

### ✨ Gestão Avançada de Transações
- **Separação Temporal**: Distinção clara entre data do evento e data de pagamento
- **Cartões de Crédito**: Controle completo de faturas com fechamento e vencimento
- **Parcelamentos Inteligentes**: Planos de parcelamento com geração automática
- **Transações Recorrentes**: Automação completa de receitas e despesas fixas

### 📊 Análises e Relatórios
- **Fluxo de Caixa Real**: Visão precisa do dinheiro disponível
- **Competência vs Caixa**: Relatórios separados para análises distintas
- **Projeções Futuras**: Previsões baseadas em compromissos recorrentes
- **Dashboards Interativos**: Múltiplas visualizações dos dados financeiros

### 🤖 Automação Inteligente
- **Background Jobs**: Processamento automático via Sidekiq
- **Jobs Recorrentes**: Geração automática de transações mensais/anuais
- **Processamento de Parcelas**: Criação automática de parcelas futuras
- **Atualização de Faturas**: Cálculo automático de valores de cartão

## 🚀 Ambientes

### 🔨 Desenvolvimento Local
```bash
# Setup inicial
./bin/setup

# Servidor de desenvolvimento
./bin/dev

# Testes
bundle exec rspec
```

### 📊 Dados de Demonstração
O setup padrão carrega apenas dados essenciais. Para demonstrações ou desenvolvimento com dados ricos:

```bash
# Carregar dados de demonstração (recomendado para demos)
rails db:seed:demo

# Reset completo com dados de demonstração
rails db:seed:demo_full
```

**📋 [Ver documentação completa dos dados](DEMO_DATA_MANAGEMENT.md)**

### 🎯 Pré-produção (Heroku-like)
Ambiente completo que simula produção:

```bash
# Iniciar ambiente completo
./run-pre-prod.sh

# Utilitários
./preprod-utils.sh help
./preprod-utils.sh start
./preprod-utils.sh console
./preprod-utils.sh jobs

# Health check
./health-check.sh
```

**Serviços incluídos:**
- PostgreSQL (porta 5433)
- Redis (porta 6380)
- Sidekiq + Web UI
- MailCatcher (porta 1080)
- App Rails (porta 3001)

[📖 **Documentação completa do ambiente**](PREPROD.md)

## 🤖 Automação

### Background Jobs
```ruby
# Transações recorrentes (salários, aluguel, etc)
GenerateRecurringTransactionsJob.perform_later

# Parcelas de parcelamentos
GenerateInstallmentTransactionsJob.perform_later
```

## 🚀 Deploy Pronto

### Heroku
```bash
# Criar app
heroku create meu-finance-tracker

# Configurar addons
heroku addons:create heroku-postgresql
heroku addons:create heroku-redis

# Deploy
git push heroku main
heroku run rails db:migrate
```

---

**✅ MVP Completo | ✅ Ambiente Pré-produção | ✅ Automação Operacional**