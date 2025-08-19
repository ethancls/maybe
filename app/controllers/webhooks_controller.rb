class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_authentication

  def plaid
    webhook_body = request.body.read
    plaid_verification_header = request.headers["Plaid-Verification"]

    client = Provider::Registry.plaid_provider_for_region(:us)

    client.validate_webhook!(plaid_verification_header, webhook_body)

    PlaidItem::WebhookProcessor.new(webhook_body).process

    render json: { received: true }, status: :ok
  rescue => error
    Sentry.capture_exception(error)
    render json: { error: "Invalid webhook: #{error.message}" }, status: :bad_request
  end

  def plaid_eu
    webhook_body = request.body.read
    plaid_verification_header = request.headers["Plaid-Verification"]

    client = Provider::Registry.plaid_provider_for_region(:eu)

    client.validate_webhook!(plaid_verification_header, webhook_body)

    PlaidItem::WebhookProcessor.new(webhook_body).process

    render json: { received: true }, status: :ok
  rescue => error
    Sentry.capture_exception(error)
    render json: { error: "Invalid webhook: #{error.message}" }, status: :bad_request
  end

  def stripe
    stripe_provider = Provider::Registry.get_provider(:stripe)

    begin
      webhook_body = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

      stripe_provider.process_webhook_later(webhook_body, sig_header)

      head :ok
    rescue JSON::ParserError => error
      Sentry.capture_exception(error)
      Rails.logger.error "JSON parser error: #{error.message}"
      head :bad_request
    rescue Stripe::SignatureVerificationError => error
      Sentry.capture_exception(error)
      Rails.logger.error "Stripe signature verification error: #{error.message}"
      head :bad_request
    end
  end

  # POST /webhooks/integration_import
  def integration_import
    # Verify the webhook token
    integration_config = find_integration_by_token
    
    unless integration_config
      render json: { error: "unauthorized", message: "Invalid webhook token" }, status: :unauthorized
      return
    end

    # Parse webhook payload
    payload = parse_webhook_payload

    # Validate required fields
    unless payload[:transactions].present?
      render json: { error: "bad_request", message: "Missing transactions data" }, status: :bad_request
      return
    end

    # Queue the import for background processing
    AutoImportJob.perform_later(
      integration_config,
      payload[:transactions],
      {
        source_version: payload[:source_version],
        account: find_account_by_name(integration_config.family, payload[:account_name])
      }
    )

    render json: {
      status: "accepted",
      message: "Webhook received, import queued for processing",
      transactions_count: payload[:transactions].size
    }, status: :accepted

  rescue JSON::ParserError
    render json: { error: "bad_request", message: "Invalid JSON payload" }, status: :bad_request
  rescue => e
    Rails.logger.error "WebhooksController#integration_import error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error processing webhook"
    }, status: :internal_server_error
  end

  private

    def find_integration_by_token
      token = request.headers["X-Integration-Token"] || params[:token]
      return nil unless token.present?

      IntegrationConfig.active.find_by(api_token: token)
    end

    def parse_webhook_payload
      if request.content_type&.include?("application/json")
        JSON.parse(request.body.read).with_indifferent_access
      else
        params.except(:controller, :action, :token).with_indifferent_access
      end
    end

    def find_account_by_name(family, account_name)
      return nil unless account_name.present?
      
      family.accounts.find_by(name: account_name)
    end
end
