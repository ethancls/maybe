class AutoImportJob < ApplicationJob
  queue_as :high_priority

  def perform(integration_config, transactions_data, options = {})
    Rails.logger.info "AutoImportJob: Processing #{transactions_data.size} transactions for integration #{integration_config.name}"

    # Create an API import
    import = integration_config.create_api_import(transactions_data, options)

    # Process the import immediately if it's valid
    if import.publishable?
      import.publish
      Rails.logger.info "AutoImportJob: Successfully processed import #{import.id} for integration #{integration_config.name}"
    else
      Rails.logger.warn "AutoImportJob: Import #{import.id} requires manual review for integration #{integration_config.name}"
    end

  rescue => e
    Rails.logger.error "AutoImportJob: Failed to process import for integration #{integration_config.name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Re-raise to ensure Sidekiq marks the job as failed
    raise e
  end
end