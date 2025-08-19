class IntegrationConfig < ApplicationRecord
  belongs_to :family
  
  # Store configuration data as JSON
  store_accessor :config, :webhook_url, :api_endpoint, :auth_method, :credentials

  validates :name, presence: true, uniqueness: { scope: :family_id }
  validates :app_type, presence: true
  validates :status, inclusion: { in: %w[active inactive] }

  enum :status, {
    active: "active",
    inactive: "inactive"
  }, validate: true, default: "active"

  # Common app types for third-party integrations
  APP_TYPES = %w[
    banking
    accounting
    ecommerce
    payment_processor
    expense_tracker
    investment_platform
    custom
  ].freeze

  validates :app_type, inclusion: { in: APP_TYPES }

  scope :active, -> { where(status: :active) }
  scope :by_app_type, ->(type) { where(app_type: type) }

  # Generate a secure API token for this integration
  def generate_api_token!
    self.api_token = SecureRandom.hex(32)
    save!
  end

  # Check if the integration supports webhook notifications
  def supports_webhooks?
    webhook_url.present?
  end

  # Validate the webhook URL if provided
  def validate_webhook_url
    return true unless webhook_url.present?

    begin
      uri = URI.parse(webhook_url)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end
  end

  # Test the webhook connection
  def test_webhook
    return { success: false, error: "No webhook URL configured" } unless supports_webhooks?
    return { success: false, error: "Invalid webhook URL" } unless validate_webhook_url

    begin
      response = HTTParty.post(
        webhook_url,
        body: {
          test: true,
          timestamp: Time.current.iso8601,
          integration_id: id
        }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'X-Integration-Token' => api_token
        },
        timeout: 10
      )

      if response.success?
        { success: true, status_code: response.code }
      else
        { success: false, error: "HTTP #{response.code}", response: response.body }
      end
    rescue => e
      { success: false, error: e.message }
    end
  end

  # Create an API import for this integration
  def create_api_import(transactions_data, options = {})
    family.imports.create!(
      type: "ApiImport",
      source_app_name: name,
      source_app_version: options[:source_version],
      account: options[:account]
    ).tap do |import|
      import.generate_rows_from_json(transactions_data)
      import.sync_mappings
    end
  end
end