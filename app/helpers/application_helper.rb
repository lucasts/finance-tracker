module ApplicationHelper
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
