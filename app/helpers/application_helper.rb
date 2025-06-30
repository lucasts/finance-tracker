module ApplicationHelper
  
  # Helper methods for money formatting
  def format_currency(amount, options = {})
    MoneyFormattingHelper.format_money_display(amount, options)
  end

  def format_currency_compact(amount)
    MoneyFormattingHelper.format_money_display(amount, show_currency: false)
  end

  def parse_money(value)
    MoneyFormattingHelper.parse_money_string(value)
  end

  def file_size_human(size_in_bytes)
    return "0 B" if size_in_bytes.nil? || size_in_bytes == 0
    
    units = %w[B KB MB GB TB]
    base = 1024.0
    
    if size_in_bytes < base
      "#{size_in_bytes} B"
    else
      exponent = (Math.log(size_in_bytes) / Math.log(base)).floor
      exponent = [exponent, units.length - 1].min
      
      size = (size_in_bytes / (base ** exponent)).round(1)
      "#{size} #{units[exponent]}"
    end
  end
end
