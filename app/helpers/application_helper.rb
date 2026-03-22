module ApplicationHelper
  # Money formatting helper with Brazilian standards
  # Returns plain formatted string (no HTML wrapper)
  def format_money(amount, options = {})
    return "R$ 0,00" if amount.blank? || amount.zero?

    defaults = {
      unit: "R$ ",
      separator: ",",
      delimiter: ".",
      precision: 2
    }

    number_to_currency(amount, defaults.merge(options))
  end

  def parse_money(value)
    MoneyParsingConcern.parse_money_string(value)
  end

  def file_size_human(size_in_bytes)
    return "0 B" if size_in_bytes.nil? || size_in_bytes == 0

    units = %w[B KB MB GB TB]
    base = 1024.0

    if size_in_bytes < base
      "#{size_in_bytes} B"
    else
      exponent = (Math.log(size_in_bytes) / Math.log(base)).floor
      exponent = [ exponent, units.length - 1 ].min

      size = (size_in_bytes / (base ** exponent)).round(1)
      "#{size} #{units[exponent]}"
    end
  end
end
