# frozen_string_literal: true

module FinancialConstants
  # Alert thresholds
  LOW_BALANCE_THRESHOLD = 1000.0
  CRITICAL_BALANCE_THRESHOLD = 0.0
  
  # Calculation precision
  PERCENTAGE_PRECISION = 1
  DECIMAL_PRECISION = 2
  
  # Analysis confidence levels
  HIGH_CONFIDENCE_MIN = 80
  MEDIUM_CONFIDENCE_MIN = 60
  LOW_CONFIDENCE_MIN = 40
  MAX_CONFIDENCE = 100
  
  # Analysis parameters
  CONFIDENCE_MULTIPLIER = 5
  PERCENTAGE_MULTIPLIER = 100
  
  # Default values
  DEFAULT_ZERO_BALANCE = 0.0
  DEFAULT_PERCENTAGE = 0
  DEFAULT_CONFIDENCE = 0
  
  # Variability thresholds
  MAX_COEFFICIENT_OF_VARIATION = 100
  
  # File size limits (in bytes)
  MAX_IMPORT_FILE_SIZE = 10.megabytes
  
  # Pagination defaults
  DEFAULT_PAGE_SIZE = 25
  MAX_PAGE_SIZE = 100
  
  # Time periods
  MONTHS_PER_YEAR = 12
  DAYS_PER_MONTH = 30
  
  # Money formatting
  CURRENCY_SYMBOL = 'R$'.freeze
  CURRENCY_CODE = 'BRL'.freeze
  THOUSAND_SEPARATOR = '.'.freeze
  DECIMAL_SEPARATOR = ','.freeze
  
  # Matching tolerances for import services
  AMOUNT_ABSOLUTE_TOLERANCE = 0.01
  AMOUNT_PERCENTAGE_TOLERANCE = 0.05  # 5%
  RECURRING_AMOUNT_TOLERANCE = 0.10   # 10%
  DATE_TOLERANCE_DAYS = 3
  
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
  
  # Rounding helpers
  def self.round_percentage(value)
    value.round(PERCENTAGE_PRECISION)
  end
  
  def self.round_decimal(value)
    value.round(DECIMAL_PRECISION)
  end
  
  def self.calculate_percentage(numerator, denominator)
    return DEFAULT_PERCENTAGE if denominator.zero?
    round_percentage((numerator / denominator) * PERCENTAGE_MULTIPLIER)
  end
  
  def self.safe_divide(numerator, denominator, default = DEFAULT_ZERO_BALANCE)
    return default if denominator.zero?
    numerator / denominator
  end
  
  # Category classification helpers
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
