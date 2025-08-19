require "test_helper"

class IntegrationConfigTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @integration = IntegrationConfig.new(
      family: @family,
      name: "Test Banking App",
      app_type: "banking",
      description: "Test integration for banking data"
    )
  end

  test "should be valid with required attributes" do
    assert @integration.valid?
  end

  test "should require name" do
    @integration.name = nil
    assert_not @integration.valid?
    assert_includes @integration.errors[:name], "can't be blank"
  end

  test "should require app_type" do
    @integration.app_type = nil
    assert_not @integration.valid?
    assert_includes @integration.errors[:app_type], "can't be blank"
  end

  test "should validate app_type inclusion" do
    @integration.app_type = "invalid_type"
    assert_not @integration.valid?
    assert_includes @integration.errors[:app_type], "is not included in the list"
  end

  test "should require unique name per family" do
    @integration.save!
    
    duplicate = IntegrationConfig.new(
      family: @family,
      name: "Test Banking App",
      app_type: "accounting"
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow same name in different families" do
    @integration.save!
    
    other_family = families(:melanie_family)
    other_integration = IntegrationConfig.new(
      family: other_family,
      name: "Test Banking App",
      app_type: "banking"
    )
    
    assert other_integration.valid?
  end

  test "should generate API token" do
    @integration.save!
    assert_nil @integration.api_token
    
    @integration.generate_api_token!
    assert_not_nil @integration.api_token
    assert_equal 64, @integration.api_token.length # 32 bytes as hex = 64 chars
  end

  test "should detect webhook support" do
    assert_not @integration.supports_webhooks?
    
    @integration.webhook_url = "https://example.com/webhook"
    assert @integration.supports_webhooks?
  end

  test "should validate webhook URL format" do
    @integration.webhook_url = "invalid-url"
    assert_not @integration.validate_webhook_url
    
    @integration.webhook_url = "https://example.com/webhook"
    assert @integration.validate_webhook_url
    
    @integration.webhook_url = "http://example.com/webhook"
    assert @integration.validate_webhook_url
  end

  test "should default to active status" do
    assert_equal "active", @integration.status
  end

  test "should scope by status" do
    @integration.save!
    inactive_integration = IntegrationConfig.create!(
      family: @family,
      name: "Inactive App",
      app_type: "accounting",
      status: "inactive"
    )
    
    active_configs = IntegrationConfig.active
    assert_includes active_configs, @integration
    assert_not_includes active_configs, inactive_integration
  end

  test "should scope by app_type" do
    @integration.save!
    accounting_integration = IntegrationConfig.create!(
      family: @family,
      name: "Accounting App",
      app_type: "accounting"
    )
    
    banking_configs = IntegrationConfig.by_app_type("banking")
    assert_includes banking_configs, @integration
    assert_not_includes banking_configs, accounting_integration
  end

  test "should create API import" do
    @integration.save!
    
    transactions_data = [
      {
        "date" => "2024-08-19",
        "amount" => "-45.99",
        "description" => "Test Transaction"
      }
    ]
    
    import = @integration.create_api_import(transactions_data)
    
    assert_equal "ApiImport", import.type
    assert_equal @integration.name, import.source_app_name
    assert_equal @family, import.family
    assert_equal 1, import.rows.count
  end
end