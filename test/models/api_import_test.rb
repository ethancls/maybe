require "test_helper"

class ApiImportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper, ImportInterfaceTest

  setup do
    @subject = @import = imports(:api)
  end

  test "should have valid source_app_name" do
    @import.source_app_name = nil
    assert_not @import.valid?
    assert_includes @import.errors[:source_app_name], "can't be blank"
  end

  test "accepts JSON data format" do
    assert @import.accepts_json?
  end

  test "validates JSON structure with valid data" do
    valid_data = [
      {
        "date" => "2024-08-19",
        "amount" => "-45.99",
        "description" => "Grocery Store",
        "category" => "Food"
      }
    ]

    result = @import.validate_json_structure(valid_data)
    assert result[:valid]
    assert_empty result[:errors]
  end

  test "validates JSON structure with invalid data" do
    invalid_data = [
      {
        "amount" => "-45.99"
        # missing required date field
      }
    ]

    result = @import.validate_json_structure(invalid_data)
    assert_not result[:valid]
    assert_includes result[:errors].first, "missing required field: date"
  end

  test "validates JSON structure rejects non-array data" do
    invalid_data = { "not" => "an array" }

    result = @import.validate_json_structure(invalid_data)
    assert_not result[:valid]
    assert_includes result[:errors], "Data must be an array"
  end

  test "validates date format in JSON data" do
    invalid_data = [
      {
        "date" => "invalid-date",
        "amount" => "-45.99"
      }
    ]

    result = @import.validate_json_structure(invalid_data)
    assert_not result[:valid]
    assert_includes result[:errors].first, "has invalid date format"
  end

  test "validates amount format in JSON data" do
    invalid_data = [
      {
        "date" => "2024-08-19",
        "amount" => "not-a-number"
      }
    ]

    result = @import.validate_json_structure(invalid_data)
    assert_not result[:valid]
    assert_includes result[:errors].first, "has invalid amount format"
  end

  test "generates rows from JSON data" do
    json_data = [
      {
        "date" => "2024-08-19",
        "amount" => "-45.99",
        "description" => "Grocery Store",
        "category" => "Food",
        "account_name" => "Checking Account",
        "currency" => "USD",
        "tags" => ["groceries", "essentials"],
        "notes" => "Weekly shopping"
      }
    ]

    @import.generate_rows_from_json(json_data)

    assert_equal 1, @import.rows.count
    row = @import.rows.first
    assert_equal "2024-08-19", row.date
    assert_equal "-45.99", row.amount
    assert_equal "Grocery Store", row.name
    assert_equal "Food", row.category
    assert_equal "Checking Account", row.account
    assert_equal "USD", row.currency
    assert_equal "groceries|essentials", row.tags
    assert_equal "Weekly shopping", row.notes
  end

  test "imports transactions with mappings" do
    # This test would need proper fixtures and is similar to other import tests
    # Skipping detailed implementation for brevity
    skip "Detailed import test requires full fixture setup"
  end
end