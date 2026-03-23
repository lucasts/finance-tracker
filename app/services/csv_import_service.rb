# frozen_string_literal: true

# Service to import and parse CSV files
require "csv"

class CsvImportService
  def self.call(file_content:)
    new(file_content).parse
  end

  # Expected header: date,value,description,category,status,type,installment
  def initialize(file_content)
    @file_content = file_content
  end

  def parse
    return [] if @file_content.to_s.strip.empty?

    sanitized = @file_content.to_s.sub(/\A\xEF\xBB\xBF/, "").strip
    lines = sanitized.lines.reject { |l| l.strip.empty? }

    if headerless_semicolon_format?(lines)
      parse_headerless_semicolon(lines)
    elsif credit_card_csv_format?(lines)
      parse_credit_card_csv(lines)
    else
      parse_standard_csv(lines)
    end
  end

  private

  # Detects credit card CSV exports with "lançamento" header:
  #   data,lançamento,valor
  # Also matches "lancamento" (no cedilla) and "lanamento" (cedilla stripped by
  # binary-to-UTF-8 encoding in the controller).
  def credit_card_csv_format?(lines)
    header = lines.first.to_s.strip.downcase
    header.match?(/\blan[çc]?amento\b/)
  end

  def parse_credit_card_csv(lines)
    content = lines.join
    csv = CSV.parse(content, headers: true, col_sep: ",")

    desc_key = csv.headers.find { |h| h&.match?(/lan[çc]?amento/i) }

    transactions = []
    csv.each_with_index do |row, idx|
      description = row[desc_key]&.strip.presence
      amount = parse_amount(row["valor"])

      # Credit card: positive = expense (charge), negative = payment (credit)
      transaction_type = if amount && amount < 0
        "income"
      else
        "expense"
      end

      transactions << {
        line_number: idx + 1,
        external_id: nil,
        raw_data: row.to_h.to_json,
        description: description,
        amount: amount&.abs,
        event_date: row["data"],
        payment_date: row["data"],
        transaction_type: transaction_type,
        status: "pending",
        parsed_data: row.to_h
      }
    end

    transactions
  end

  # Detects headerless semicolon-delimited bank exports like:
  #   21/11/2025;REND PAGO APLIC AUT MAIS;0,04
  def headerless_semicolon_format?(lines)
    sample = lines.first.to_s.strip
    return false if sample.empty?

    # Must contain semicolons and first field must look like DD/MM/YYYY
    sample.include?(";") && sample.split(";").first.strip.match?(%r{\A\d{2}/\d{2}/\d{4}\z})
  end

  def parse_headerless_semicolon(lines)
    transactions = []

    lines.each_with_index do |line, idx|
      fields = line.strip.split(";", 3)
      next if fields.size < 3

      raw_date = fields[0].strip
      description = fields[1].strip
      raw_amount = fields[2].strip

      amount = parse_amount(raw_amount)
      iso_date = parse_brazilian_date(raw_date)

      transaction_type = if amount && amount < 0
        "expense"
      elsif amount && amount > 0
        "income"
      else
        "expense"
      end

      transactions << {
        line_number: idx + 1,
        external_id: nil,
        raw_data: { data: raw_date, descricao: description, valor: raw_amount }.to_json,
        description: description.presence,
        amount: amount&.abs,
        event_date: iso_date,
        payment_date: iso_date,
        transaction_type: transaction_type,
        status: "pending",
        parsed_data: { "data" => raw_date, "descricao" => description, "valor" => raw_amount }
      }
    end

    transactions
  end

  def parse_brazilian_date(date_str)
    return nil if date_str.nil? || date_str.strip.empty?
    if date_str.match?(%r{\A\d{2}/\d{2}/\d{4}\z})
      day, month, year = date_str.split("/")
      "#{year}-#{month}-#{day}"
    else
      date_str
    end
  end

  def parse_standard_csv(lines)
    content = lines.join

    # Single-line fallback (not standard CSV)
    if lines.size == 1 && lines.first !~ /^data,valor/i && lines.first.count('"') % 2 == 0
      return [ {
        line_number: 1,
        external_id: nil,
        raw_data: content.strip,
        description: nil,
        amount: nil,
        event_date: nil,
        payment_date: nil,
        transaction_type: "expense",
        status: nil,
        parsed_data: {}
      } ]
    end

    csv = CSV.parse(content, headers: true, col_sep: ",")

    # Analyze file patterns to determine normalization strategy
    analysis = analyze_file_patterns(csv)

    transactions = []
    csv.each_with_index do |row, idx|
      valor = row["valor"]
      amount = parse_amount(valor)
      desc = row["descricao"]
      description = desc.nil? || desc.to_s.strip.empty? ? nil : desc

      # Apply normalization based on file analysis
      normalized_data = normalize_transaction_data(row, amount, analysis)

      transactions << {
        line_number: idx + 1,
        external_id: nil,
        raw_data: row.to_h.to_json,
        description: description,
        amount: normalized_data[:amount],
        event_date: row["data"],
        payment_date: row["data"],
        transaction_type: normalized_data[:transaction_type],
        status: row["status"] || "pending",
        parsed_data: row.to_h
      }
    end
    transactions
  end

  private

  def analyze_file_patterns(csv)
    analysis = {
      has_negative_values: false,
      has_type_column: false,
      type_column_name: nil,
      has_populated_type_column: false,
      normalization_strategy: :none
    }

    # Check if there's a type/transaction_type column
    type_columns = [ "tipo", "transaction_type", "type", "natureza", "credito_debito" ]
    analysis[:type_column_name] = type_columns.find { |col| csv.headers&.include?(col) }
    analysis[:has_type_column] = !analysis[:type_column_name].nil?

    # Analyze values to detect negative amounts and populated type columns
    csv.each do |row|
      valor = row["valor"]
      if valor && !valor.to_s.strip.empty?
        amount = parse_amount_for_analysis(valor)
        if amount && amount < 0
          analysis[:has_negative_values] = true
        end
      end

      # Check if type column actually has values
      if analysis[:type_column_name]
        type_value = row[analysis[:type_column_name]]
        if type_value && !type_value.to_s.strip.empty?
          analysis[:has_populated_type_column] = true
        end
      end
    end

    # Determine normalization strategy
    if analysis[:has_negative_values] && !analysis[:has_populated_type_column]
      # Bank uses negative values to indicate expenses (common pattern)
      analysis[:normalization_strategy] = :negative_to_positive_with_type
    elsif analysis[:has_populated_type_column] && !analysis[:has_negative_values]
      # Bank provides type column and all values are positive (ideal pattern)
      analysis[:normalization_strategy] = :use_type_column
    elsif analysis[:has_negative_values] && analysis[:has_populated_type_column]
      # Bank has both negative values AND type column (mixed pattern - prioritize type column)
      analysis[:normalization_strategy] = :use_type_column
    else
      # Default to inferring from amount sign
      analysis[:normalization_strategy] = :negative_to_positive_with_type
    end

    analysis
  end

  def normalize_transaction_data(row, amount, analysis)
    case analysis[:normalization_strategy]
    when :negative_to_positive_with_type
      # Convert negative values to positive and set type based on original sign
      if amount && amount < 0
        { amount: amount.abs, transaction_type: "expense" }
      elsif amount && amount > 0
        { amount: amount, transaction_type: "income" }
      else
        { amount: amount, transaction_type: "expense" }
      end

    when :use_type_column
      # Use type column and keep amount as is (assuming positive)
      type_value = row[analysis[:type_column_name]]
      normalized_type = normalize_type_column_value(type_value)
      { amount: amount&.abs, transaction_type: normalized_type }

    else
      # Default normalization: use amount sign and infer type
      transaction_type = row["tipo"] || infer_type(row)
      if amount && amount < 0
        { amount: amount.abs, transaction_type: "expense" }
      elsif amount && amount > 0
        { amount: amount, transaction_type: transaction_type == "expense" ? "expense" : "income" }
      else
        { amount: amount, transaction_type: transaction_type || "expense" }
      end
    end
  end

  def normalize_type_column_value(type_value)
    return "expense" if type_value.nil? || type_value.to_s.strip.empty?

    type_str = type_value.to_s.downcase.strip

    # Map common type values to standard types
    case type_str
    when "receita", "entrada", "credito", "credit", "income", "c", "+"
      "income"
    when "despesa", "saida", "debito", "debit", "expense", "d", "-"
      "expense"
    when "transferencia", "transfer", "transf"
      "transfer"
    else
      # If it contains positive indicators
      if type_str.include?("receita") || type_str.include?("entrada") || type_str.include?("credit")
        "income"
      # If it contains negative indicators
      elsif type_str.include?("despesa") || type_str.include?("saida") || type_str.include?("debit")
        "expense"
      else
        "expense"
      end
    end
  end

  def parse_amount_for_analysis(valor)
    return nil if valor.nil? || valor.to_s.strip.empty?
    begin
      FinancialConstants.safe_to_decimal(valor)
    rescue ArgumentError, TypeError
      nil
    end
  end

  def parse_amount(valor)
    return nil if valor.nil? || valor.to_s.strip.empty?
    FinancialConstants.safe_to_decimal(valor)
  end

  def infer_type(row)
    v = FinancialConstants.safe_to_float(row["valor"])
    v > 0 ? "income" : "expense"
  end
end
