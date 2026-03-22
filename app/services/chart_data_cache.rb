# frozen_string_literal: true

# ChartDataCache
# Centraliza chave e invalidação do cache de dados de gráfico (últimos 12 meses).
# Evita duplicação de lógica de key e facilita evolução de versão.
module ChartDataCache
  VERSION = "v1"

  module_function

  def key_for(user_id, today: Date.today)
    [ "chart-data-#{VERSION}", user_id, today.strftime("%Y-%m") ]
  end

  def fetch(user_id, expires_in: 6.hours)
    Rails.cache.fetch(key_for(user_id)) { yield }
  end

  def invalidate_for(user_id)
    Rails.cache.delete(key_for(user_id))
  end

  # Invalida apenas se a transação afetar a janela de 12 meses exibida
  def invalidate_if_relevant(transaction)
    return unless transaction&.user_id && transaction.event_date
    window_start = (Date.today - 11.months).beginning_of_month
    window_end = Date.today.end_of_month
    invalidate_for(transaction.user_id) if (window_start..window_end).cover?(transaction.event_date)
  end
end
