# frozen_string_literal: true

class Api::V1::ImportsController < Api::V1::BaseController
  # Ensure proper scope authorization for imports
  before_action :ensure_write_scope, only: [ :create ]

  # POST /api/v1/imports
  # Create a new import from external application data
  def create
    family = current_resource_owner.family

    # Validate request parameters
    unless import_params[:source_app_name].present?
      render json: {
        error: "validation_failed",
        message: "Source application name is required",
        errors: [ "source_app_name is required" ]
      }, status: :unprocessable_entity
      return
    end

    unless import_params[:transactions].present?
      render json: {
        error: "validation_failed", 
        message: "Transaction data is required",
        errors: [ "transactions array is required" ]
      }, status: :unprocessable_entity
      return
    end

    # Create the API import
    @import = family.imports.build(
      type: "ApiImport",
      source_app_name: import_params[:source_app_name],
      source_app_version: import_params[:source_app_version],
      account: find_account_if_specified(family)
    )

    # Validate the JSON structure
    validation_result = @import.validate_json_structure(import_params[:transactions])
    unless validation_result[:valid]
      render json: {
        error: "validation_failed",
        message: "Invalid transaction data format",
        errors: validation_result[:errors]
      }, status: :unprocessable_entity
      return
    end

    if @import.save
      # Generate rows from the JSON data
      @import.generate_rows_from_json(import_params[:transactions])
      @import.sync_mappings

      # If auto_import is requested, process immediately
      if import_params[:auto_import] == true
        process_import_async
        render json: {
          id: @import.id,
          status: "processing",
          message: "Import created and processing started",
          transactions_count: @import.rows.count
        }, status: :accepted
      else
        render json: {
          id: @import.id,
          status: "created",
          message: "Import created successfully, awaiting manual confirmation",
          transactions_count: @import.rows.count,
          configuration_url: import_configuration_url(@import)
        }, status: :created
      end
    else
      render json: {
        error: "validation_failed",
        message: "Import could not be created",
        errors: @import.errors.full_messages
      }, status: :unprocessable_entity
    end

  rescue => e
    Rails.logger.error "Api::V1::ImportsController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error processing import: #{e.message}"
    }, status: :internal_server_error
  end

  private

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def import_params
      params.require(:import).permit(
        :source_app_name, :source_app_version, :account_id, :auto_import,
        transactions: [
          :date, :amount, :name, :description, :account_name, :category, 
          :currency, :notes, tags: []
        ]
      )
    end

    def find_account_if_specified(family)
      return nil unless import_params[:account_id].present?
      
      family.accounts.find(import_params[:account_id])
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def process_import_async
      # Queue the import for processing in the background
      ImportJob.perform_later(@import)
    end

    def import_configuration_url(import)
      # Return URL for manual configuration if needed
      # This would be the web UI URL for configuring the import
      Rails.application.routes.url_helpers.import_url(import)
    rescue
      nil
    end
end