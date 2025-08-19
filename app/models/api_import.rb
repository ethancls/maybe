class ApiImport < Import
  # Store metadata about the source application
  store_accessor :config, :source_app_name, :source_app_version, :auth_token_hash

  validates :source_app_name, presence: true

  def import!
    transaction do
      mappings.each(&:create_mappable!)

      transactions = rows.map do |row|
        mapped_account = if account
          account
        else
          mappings.accounts.mappable_for(row.account)
        end

        category = mappings.categories.mappable_for(row.category)
        tags = row.tags_list.map { |tag| mappings.tags.mappable_for(tag) }.compact

        Transaction.new(
          category: category,
          tags: tags,
          entry: Entry.new(
            account: mapped_account,
            date: row.date_iso,
            amount: row.signed_amount,
            name: row.name,
            currency: row.currency,
            notes: row.notes,
            import: self
          )
        )
      end

      Transaction.import!(transactions, recursive: true)
    end
  end

  def required_column_keys
    %i[date amount]
  end

  def column_keys
    base = %i[date amount name currency category tags notes]
    base.unshift(:account) if account.nil?
    base
  end

  def mapping_steps
    base = [ Import::CategoryMapping, Import::TagMapping ]
    base << Import::AccountMapping if account.nil?
    base
  end

  # Override to generate rows from JSON data instead of CSV
  def generate_rows_from_json(transactions_data)
    rows.destroy_all

    mapped_rows = transactions_data.map do |transaction_data|
      {
        account: transaction_data["account_name"].to_s,
        date: transaction_data["date"].to_s,
        amount: transaction_data["amount"].to_s,
        currency: (transaction_data["currency"] || default_currency).to_s,
        name: (transaction_data["description"] || transaction_data["name"] || default_row_name).to_s,
        category: transaction_data["category"].to_s,
        tags: Array(transaction_data["tags"]).join("|"),
        notes: transaction_data["notes"].to_s
      }
    end

    rows.insert_all!(mapped_rows)
  end

  # For API imports, we accept JSON data format
  def accepts_json?
    true
  end

  # Validate the structure of incoming JSON data
  def validate_json_structure(data)
    return { valid: false, errors: ["Data must be an array"] } unless data.is_a?(Array)
    
    errors = []
    data.each_with_index do |transaction, index|
      unless transaction.is_a?(Hash)
        errors << "Transaction at index #{index} must be an object"
        next
      end

      required_fields = %w[date amount]
      required_fields.each do |field|
        unless transaction.key?(field) && transaction[field].present?
          errors << "Transaction at index #{index} missing required field: #{field}"
        end
      end

      # Validate date format
      if transaction["date"].present?
        begin
          Date.parse(transaction["date"])
        rescue ArgumentError
          errors << "Transaction at index #{index} has invalid date format: #{transaction['date']}"
        end
      end

      # Validate amount is numeric
      if transaction["amount"].present?
        unless transaction["amount"].to_s.match?(/\A-?\d+\.?\d*\z/)
          errors << "Transaction at index #{index} has invalid amount format: #{transaction['amount']}"
        end
      end
    end

    { valid: errors.empty?, errors: errors }
  end
end