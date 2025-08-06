module ApplicationHelper
  
  # Unified money formatting helper - replaces all number_to_currency calls
  def format_money_unified(amount, options = {})
    return content_tag(:span, 'R$ 0,00', class: 'text-muted') if amount.blank? || amount.zero?
    
    defaults = {
      unit: 'R$ ',
      separator: ',', 
      delimiter: '.',
      precision: 2
    }
    
    formatted = number_to_currency(amount, defaults.merge(options))
    
    # Add semantic CSS classes based on amount
    css_class = case
                when amount > 0 then 'money-positive'
                when amount < 0 then 'money-negative'  
                else 'money-neutral'
                end
                
    content_tag(:span, formatted, class: "money-display #{css_class}")
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
      exponent = [exponent, units.length - 1].min
      
      size = (size_in_bytes / (base ** exponent)).round(1)
      "#{size} #{units[exponent]}"
    end
  end
end
