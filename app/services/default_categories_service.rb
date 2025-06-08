class DefaultCategoriesService
  def self.create_for_user(user)
    return if Rails.env.test?
    new(user).create_default_categories
  end
  
  def initialize(user)
    @user = user
  end
  
  def create_default_categories
    expense_categories.each do |category_data|
      @user.categories.find_or_create_by(name: category_data[:name]) do |category|
        category.category_type = 'expense'
        category.description = category_data[:description]
      end
    end
    
    income_categories.each do |category_data|
      @user.categories.find_or_create_by(name: category_data[:name]) do |category|
        category.category_type = 'income'
        category.description = category_data[:description]
      end
    end
  end
  
  private
  
  def expense_categories
    [
      {
        name: 'Habitação',
        description: 'Aluguel, energia, água, condomínio e manutenção da casa'
      },
      {
        name: 'Supermercado',
        description: 'Compras para casa, supermercado, feira e produtos de primeira necessidade'
      },
      {
        name: 'Restaurante e Delivery',
        description: 'Refeições fora, apps de entrega, restaurantes e lanchonetes'
      },
      {
        name: 'Transporte',
        description: 'Combustível, transporte público, manutenção de veículos e locomoção'
      },
      {
        name: 'Saúde',
        description: 'Plano de saúde, farmácia, exames e consultas médicas'
      },
      {
        name: 'Educação',
        description: 'Escola, cursos, livros e material de estudo'
      },
      {
        name: 'Serviços e Assinaturas',
        description: 'Internet, telefonia, streaming, apps e outros serviços mensais'
      },
      {
        name: 'Bem-estar',
        description: 'Academia, estética, massagem e cuidados pessoais'
      },
      {
        name: 'Finanças',
        description: 'Empréstimos, investimentos, impostos e seguros'
      },
      {
        name: 'Lazer',
        description: 'Passeios, eventos, viagens e entretenimento'
      },
      {
        name: 'Compras Diversas',
        description: 'Roupas, eletrônicos, presentes e outras compras variadas'
      }
    ]
  end
  
  def income_categories
    [
      {
        name: 'Salário',
        description: 'Salário principal, 13º salário e outros rendimentos do trabalho'
      },
      {
        name: 'Rendimentos',
        description: 'Juros, dividendos, aluguéis e outros rendimentos financeiros'
      },
      {
        name: 'Outras Receitas',
        description: 'Presentes, vendas, extras e receitas diversas'
      }
    ]
  end
end
