# frozen_string_literal: true

module CategoryConfiguration
  # Variable expense categories that need analysis
  VARIABLE_EXPENSE_KEYWORDS = [
    'supermercado',
    'farmácia', 
    'gasolina',
    'consultas',
    'mercado',
    'combustível',
    'alimentação',
    'transporte',
    'saúde',
    'lazer',
    'entretenimento'
  ].freeze
  
  # Fixed expense categories (predictable amounts)
  FIXED_EXPENSE_KEYWORDS = [
    'aluguel',
    'financiamento',
    'empréstimo',
    'mensalidade',
    'assinatura',
    'seguro',
    'condomínio',
    'internet',
    'telefone',
    'água',
    'luz',
    'gás'
  ].freeze
  
  # Essential categories (high priority)
  ESSENTIAL_CATEGORIES = [
    'alimentação',
    'moradia',
    'transporte',
    'saúde',
    'educação'
  ].freeze
  
  # Non-essential categories (can be reduced in budget cuts)
  NON_ESSENTIAL_CATEGORIES = [
    'lazer',
    'entretenimento',
    'viagem',
    'shopping',
    'restaurante',
    'delivery'
  ].freeze
  
  def self.variable_expense?(name_or_category)
    text = name_or_category.to_s.downcase
    VARIABLE_EXPENSE_KEYWORDS.any? { |keyword| text.include?(keyword) }
  end
  
  def self.fixed_expense?(name_or_category)
    text = name_or_category.to_s.downcase  
    FIXED_EXPENSE_KEYWORDS.any? { |keyword| text.include?(keyword) }
  end
  
  def self.essential?(name_or_category)
    text = name_or_category.to_s.downcase
    ESSENTIAL_CATEGORIES.any? { |keyword| text.include?(keyword) }
  end
  
  def self.non_essential?(name_or_category)
    text = name_or_category.to_s.downcase
    NON_ESSENTIAL_CATEGORIES.any? { |keyword| text.include?(keyword) }
  end
end
