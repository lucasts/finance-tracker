puts "=== SEEDING DEMO DATA FOR DEVELOPMENT ==="
puts "Seeding realistic family financial data..."

require 'date'

# Create demo user for development
puts "Creating demo user..."
default_user = User.find_or_create_by!(email: "admin@example.com") do |user|
  user.password = "password"
  user.password_confirmation = "password"
end

puts "Demo user: #{default_user.email}"

# Limpa dados existentes de demo
puts "Cleaning existing demo data..."
Transaction.where(user: default_user).destroy_all
InstallmentPlan.where(user: default_user).destroy_all
RecurringCommitment.where(user: default_user).destroy_all
CreditStatement.joins(:account).where(accounts: { user: default_user }).destroy_all
Account.where(user: default_user).destroy_all
# Categorias são criadas automaticamente via DefaultCategoriesService no callback after_create do User

# === CONTAS E CARTÕES ===
puts "Criando contas da família..."

accounts = {
  # Contas correntes
  itau_pai:      Account.create!(name: "Itaú - João", account_type: AccountType.find_by(code: "BANK"), user: default_user),
  bradesco_mae:  Account.create!(name: "Bradesco - Maria", account_type: AccountType.find_by(code: "BANK"), user: default_user),
  
  # Cartões de crédito
  nubank_pai:    Account.create!(name: "Nubank - João", account_type: AccountType.find_by(code: "CREDIT"), closing_day: 15, due_day: 5, user: default_user),
  inter_mae:     Account.create!(name: "Inter - Maria", account_type: AccountType.find_by(code: "CREDIT"), closing_day: 20, due_day: 10, user: default_user),
  santander:     Account.create!(name: "Santander - Família", account_type: AccountType.find_by(code: "CREDIT"), closing_day: 25, due_day: 15, user: default_user),
  
  # Poupança
  poupanca:      Account.create!(name: "Poupança Emergência", account_type: AccountType.find_by(code: "SAVINGS"), user: default_user),
  
  # Contas de despesas (estabelecimentos)
  mercado:       Account.create!(name: "Supermercados", account_type: AccountType.find_by(code: "EXPENSE"), user: default_user),
  farmacia:      Account.create!(name: "Farmácias", account_type: AccountType.find_by(code: "EXPENSE"), user: default_user),
  escola:        Account.create!(name: "Escola dos Filhos", account_type: AccountType.find_by(code: "EXPENSE"), user: default_user),
  posto:         Account.create!(name: "Postos de Gasolina", account_type: AccountType.find_by(code: "EXPENSE"), user: default_user),
  lazer:         Account.create!(name: "Lazer e Entretenimento", account_type: AccountType.find_by(code: "EXPENSE"), user: default_user),
  saude:         Account.create!(name: "Saúde e Medicina", account_type: AccountType.find_by(code: "EXPENSE"), user: default_user),
  casa:          Account.create!(name: "Casa e Utilidades", account_type: AccountType.find_by(code: "EXPENSE"), user: default_user),
  vestuario:     Account.create!(name: "Roupas e Calçados", account_type: AccountType.find_by(code: "EXPENSE"), user: default_user),
  transporte:    Account.create!(name: "Transporte", account_type: AccountType.find_by(code: "EXPENSE"), user: default_user),
  banco:         Account.create!(name: "Bancos e Financeiras", account_type: AccountType.find_by(code: "EXPENSE"), user: default_user),
  
  # Contas de receita
  empresa_pai:   Account.create!(name: "Empresa João", account_type: AccountType.find_by(code: "REVENUE"), user: default_user),
  empresa_mae:   Account.create!(name: "Empresa Maria", account_type: AccountType.find_by(code: "REVENUE"), user: default_user),
  freelance:     Account.create!(name: "Trabalhos Extra", account_type: AccountType.find_by(code: "REVENUE"), user: default_user)
}

# === MAPEAMENTO DAS CATEGORIAS PADRÃO ===
puts "Carregando categorias padrão do usuário..."
categories = Category.where(user: default_user).index_by(&:name)

# === FATURAS DE CARTÃO DE CRÉDITO (CRIAR ANTES DAS TRANSAÇÕES) ===
puts "Criando faturas de cartão..."

statements = {}

# Gerar faturas para os últimos 12 meses
(-11..0).each do |offset|
  mes_fatura = Date.today.beginning_of_month + offset.months
  
  # Fatura Nubank - João
  statements[:nubank_pai] ||= {}
  statements[:nubank_pai][offset] = CreditStatement.create!(
    account: accounts[:nubank_pai],
    month: mes_fatura.strftime('%Y-%m'),
    amount_due: 0,
    amount_paid: 0,
    status: offset < -1 ? :paid : (offset == -1 ? :overdue : :open),
    closed_on: Date.new(mes_fatura.year, mes_fatura.month, 15),
    due_on: (mes_fatura + 1.month).change(day: 5),
    paid_on: offset < -1 ? (mes_fatura + 1.month).change(day: 6) : nil
  )
  
  # Fatura Inter - Maria
  statements[:inter_mae] ||= {}
  statements[:inter_mae][offset] = CreditStatement.create!(
    account: accounts[:inter_mae],
    month: mes_fatura.strftime('%Y-%m'),
    amount_due: 0,
    amount_paid: 0,
    status: offset < -1 ? :paid : (offset == -1 ? :overdue : :open),
    closed_on: Date.new(mes_fatura.year, mes_fatura.month, 20),
    due_on: (mes_fatura + 1.month).change(day: 10),
    paid_on: offset < -1 ? (mes_fatura + 1.month).change(day: 11) : nil
  )
  
  # Fatura Santander - Família
  statements[:santander] ||= {}
  statements[:santander][offset] = CreditStatement.create!(
    account: accounts[:santander],
    month: mes_fatura.strftime('%Y-%m'),
    amount_due: 0,
    amount_paid: 0,
    status: offset < -1 ? :paid : (offset == -1 ? :overdue : :open),
    closed_on: Date.new(mes_fatura.year, mes_fatura.month, 25),
    due_on: (mes_fatura + 1.month).change(day: 15),
    paid_on: offset < -1 ? (mes_fatura + 1.month).change(day: 16) : nil
  )
end

# Função helper para associar transação de cartão à fatura correta
def associar_com_fatura(transaction, statements, accounts)
  return unless transaction.from_account&.account_type&.code == "CREDIT"
  
  # Determina qual mês da fatura baseado na data de fechamento
  closing_day = transaction.from_account.closing_day
  event_date = transaction.event_date
  
  # Se comprou antes do fechamento, vai para fatura do mesmo mês
  # Se comprou depois do fechamento, vai para fatura do mês seguinte
  cutoff = Date.new(event_date.year, event_date.month, closing_day)
  fatura_mes = (event_date <= cutoff) ? event_date : event_date + 1.month
  
  # Encontra a fatura correspondente
  account_key = case transaction.from_account
  when accounts[:nubank_pai] then :nubank_pai
  when accounts[:inter_mae] then :inter_mae
  when accounts[:santander] then :santander
  end
  
  if account_key && statements[account_key]
    offset = ((fatura_mes.year - Date.today.year) * 12) + (fatura_mes.month - Date.today.month)
    fatura = statements[account_key][offset]
    transaction.update!(credit_statement: fatura) if fatura
  end
end

# === GERAÇÃO DE TRANSAÇÕES REALISTAS ===
puts "Gerando transações para 12 meses..."

# Data de início (12 meses atrás)
data_inicio = Date.today - 11.months
meses_gerados = []

(0..11).each do |i|
  mes_atual = data_inicio + i.months
  meses_gerados << mes_atual.strftime('%Y-%m')
  puts "  Gerando mês #{mes_atual.strftime('%B/%Y')}..."
  
  # === RECEITAS MENSAIS (PAI E MÃE) ===
  
  # Salário do pai - R$ 4.000 (dia 5)
  Transaction.create!(
    description: "Salário - João Silva",
    amount: 4000.00,
    transaction_type: "income",
    event_date: Date.new(mes_atual.year, mes_atual.month, 5),
    payment_date: Date.new(mes_atual.year, mes_atual.month, 5),
    from_account: accounts[:empresa_pai],
    to_account: accounts[:itau_pai],
    category: categories["Salário"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
  
  # Salário da mãe - R$ 8.500 (dia 10)
  Transaction.create!(
    description: "Salário - Maria Silva",
    amount: 8500.00,
    transaction_type: "income",
    event_date: Date.new(mes_atual.year, mes_atual.month, 10),
    payment_date: Date.new(mes_atual.year, mes_atual.month, 10),
    from_account: accounts[:empresa_mae],
    to_account: accounts[:bradesco_mae],
    category: categories["Salário"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
  
  # Freelance ocasional (30% de chance por mês)
  if rand < 0.3
    valor_freelance = rand(800..2500)
    Transaction.create!(
      description: "Trabalho freelance - Consultoria",
      amount: valor_freelance,
      transaction_type: "income",
      event_date: Date.new(mes_atual.year, mes_atual.month, rand(15..25)),
      payment_date: Date.new(mes_atual.year, mes_atual.month, rand(15..25)),
      from_account: accounts[:freelance],
      to_account: [accounts[:itau_pai], accounts[:bradesco_mae]].sample,
      category: categories["Outras Receitas"],
      recurrence_type: "single",
      status: "confirmed",
      user: default_user
    )
  end
  
  # === DESPESAS FIXAS MENSAIS ===
  
  # Escola dos 3 filhos - R$ 2.800 (dia 8)
  Transaction.create!(
    description: "Mensalidade escolar - 3 filhos",
    amount: 2800.00,
    transaction_type: "expense",
    event_date: Date.new(mes_atual.year, mes_atual.month, 8),
    payment_date: Date.new(mes_atual.year, mes_atual.month, 8),
    from_account: accounts[:bradesco_mae],
    to_account: accounts[:escola],
    category: categories["Educação"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
  
  # Plano de saúde família - R$ 1.450 (dia 12)
  Transaction.create!(
    description: "Plano de saúde familiar - Unimed",
    amount: 1450.00,
    transaction_type: "expense",
    event_date: Date.new(mes_atual.year, mes_atual.month, 12),
    payment_date: Date.new(mes_atual.year, mes_atual.month, 12),
    from_account: accounts[:itau_pai],
    to_account: accounts[:saude],
    category: categories["Saúde"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
  
  # Aluguel/Financiamento casa - R$ 2.200 (dia 10)
  Transaction.create!(
    description: "Financiamento habitacional - Caixa",
    amount: 2200.00,
    transaction_type: "expense",
    event_date: Date.new(mes_atual.year, mes_atual.month, 10),
    payment_date: Date.new(mes_atual.year, mes_atual.month, 10),
    from_account: accounts[:bradesco_mae],
    to_account: accounts[:banco],
    category: categories["Habitação"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
  
  # Internet e TV - R$ 180 (dia 15)
  Transaction.create!(
    description: "Internet + TV - Claro",
    amount: 180.00,
    transaction_type: "expense",
    event_date: Date.new(mes_atual.year, mes_atual.month, 15),
    payment_date: Date.new(mes_atual.year, mes_atual.month, 15),
    from_account: accounts[:itau_pai],
    to_account: accounts[:casa],
    category: categories["Serviços e Assinaturas"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
  
  # Celular família - R$ 220 (dia 20)
  Transaction.create!(
    description: "Plano celular família - Vivo",
    amount: 220.00,
    transaction_type: "expense",
    event_date: Date.new(mes_atual.year, mes_atual.month, 20),
    payment_date: Date.new(mes_atual.year, mes_atual.month, 20),
    from_account: accounts[:bradesco_mae],
    to_account: accounts[:casa],
    category: categories["Serviços e Assinaturas"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
  
  # === MERCADO (3-4 VEZES POR MÊS) ===
  compras_mercado = rand(3..4)
  compras_mercado.times do |j|
    valor_compra = case j
    when 0 then rand(450..650)  # Compra grande
    when 1 then rand(280..400)  # Compra média
    else rand(80..180)          # Compras menores
    end
    
    dia_compra = [7, 14, 21, 28][j] + rand(-2..2)
    dia_compra = [dia_compra, 1].max
    dia_compra = [dia_compra, 28].min
    
    mercados = ["Zaffari", "Big", "Carrefour", "Extra", "Walmart"]
    
    transaction = Transaction.create!(
      description: "Supermercado #{mercados.sample} - Compras família",
      amount: valor_compra,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, dia_compra),
      payment_date: Date.new(mes_atual.year, mes_atual.month, dia_compra),
      from_account: [accounts[:itau_pai], accounts[:bradesco_mae], accounts[:nubank_pai]].sample,
      to_account: accounts[:mercado],
      category: categories["Supermercado"],
      recurrence_type: "single",
      status: "confirmed",
    user: default_user
    )
    
    # Associar com fatura se for cartão de crédito
    associar_com_fatura(transaction, statements, accounts)
  end
  
  # === COMBUSTÍVEL (2-3 VEZES POR MÊS) ===
  abastecimentos = rand(2..3)
  abastecimentos.times do |j|
    valor_combustivel = rand(180..320)
    dia_abastecimento = [10, 20, 30][j % 3] + rand(-3..3)
    dia_abastecimento = [dia_abastecimento, 1].max
    dia_abastecimento = [dia_abastecimento, 28].min
    
    postos = ["Ipiranga", "Shell", "Petrobras", "Texaco"]
    
    transaction = Transaction.create!(
      description: "Combustível - Posto #{postos.sample}",
      amount: valor_combustivel,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, dia_abastecimento),
      payment_date: Date.new(mes_atual.year, mes_atual.month, dia_abastecimento),
      from_account: [accounts[:itau_pai], accounts[:nubank_pai]].sample,
      to_account: accounts[:posto],
      category: categories["Transporte"],
      recurrence_type: "single",
      status: "confirmed",
    user: default_user
    )
    
    # Associar com fatura se for cartão de crédito
    associar_com_fatura(transaction, statements, accounts)
  end
  
  # === FARMÁCIA (1-2 VEZES POR MÊS) ===
  compras_farmacia = rand(1..2)
  compras_farmacia.times do |j|
    valor_farmacia = rand(45..250)
    farmacias = ["Panvel", "Droga Raia", "Drogasil", "Pague Menos"]
    
    transaction = Transaction.create!(
      description: "Farmácia #{farmacias.sample} - Medicamentos",
      amount: valor_farmacia,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, rand(5..25)),
      payment_date: Date.new(mes_atual.year, mes_atual.month, rand(5..25)),
      from_account: [accounts[:bradesco_mae], accounts[:inter_mae]].sample,
      to_account: accounts[:farmacia],
      category: categories["Saúde"],
      recurrence_type: "single",
      status: "confirmed",
    user: default_user
    )
    
    # Associar com fatura se for cartão de crédito
    associar_com_fatura(transaction, statements, accounts)
  end
  
  # === RESTAURANTES E DELIVERY (6-10 VEZES POR MÊS) ===
  refeicoes_fora = rand(6..10)
  refeicoes_fora.times do |j|
    valor_refeicao = rand(35..180)
    opcoes_delivery = [
      "iFood - McDonald's", "Uber Eats - Pizza Hut", "iFood - Outback",
      "Restaurante Japonês", "Pizzaria do bairro", "Lanche da tarde",
      "Açaí família", "Churrascaria", "iFood - Burguer King", "Sorveteria"
    ]
    
    transaction = Transaction.create!(
      description: opcoes_delivery.sample,
      amount: valor_refeicao,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      payment_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      from_account: [accounts[:nubank_pai], accounts[:inter_mae], accounts[:santander]].sample,
      to_account: accounts[:lazer],
      category: categories["Restaurante e Delivery"],
      recurrence_type: "single",
      status: "confirmed",
    user: default_user
    )
    
    # Associar com fatura se for cartão de crédito
    associar_com_fatura(transaction, statements, accounts)
  end
  
  # === TRANSPORTE URBANO ===
  transporte_mes = rand(4..8)
  transporte_mes.times do |j|
    valor_transporte = rand(15..85)
    tipos_transporte = ["Uber", "99", "Táxi", "Ônibus", "Estacionamento"]
    
    transaction = Transaction.create!(
      description: "Transporte - #{tipos_transporte.sample}",
      amount: valor_transporte,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      payment_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      from_account: [accounts[:itau_pai], accounts[:bradesco_mae], accounts[:nubank_pai]].sample,
      to_account: accounts[:transporte],
      category: categories["Transporte"],
      recurrence_type: "single",
      status: "confirmed",
    user: default_user
    )
    
    # Associar com fatura se for cartão de crédito
    associar_com_fatura(transaction, statements, accounts)
  end
  
  # === LAZER E ENTRETENIMENTO ===
  atividades_lazer = rand(3..6)
  atividades_lazer.times do |j|
    valor_lazer = rand(40..300)
    atividades = [
      "Cinema família", "Shopping center", "Parque aquático", "Teatro",
      "Show musical", "Clube recreativo", "Museu", "Zoológico",
      "Boliche", "Escape room", "Netflix", "Spotify", "Amazon Prime"
    ]
    
    transaction = Transaction.create!(
      description: atividades.sample,
      amount: valor_lazer,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      payment_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      from_account: [accounts[:inter_mae], accounts[:santander], accounts[:nubank_pai]].sample,
      to_account: accounts[:lazer],
      category: categories["Serviços e Assinaturas"],
      recurrence_type: "single",
      status: "confirmed",
    user: default_user
    )
    
    # Associar com fatura se for cartão de crédito
    associar_com_fatura(transaction, statements, accounts)
  end
  
  # === ROUPAS E CALÇADOS (OCASIONAL) ===
  if rand < 0.6  # 60% de chance por mês
    compras_roupa = rand(1..3)
    compras_roupa.times do |j|
      valor_roupa = rand(120..450)
      lojas = ["C&A", "Renner", "Riachuelo", "Zara", "Nike", "Adidas", "Centauro"]
      
      transaction = Transaction.create!(
        description: "Roupas - #{lojas.sample}",
        amount: valor_roupa,
        transaction_type: "expense",
        event_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
        payment_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
        from_account: [accounts[:santander], accounts[:inter_mae]].sample,
        to_account: accounts[:vestuario],
        category: categories["Compras Diversas"],
        recurrence_type: "single",
        status: "confirmed",
    user: default_user
      )
      
      # Associar com fatura se for cartão de crédito
      associar_com_fatura(transaction, statements, accounts)
    end
  end
  
  # === ENERGIA E ÁGUA ===
  # Energia elétrica (varia por estação)
  fator_sazonal = [1.2, 1.1, 0.9, 0.8, 0.8, 0.9, 1.0, 1.1, 1.0, 0.9, 1.0, 1.3][mes_atual.month - 1]
  valor_energia = (rand(280..450) * fator_sazonal).round(2)
  
  Transaction.create!(
    description: "Conta de luz - CEEE",
    amount: valor_energia,
    transaction_type: "expense",
    event_date: Date.new(mes_atual.year, mes_atual.month, rand(15..25)),
    payment_date: Date.new(mes_atual.year, mes_atual.month, rand(15..25)),
    from_account: accounts[:itau_pai],
    to_account: accounts[:casa],
    category: categories["Habitação"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
  
  # Água e esgoto
  valor_agua = rand(120..180)
  Transaction.create!(
    description: "Conta de água - DMAE",
    amount: valor_agua,
    transaction_type: "expense",
    event_date: Date.new(mes_atual.year, mes_atual.month, rand(18..28)),
    payment_date: Date.new(mes_atual.year, mes_atual.month, rand(18..28)),
    from_account: accounts[:bradesco_mae],
    to_account: accounts[:casa],
    category: categories["Habitação"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
  
  # === ACADEMIA E ATIVIDADES FÍSICAS ===
  Transaction.create!(
    description: "Academia Smart Fit - João",
    amount: 79.90,
    transaction_type: "expense",
    event_date: Date.new(mes_atual.year, mes_atual.month, 5),
    payment_date: Date.new(mes_atual.year, mes_atual.month, 5),
    from_account: accounts[:itau_pai],
    to_account: accounts[:saude],
    category: categories["Bem-estar"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
  
  Transaction.create!(
    description: "Pilates - Maria",
    amount: 180.00,
    transaction_type: "expense",
    event_date: Date.new(mes_atual.year, mes_atual.month, 8),
    payment_date: Date.new(mes_atual.year, mes_atual.month, 8),
    from_account: accounts[:bradesco_mae],
    to_account: accounts[:saude],
    category: categories["Bem-estar"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
end

# === PARCELAMENTOS E COMPRAS GRANDES ===
puts "Criando parcelamentos..."

# TV 65" - 10x de R$ 380 (6 meses atrás)
tv_plan = InstallmentPlan.create!(user: default_user, 
  name: "Smart TV 65 polegadas",
  installment_count: 10,
  recurrence_frequency: "monthly",
  starts_on: 6.months.ago.beginning_of_month + 15.days,
  total_amount: 3800.00,
  status: "active",
  notes: "Smart TV Samsung 65\" comprada na Black Friday",
  category: categories["Compras Diversas"]
)

# Use proper model method to create installment transactions
tv_plan.create_installment_transactions!({
  description_base: "Smart TV Samsung 65\"",
  transaction_type: "expense",
  from_account_id: accounts[:santander].id,
  to_account_id: accounts[:casa].id
})

# Carro usado - 48x de R$ 890 (financiamento que começou 8 meses atrás)
carro_plan = InstallmentPlan.create!(user: default_user, 
  name: "Carro usado (financiamento)",
  installment_count: 48,
  recurrence_frequency: "monthly",
  starts_on: 8.months.ago.beginning_of_month + 10.days,
  total_amount: 42720.00,
  status: "active",
  notes: "Fiat Cronos 2020 - financiamento de 48x",
  category: categories["Compras Diversas"]
)

# Use proper model method to create installment transactions
carro_plan.create_installment_transactions!({
  description_base: "Financiamento Honda Civic",
  transaction_type: "expense",
  from_account_id: accounts[:bradesco_mae].id,
  to_account_id: accounts[:banco].id
})

# Móveis planejados - 24x de R$ 520 (começou 3 meses atrás)
moveis_plan = InstallmentPlan.create!(user: default_user, 
  name: "Móveis planejados",
  installment_count: 24,
  recurrence_frequency: "monthly",
  starts_on: 3.months.ago.beginning_of_month + 5.days,
  total_amount: 24000.00,
  status: "active",
  notes: "Móveis planejados para cozinha e quartos",
  category: categories["Compras Diversas"]
)

# Use proper model method to create installment transactions
moveis_plan.create_installment_transactions!({
  description_base: "Móveis planejados Todeschini",
  transaction_type: "expense",
  from_account_id: accounts[:inter_mae].id,
  to_account_id: accounts[:casa].id
})

# Empréstimo pessoal para emergência - 12x de R$ 1000 (começou 2 meses atrás)
emprestimo_plan = InstallmentPlan.create!(user: default_user, 
  name: "Empréstimo pessoal",
  installment_count: 12,
  recurrence_frequency: "monthly",
  starts_on: 2.months.ago.beginning_of_month + 2.days,
  total_amount: 12000.00,
  status: "active",
  notes: "Empréstimo para reforma da casa",
  category: categories["Finanças"]
)

# Use proper model method to create installment transactions
emprestimo_plan.create_installment_transactions!({
  description_base: "Empréstimo pessoal BB",
  transaction_type: "expense",
  from_account_id: accounts[:itau_pai].id,
  to_account_id: accounts[:banco].id
})

# === COMPROMISSOS RECORRENTES ===
puts "Criando compromissos recorrentes..."

# Salário João - todo dia 5 do mês
salario_joao = RecurringCommitment.create!(user: default_user, 
  name: "Salário João - Empresa ABC",
  default_amount: 8500.00,
  recurrence_frequency: "monthly",
  start_date: 12.months.ago.beginning_of_month + 5.days,
  status: "active",
  category: categories["Salário"],
  from_account: accounts[:empresa_pai],
  to_account: accounts[:itau_pai],
  notes: "Salário mensal como Gerente de TI"
)

# Salário Maria - todo dia 10 do mês
salario_maria = RecurringCommitment.create!(user: default_user, 
  name: "Salário Maria - Consultoria XYZ",
  default_amount: 6800.00,
  recurrence_frequency: "monthly",
  start_date: 12.months.ago.beginning_of_month + 10.days,
  status: "active",
  category: categories["Salário"],
  from_account: accounts[:empresa_mae],
  to_account: accounts[:bradesco_mae],
  notes: "Salário mensal como Consultora de RH"
)

# Aluguel - todo dia 10 do mês
aluguel = RecurringCommitment.create!(user: default_user, 
  name: "Aluguel do apartamento",
  default_amount: 2800.00,
  recurrence_frequency: "monthly",
  start_date: 12.months.ago.beginning_of_month + 10.days,
  status: "active",
  category: categories["Habitação"],
  from_account: accounts[:itau_pai],
  to_account: accounts[:casa],
  notes: "Aluguel mensal do apartamento de 3 quartos"
)

# Escola dos filhos - todo dia 15
escola_filhos = RecurringCommitment.create!(user: default_user, 
  name: "Mensalidade escola particular",
  default_amount: 1200.00,
  recurrence_frequency: "monthly",
  start_date: 12.months.ago.beginning_of_month + 15.days,
  status: "active",
  category: categories["Educação"],
  from_account: accounts[:bradesco_mae],
  to_account: accounts[:escola],
  notes: "Mensalidade dos dois filhos na escola particular"
)

# Internet e TV - todo dia 20
internet_tv = RecurringCommitment.create!(user: default_user, 
  name: "Internet e TV por assinatura",
  default_amount: 180.00,
  recurrence_frequency: "monthly",
  start_date: 12.months.ago.beginning_of_month + 20.days,
  status: "active",
  category: categories["Serviços e Assinaturas"],
  from_account: accounts[:itau_pai],
  to_account: accounts[:casa],
  notes: "Plano 300MB + canais premium"
)

# Academia casal - todo dia 8
academia = RecurringCommitment.create!(user: default_user, 
  name: "Academia Smart Fit - Casal",
  default_amount: 140.00,
  recurrence_frequency: "monthly",
  start_date: 12.months.ago.beginning_of_month + 8.days,
  status: "active",
  category: categories["Bem-estar"],
  from_account: accounts[:itau_pai],
  to_account: accounts[:saude],
  notes: "Plano casal na academia Smart Fit"
)

# Freelance João - toda sexta-feira
freelance_joao = RecurringCommitment.create!(user: default_user, 
  name: "Consultoria TI - Freelance",
  default_amount: 1500.00,
  recurrence_frequency: "monthly",
  start_date: 6.months.ago.beginning_of_month + 25.days,
  status: "active",
  category: categories["Outras Receitas"],
  from_account: accounts[:freelance],
  to_account: accounts[:itau_pai],
  notes: "Consultoria em desenvolvimento de sistemas"
)

puts "Compromissos recorrentes criados: #{RecurringCommitment.count}"

# === GERAR TRANSAÇÕES DOS COMPROMISSOS RECORRENTES ===
puts "Gerando transações recorrentes usando o job oficial..."

# Use the official job to generate recurring transactions for the past months
# This ensures we use the proper model methods and business logic
(1..12).each do |months_ago|
  target_date = months_ago.months.ago.beginning_of_month
  
  # Generate transactions for each day of the month to catch all recurring commitments
  (1..target_date.end_of_month.day).each do |day|
    check_date = Date.new(target_date.year, target_date.month, day)
    next if check_date > Date.current # Don't generate future transactions
    
    # Run the job for this specific date
    result = GenerateRecurringTransactionsJob.new.perform(check_date)
    if result[:generated_count] > 0
      puts "  Generated #{result[:generated_count]} recurring transactions for #{check_date}"
    end
  end
end

puts "Transações recorrentes geradas automaticamente!"

# === ATUALIZAR VALORES DAS FATURAS ===
puts "Atualizando valores das faturas..."

# Atualizar valores das faturas baseado nas transações de cartão já associadas
CreditStatement.all.each do |fatura|
  total_fatura = fatura.transactions.sum(:amount)
  valor_pago = fatura.status == 'paid' ? total_fatura : 0
  
  fatura.update!(
    amount_due: total_fatura,
    amount_paid: valor_pago
  )
  
  # Criar transação de pagamento da fatura se foi paga
  if fatura.status == 'paid' && total_fatura > 0
    conta_origem = fatura.account.name.include?('João') ? accounts[:itau_pai] : accounts[:bradesco_mae]
    
    Transaction.create!(
      description: "Pagamento fatura #{fatura.account.name}",
      amount: total_fatura,
      transaction_type: "expense",
      event_date: fatura.paid_on,
      payment_date: fatura.paid_on,
      from_account: conta_origem,
      to_account: fatura.account,
      category: categories["Finanças"],
      recurrence_type: "single",
      status: "confirmed",
    user: default_user
    )
  end
end

# === TRANSFERÊNCIAS ENTRE CONTAS ===
puts "Criando transferências..."

# Transferências entre contas da família
8.times do |i|
  data_transferencia = (Date.today - rand(90..300).days)
  valor_transferencia = rand(200..2000)
  
  # Diferentes tipos de transferências
  case i % 4
  when 0
    # Poupança para conta corrente
    from_account = accounts[:poupanca]
    to_account = [accounts[:itau_pai], accounts[:bradesco_mae]].sample
    descricao = "Transferência da poupança"
  when 1
    # Entre contas correntes
    from_account = accounts[:itau_pai]
    to_account = accounts[:bradesco_mae]
    descricao = "Transferência PIX entre contas"
  when 2
    # Para poupança (reserva de emergência)
    from_account = [accounts[:itau_pai], accounts[:bradesco_mae]].sample
    to_account = accounts[:poupanca]
    descricao = "Reserva de emergência"
  else
    # Transferência para pagamento de cartão
    from_account = accounts[:bradesco_mae]
    to_account = accounts[:itau_pai]
    descricao = "Transferência para pagamento"
  end
  
  Transaction.create!(
    description: descricao,
    amount: valor_transferencia,
    transaction_type: "transfer",
    event_date: data_transferencia,
    payment_date: data_transferencia,
    from_account: from_account,
    to_account: to_account,
    category: nil,  # Transferências não têm categoria
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
end

# === EMERGÊNCIAS E GASTOS EXTRAS ===
puts "Adicionando gastos extras e emergências..."

# Consulta médica particular (2x nos últimos 12 meses)
2.times do |i|
  data_consulta = Date.today - rand(30..360).days
  valor_consulta = rand(200..600)
  medicos = ["Cardiologista", "Dermatologista", "Ortopedista", "Dentista", "Pediatra"]
  
  Transaction.create!(
    description: "Consulta #{medicos.sample} - particular",
    amount: valor_consulta,
    transaction_type: "expense",
    event_date: data_consulta,
    payment_date: data_consulta,
    from_account: accounts[:bradesco_mae],
    to_account: accounts[:saude],
    category: categories["Saúde"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
end

# Manutenção do carro (3x nos últimos 12 meses)
3.times do |i|
  data_manutencao = Date.today - rand(60..360).days
  valor_manutencao = rand(300..1200)
  servicos = ["Revisão completa", "Troca de pneus", "Mecânica geral", "Funilaria"]
  
  Transaction.create!(
    description: "#{servicos.sample} - Honda Civic",
    amount: valor_manutencao,
    transaction_type: "expense",
    event_date: data_manutencao,
    payment_date: data_manutencao,
    from_account: accounts[:itau_pai],
    to_account: accounts[:transporte],
    category: categories["Manutenção"] || categories["Transporte"],
    recurrence_type: "single",
    status: "confirmed",
    user: default_user
  )
end

# Viagem de família (1x nos últimos 12 meses)
data_viagem = Date.today - rand(90..300).days
transaction = Transaction.create!(
  description: "Viagem família - Gramado/RS",
  amount: 2800.00,
  transaction_type: "expense",
  event_date: data_viagem,
  payment_date: data_viagem,
  from_account: accounts[:santander],
  to_account: accounts[:lazer],
  category: categories["Lazer"],
  recurrence_type: "single",
  status: "confirmed",
    user: default_user
)

# Associar com fatura se for cartão de crédito
associar_com_fatura(transaction, statements, accounts)

# Alguns gastos de emergência que deixaram o mês negativo
mes_negativo_1 = Date.today - 4.months
transaction = Transaction.create!(
  description: "Troca de geladeira - emergência",
  amount: 2400.00,
  transaction_type: "expense",
  event_date: mes_negativo_1,
  payment_date: mes_negativo_1,
  from_account: accounts[:nubank_pai],
  to_account: accounts[:casa],
  category: categories["Compras Diversas"],
  recurrence_type: "single",
  status: "confirmed",
    user: default_user
)

# Associar com fatura se for cartão de crédito
associar_com_fatura(transaction, statements, accounts)

mes_negativo_2 = Date.today - 7.months
transaction = Transaction.create!(
  description: "Dentista emergência - tratamento canal",
  amount: 1800.00,
  transaction_type: "expense",
  event_date: mes_negativo_2,
  payment_date: mes_negativo_2,
  from_account: accounts[:inter_mae],
  to_account: accounts[:saude],
  category: categories["Saúde"],
  recurrence_type: "single",
  status: "confirmed",
    user: default_user
)

# Associar com fatura se for cartão de crédito
associar_com_fatura(transaction, statements, accounts)

# === TRANSAÇÕES FUTURAS (PENDENTES) ===
puts "Criando compromissos futuros..."

# Próxima viagem de família (planejada)
Transaction.create!(
  description: "Viagem família - Florianópolis (planejada)",
  amount: 3200.00,
  transaction_type: "expense",
  event_date: Date.today + 45.days,
  payment_date: Date.today + 45.days,
  from_account: accounts[:poupanca],
  to_account: accounts[:lazer],
  category: categories["Lazer"],
  recurrence_type: "single",
  status: "pending",
    user: default_user
)

# Material escolar próximo ano
Transaction.create!(
  description: "Material escolar 2025 - 3 filhos",
  amount: 1200.00,
  transaction_type: "expense",
  event_date: Date.today + 60.days,
  payment_date: Date.today + 60.days,
  from_account: accounts[:bradesco_mae],
  to_account: accounts[:escola],
  category: categories["Educação"],
  recurrence_type: "single",
  status: "pending",
    user: default_user
)

# === ESTATÍSTICAS FINAIS ===
puts "\n=== RESUMO DOS DADOS GERADOS ==="
puts "Total de transações: #{Transaction.count}"
puts "Receitas confirmadas: #{Transaction.income.confirmed.count}"
puts "Despesas confirmadas: #{Transaction.expense.confirmed.count}"
puts "Transferências confirmadas: #{Transaction.transfer.confirmed.count}"
puts "Parcelamentos criados: #{InstallmentPlan.count}"
puts "Compromissos recorrentes: #{RecurringCommitment.count}"
puts "Faturas de cartão: #{CreditStatement.count}"

# Análise dos novos modelos
puts "\n=== ANÁLISE DOS NOVOS MODELOS ==="
puts "Planos de parcelamento ativos: #{InstallmentPlan.active.count}"
puts "Valor total dos parcelamentos: R$ #{InstallmentPlan.sum(:total_amount).to_i}"
puts "Compromissos recorrentes ativos: #{RecurringCommitment.active.count}"
puts "Valor mensal total dos compromissos: R$ #{RecurringCommitment.active.with_default_amount.sum(:default_amount).to_i}"

# Estatísticas por mês
puts "\n=== RESUMO POR MÊS ==="
meses_gerados.each do |mes_str|
  mes_date = Date.strptime(mes_str, '%Y-%m')
  receitas = Transaction.income.confirmed.in_competence_month(mes_date).sum(:amount)
  despesas = Transaction.expense.confirmed.in_competence_month(mes_date).sum(:amount)
  transferencias = Transaction.transfer.confirmed.in_competence_month(mes_date).sum(:amount)
  saldo = receitas - despesas
  
  puts "#{mes_str}: Receitas R$ #{receitas.to_i} | Despesas R$ #{despesas.to_i} | Transferências R$ #{transferencias.to_i} | Saldo R$ #{saldo.to_i}"
end

puts "\nSeed realista finalizado com sucesso! 🎉"
