puts "Seeding realistic family financial data..."

require 'date'

# Limpa dados existentes de demo
Transaction.destroy_all
TransactionGroup.destroy_all
CreditStatement.destroy_all
Account.destroy_all

# === CONTAS E CARTÕES ===
puts "Criando contas da família..."

accounts = {
  # Contas correntes
  itau_pai:      Account.create!(name: "Itaú - João", account_type: AccountType.find_by(code: "BANK")),
  bradesco_mae:  Account.create!(name: "Bradesco - Maria", account_type: AccountType.find_by(code: "BANK")),
  
  # Cartões de crédito
  nubank_pai:    Account.create!(name: "Nubank - João", account_type: AccountType.find_by(code: "CREDIT"), closing_day: 15, due_day: 5),
  inter_mae:     Account.create!(name: "Inter - Maria", account_type: AccountType.find_by(code: "CREDIT"), closing_day: 20, due_day: 10),
  santander:     Account.create!(name: "Santander - Família", account_type: AccountType.find_by(code: "CREDIT"), closing_day: 25, due_day: 15),
  
  # Poupança
  poupanca:      Account.create!(name: "Poupança Emergência", account_type: AccountType.find_by(code: "SAVINGS")),
  
  # Contas de despesas (estabelecimentos)
  mercado:       Account.create!(name: "Supermercados", account_type: AccountType.find_by(code: "EXPENSE")),
  farmacia:      Account.create!(name: "Farmácias", account_type: AccountType.find_by(code: "EXPENSE")),
  escola:        Account.create!(name: "Escola dos Filhos", account_type: AccountType.find_by(code: "EXPENSE")),
  posto:         Account.create!(name: "Postos de Gasolina", account_type: AccountType.find_by(code: "EXPENSE")),
  lazer:         Account.create!(name: "Lazer e Entretenimento", account_type: AccountType.find_by(code: "EXPENSE")),
  saude:         Account.create!(name: "Saúde e Medicina", account_type: AccountType.find_by(code: "EXPENSE")),
  casa:          Account.create!(name: "Casa e Utilidades", account_type: AccountType.find_by(code: "EXPENSE")),
  vestuario:     Account.create!(name: "Roupas e Calçados", account_type: AccountType.find_by(code: "EXPENSE")),
  transporte:    Account.create!(name: "Transporte", account_type: AccountType.find_by(code: "EXPENSE")),
  banco:         Account.create!(name: "Bancos e Financeiras", account_type: AccountType.find_by(code: "EXPENSE")),
  
  # Contas de receita
  empresa_pai:   Account.create!(name: "Empresa João", account_type: AccountType.find_by(code: "REVENUE")),
  empresa_mae:   Account.create!(name: "Empresa Maria", account_type: AccountType.find_by(code: "REVENUE")),
  freelance:     Account.create!(name: "Trabalhos Extra", account_type: AccountType.find_by(code: "REVENUE"))
}

# === CATEGORIAS EXPANDIDAS ===
puts "Criando categorias adicionais..."

# Adicionar categorias que não existem
categorias_extras = [
  "Alimentação", "Saúde", "Transporte", "Educação", "Lazer", "Habitação",
  "Vestuário", "Combustível", "Telefonia", "Internet", "Streaming",
  "Academia", "Beleza", "Empréstimo", "Investimento", "Transferência",
  "Impostos", "Seguros", "Manutenção", "Decoração"
]

categorias_extras.each do |nome|
  Category.find_or_create_by(name: nome)
end

categories = Category.all.index_by(&:name)

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
    recurrence_type: "fixed",
    status: "confirmed"
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
    recurrence_type: "fixed",
    status: "confirmed"
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
      category: categories["Freelance"],
      recurrence_type: "single",
      status: "confirmed"
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
    category: categories["Educação"] || categories["Escola"],
    recurrence_type: "fixed",
    status: "confirmed"
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
    category: categories["Plano Saúde"] || categories["Saúde"],
    recurrence_type: "fixed",
    status: "confirmed"
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
    category: categories["Aluguel"] || categories["Habitação"],
    recurrence_type: "fixed",
    status: "confirmed"
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
    category: categories["Internet"] || categories["Assinatura"],
    recurrence_type: "fixed",
    status: "confirmed"
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
    category: categories["Telefonia"] || categories["Assinatura"],
    recurrence_type: "fixed",
    status: "confirmed"
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
    
    Transaction.create!(
      description: "Supermercado #{mercados.sample} - Compras família",
      amount: valor_compra,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, dia_compra),
      payment_date: Date.new(mes_atual.year, mes_atual.month, dia_compra),
      from_account: [accounts[:itau_pai], accounts[:bradesco_mae], accounts[:nubank_pai]].sample,
      to_account: accounts[:mercado],
      category: categories["Supermercado"] || categories["Alimentação"],
      recurrence_type: "single",
      status: "confirmed"
    )
  end
  
  # === COMBUSTÍVEL (2-3 VEZES POR MÊS) ===
  abastecimentos = rand(2..3)
  abastecimentos.times do |j|
    valor_combustivel = rand(180..320)
    dia_abastecimento = [10, 20, 30][j % 3] + rand(-3..3)
    dia_abastecimento = [dia_abastecimento, 1].max
    dia_abastecimento = [dia_abastecimento, 28].min
    
    postos = ["Ipiranga", "Shell", "Petrobras", "Texaco"]
    
    Transaction.create!(
      description: "Combustível - Posto #{postos.sample}",
      amount: valor_combustivel,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, dia_abastecimento),
      payment_date: Date.new(mes_atual.year, mes_atual.month, dia_abastecimento),
      from_account: [accounts[:itau_pai], accounts[:nubank_pai]].sample,
      to_account: accounts[:posto],
      category: categories["Combustível"] || categories["Transporte"],
      recurrence_type: "single",
      status: "confirmed"
    )
  end
  
  # === FARMÁCIA (1-2 VEZES POR MÊS) ===
  compras_farmacia = rand(1..2)
  compras_farmacia.times do |j|
    valor_farmacia = rand(45..250)
    farmacias = ["Panvel", "Droga Raia", "Drogasil", "Pague Menos"]
    
    Transaction.create!(
      description: "Farmácia #{farmacias.sample} - Medicamentos",
      amount: valor_farmacia,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, rand(5..25)),
      payment_date: Date.new(mes_atual.year, mes_atual.month, rand(5..25)),
      from_account: [accounts[:bradesco_mae], accounts[:inter_mae]].sample,
      to_account: accounts[:farmacia],
      category: categories["Farmácia"] || categories["Saúde"],
      recurrence_type: "single",
      status: "confirmed"
    )
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
    
    Transaction.create!(
      description: opcoes_delivery.sample,
      amount: valor_refeicao,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      payment_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      from_account: [accounts[:nubank_pai], accounts[:inter_mae], accounts[:santander]].sample,
      to_account: accounts[:lazer],
      category: categories["Restaurante"] || categories["Lazer"],
      recurrence_type: "single",
      status: "confirmed"
    )
  end
  
  # === TRANSPORTE URBANO ===
  transporte_mes = rand(4..8)
  transporte_mes.times do |j|
    valor_transporte = rand(15..85)
    tipos_transporte = ["Uber", "99", "Táxi", "Ônibus", "Estacionamento"]
    
    Transaction.create!(
      description: "Transporte - #{tipos_transporte.sample}",
      amount: valor_transporte,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      payment_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      from_account: [accounts[:itau_pai], accounts[:bradesco_mae], accounts[:nubank_pai]].sample,
      to_account: accounts[:transporte],
      category: categories["Transporte"],
      recurrence_type: "single",
      status: "confirmed"
    )
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
    
    Transaction.create!(
      description: atividades.sample,
      amount: valor_lazer,
      transaction_type: "expense",
      event_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      payment_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
      from_account: [accounts[:inter_mae], accounts[:santander], accounts[:nubank_pai]].sample,
      to_account: accounts[:lazer],
      category: categories["Netflix"] || categories["Lazer"],
      recurrence_type: "single",
      status: "confirmed"
    )
  end
  
  # === ROUPAS E CALÇADOS (OCASIONAL) ===
  if rand < 0.6  # 60% de chance por mês
    compras_roupa = rand(1..3)
    compras_roupa.times do |j|
      valor_roupa = rand(120..450)
      lojas = ["C&A", "Renner", "Riachuelo", "Zara", "Nike", "Adidas", "Centauro"]
      
      Transaction.create!(
        description: "Roupas - #{lojas.sample}",
        amount: valor_roupa,
        transaction_type: "expense",
        event_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
        payment_date: Date.new(mes_atual.year, mes_atual.month, rand(1..28)),
        from_account: [accounts[:santander], accounts[:inter_mae]].sample,
        to_account: accounts[:vestuario],
        category: categories["Compras"] || categories["Vestuário"],
        recurrence_type: "single",
        status: "confirmed"
      )
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
    category: categories["Energia"],
    recurrence_type: "fixed",
    status: "confirmed"
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
    category: categories["Habitação"] || categories["Energia"],
    recurrence_type: "fixed",
    status: "confirmed"
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
    category: categories["Academia"] || categories["Saúde"],
    recurrence_type: "fixed",
    status: "confirmed"
  )
  
  Transaction.create!(
    description: "Pilates - Maria",
    amount: 180.00,
    transaction_type: "expense",
    event_date: Date.new(mes_atual.year, mes_atual.month, 8),
    payment_date: Date.new(mes_atual.year, mes_atual.month, 8),
    from_account: accounts[:bradesco_mae],
    to_account: accounts[:saude],
    category: categories["Academia"] || categories["Saúde"],
    recurrence_type: "fixed",
    status: "confirmed"
  )
end

# === PARCELAMENTOS E COMPRAS GRANDES ===
puts "Criando parcelamentos..."

# TV 65" - 10x de R$ 380 (6 meses atrás)
tv_group = TransactionGroup.create!(
  name: "Smart TV 65 polegadas",
  group_type: "installment",
  installment_count: 10,
  starts_on: 6.months.ago.beginning_of_month + 15.days
)

10.times do |i|
  data_parcela = tv_group.starts_on + i.months
  status = data_parcela <= Date.today ? "confirmed" : "pending"
  
  Transaction.create!(
    description: "Smart TV Samsung 65\" - #{i + 1}/10",
    amount: 380.00,
    transaction_type: "expense",
    event_date: data_parcela,
    payment_date: data_parcela.next_month.change(day: 15),
    from_account: accounts[:santander],
    to_account: accounts[:casa],
    category: categories["Compras"],
    recurrence_type: "fixed",
    installment: i + 1,
    transaction_group: tv_group,
    status: status
  )
end

# Carro usado - 48x de R$ 890 (financiamento que começou 8 meses atrás)
carro_group = TransactionGroup.create!(
  name: "Financiamento Civic 2019",
  group_type: "installment",
  installment_count: 48,
  starts_on: 8.months.ago.beginning_of_month + 10.days
)

48.times do |i|
  data_parcela = carro_group.starts_on + i.months
  next if data_parcela > 3.years.from_now
  status = data_parcela <= Date.today ? "confirmed" : "pending"
  
  Transaction.create!(
    description: "Financiamento Honda Civic - #{i + 1}/48",
    amount: 890.00,
    transaction_type: "expense",
    event_date: data_parcela,
    payment_date: data_parcela,
    from_account: accounts[:bradesco_mae],
    to_account: accounts[:banco],
    category: categories["Empréstimo"] || categories["Transporte"],
    recurrence_type: "fixed",
    installment: i + 1,
    transaction_group: carro_group,
    status: status
  )
end

# Móveis planejados - 24x de R$ 520 (começou 3 meses atrás)
moveis_group = TransactionGroup.create!(
  name: "Móveis planejados cozinha",
  group_type: "installment",
  installment_count: 24,
  starts_on: 3.months.ago.beginning_of_month + 20.days
)

24.times do |i|
  data_parcela = moveis_group.starts_on + i.months
  status = data_parcela <= Date.today ? "confirmed" : "pending"
  
  Transaction.create!(
    description: "Móveis planejados Todeschini - #{i + 1}/24",
    amount: 520.00,
    transaction_type: "expense",
    event_date: data_parcela,
    payment_date: data_parcela.next_month.change(day: 10),
    from_account: accounts[:inter_mae],
    to_account: accounts[:casa],
    category: categories["Decoração"] || categories["Casa"],
    recurrence_type: "fixed",
    installment: i + 1,
    transaction_group: moveis_group,
    status: status
  )
end

# Empréstimo pessoal para emergência - 36x de R$ 450 (começou 10 meses atrás)
emprestimo_group = TransactionGroup.create!(
  name: "Empréstimo pessoal Banco do Brasil",
  group_type: "installment",
  installment_count: 36,
  starts_on: 10.months.ago.beginning_of_month + 5.days
)

36.times do |i|
  data_parcela = emprestimo_group.starts_on + i.months
  status = data_parcela <= Date.today ? "confirmed" : "pending"
  
  Transaction.create!(
    description: "Empréstimo pessoal BB - #{i + 1}/36",
    amount: 450.00,
    transaction_type: "expense",
    event_date: data_parcela,
    payment_date: data_parcela,
    from_account: accounts[:itau_pai],
    to_account: accounts[:banco],
    category: categories["Empréstimo"],
    recurrence_type: "fixed",
    installment: i + 1,
    transaction_group: emprestimo_group,
    status: status
  )
end

# === FATURAS DE CARTÃO DE CRÉDITO ===
puts "Criando faturas de cartão..."

# Gerar faturas para os últimos 6 meses
(-5..0).each do |offset|
  mes_fatura = Date.today.beginning_of_month + offset.months
  
  # Fatura Nubank - João
  fatura_nubank = CreditStatement.create!(
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
  fatura_inter = CreditStatement.create!(
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
  fatura_santander = CreditStatement.create!(
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

# Atualizar valores das faturas baseado nas transações de cartão
CreditStatement.all.each do |fatura|
  mes_fatura_date = Date.strptime(fatura.month, '%Y-%m')
  
  total_fatura = Transaction
    .where(from_account: fatura.account)
    .in_competence_month(mes_fatura_date)
    .sum(:amount)
  
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
      category: categories["Transferência"] || categories.values.sample,
      recurrence_type: "single",
      status: "confirmed"
    )
  end
end

# === TRANSFERÊNCIAS ENTRE CONTAS ===
puts "Criando transferências..."

# Algumas transferências ocasionais entre contas da família
4.times do |i|
  data_transferencia = (Date.today - rand(90..300).days)
  valor_transferencia = rand(500..2000)
  
  Transaction.create!(
    description: "Transferência entre contas",
    amount: valor_transferencia,
    transaction_type: "income",
    event_date: data_transferencia,
    payment_date: data_transferencia,
    from_account: accounts[:poupanca],
    to_account: [accounts[:itau_pai], accounts[:bradesco_mae]].sample,
    category: categories["Transferência"] || categories["PIX Recebido"],
    recurrence_type: "single",
    status: "confirmed"
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
    status: "confirmed"
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
    status: "confirmed"
  )
end

# Viagem de família (1x nos últimos 12 meses)
data_viagem = Date.today - rand(90..300).days
Transaction.create!(
  description: "Viagem família - Gramado/RS",
  amount: 2800.00,
  transaction_type: "expense",
  event_date: data_viagem,
  payment_date: data_viagem,
  from_account: accounts[:santander],
  to_account: accounts[:lazer],
  category: categories["Lazer"],
  recurrence_type: "single",
  status: "confirmed"
)

# Alguns gastos de emergência que deixaram o mês negativo
mes_negativo_1 = Date.today - 4.months
Transaction.create!(
  description: "Troca de geladeira - emergência",
  amount: 2400.00,
  transaction_type: "expense",
  event_date: mes_negativo_1,
  payment_date: mes_negativo_1,
  from_account: accounts[:nubank_pai],
  to_account: accounts[:casa],
  category: categories["Casa"] || categories["Compras"],
  recurrence_type: "single",
  status: "confirmed"
)

mes_negativo_2 = Date.today - 7.months
Transaction.create!(
  description: "Dentista emergência - tratamento canal",
  amount: 1800.00,
  transaction_type: "expense",
  event_date: mes_negativo_2,
  payment_date: mes_negativo_2,
  from_account: accounts[:inter_mae],
  to_account: accounts[:saude],
  category: categories["Saúde"],
  recurrence_type: "single",
  status: "confirmed"
)

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
  status: "pending"
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
  status: "pending"
)

# === ESTATÍSTICAS FINAIS ===
puts "\n=== RESUMO DOS DADOS GERADOS ==="
puts "Total de transações: #{Transaction.count}"
puts "Receitas confirmadas: #{Transaction.income.confirmed.count}"
puts "Despesas confirmadas: #{Transaction.expense.confirmed.count}"
puts "Parcelamentos criados: #{TransactionGroup.count}"
puts "Faturas de cartão: #{CreditStatement.count}"

# Estatísticas por mês
puts "\n=== RESUMO POR MÊS ==="
meses_gerados.each do |mes_str|
  mes_date = Date.strptime(mes_str, '%Y-%m')
  receitas = Transaction.income.confirmed.in_competence_month(mes_date).sum(:amount)
  despesas = Transaction.expense.confirmed.in_competence_month(mes_date).sum(:amount)
  saldo = receitas - despesas
  
  puts "#{mes_str}: Receitas R$ #{receitas.to_i} | Despesas R$ #{despesas.to_i} | Saldo R$ #{saldo.to_i}"
end

puts "\nSeed realista finalizado com sucesso! 🎉"
