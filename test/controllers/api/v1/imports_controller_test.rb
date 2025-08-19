require "test_helper"

class Api::V1::ImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:family_admin)
    @family = @user.family
    @api_key = api_keys(:write_all)
    @headers = { "X-Api-Key" => @api_key.value }
  end

  test "POST /api/v1/imports creates a new API import" do
    import_data = {
      source_app_name: "Test App",
      source_app_version: "1.0.0",
      transactions: [
        {
          date: "2024-08-19",
          amount: "-45.99",
          description: "Test Transaction",
          category: "Food",
          currency: "USD"
        }
      ]
    }

    assert_difference("Import.count", 1) do
      post "/api/v1/imports", 
        params: { import: import_data },
        headers: @headers,
        as: :json
    end

    assert_response :created
    
    response_data = JSON.parse(response.body)
    assert_equal "created", response_data["status"]
    assert_equal 1, response_data["transactions_count"]
    assert response_data["id"].present?

    import = Import.find(response_data["id"])
    assert_equal "ApiImport", import.type
    assert_equal "Test App", import.source_app_name
    assert_equal 1, import.rows.count
  end

  test "POST /api/v1/imports with auto_import processes immediately" do
    import_data = {
      source_app_name: "Test App",
      auto_import: true,
      transactions: [
        {
          date: "2024-08-19",
          amount: "-45.99",
          description: "Test Transaction"
        }
      ]
    }

    assert_enqueued_with(job: ImportJob) do
      post "/api/v1/imports",
        params: { import: import_data },
        headers: @headers,
        as: :json
    end

    assert_response :accepted
    
    response_data = JSON.parse(response.body)
    assert_equal "processing", response_data["status"]
  end

  test "POST /api/v1/imports validates required fields" do
    import_data = {
      # missing source_app_name
      transactions: []
    }

    post "/api/v1/imports",
      params: { import: import_data },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_equal "validation_failed", response_data["error"]
    assert_includes response_data["errors"], "source_app_name is required"
  end

  test "POST /api/v1/imports validates transaction data format" do
    import_data = {
      source_app_name: "Test App",
      transactions: [
        {
          # missing required date field
          amount: "-45.99"
        }
      ]
    }

    post "/api/v1/imports",
      params: { import: import_data },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_equal "validation_failed", response_data["error"]
    assert_includes response_data["errors"].first, "missing required field: date"
  end

  test "POST /api/v1/imports requires write scope" do
    read_only_api_key = api_keys(:read_only)
    headers = { "X-Api-Key" => read_only_api_key.value }

    import_data = {
      source_app_name: "Test App", 
      transactions: []
    }

    post "/api/v1/imports",
      params: { import: import_data },
      headers: headers,
      as: :json

    assert_response :forbidden
    
    response_data = JSON.parse(response.body)
    assert_equal "insufficient_scope", response_data["error"]
  end

  test "POST /api/v1/imports requires authentication" do
    import_data = {
      source_app_name: "Test App",
      transactions: []
    }

    post "/api/v1/imports",
      params: { import: import_data },
      as: :json

    assert_response :unauthorized
  end
end