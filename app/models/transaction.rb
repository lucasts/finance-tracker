class Transaction < ApplicationRecord
  belongs_to :from_account, class_name: "Account"
  belongs_to :to_account, class_name: "Account", optional: true
  belongs_to :category
  belongs_to :transaction_group, optional: true

  validates :description, :amount, :date, :period, :transaction_type, presence: true
  validates :transaction_type, inclusion: { in: %w[income expense] }

  scope :for_period, ->(period) { where(period: period) }

  # Preenche payment_period automaticamente, se não informado
  before_validation :fill_payment_period

  # Exemplo de enum para status (se ainda não implementado)
  enum status: { draft: 0, confirmed: 1, cancelled: 2 }

  # Deriva o mês do evento (competência)
  def event_month
    event_date.strftime('%Y-%m') if event_date.present?
  end

  # Deriva o mês do pagamento (padrão: payment_date, fallback para event_date)
  def payment_month
    (payment_date || event_date)&.strftime('%Y-%m')
  end

  def fill_payment_period
    self.payment_period ||= payment_month
  end
end