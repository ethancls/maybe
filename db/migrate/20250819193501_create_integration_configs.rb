class CreateIntegrationConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :integration_configs, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :app_type, null: false
      t.string :status, default: "active", null: false
      t.string :api_token
      t.json :config, default: {}
      t.text :description
      t.timestamps
    end

    add_index :integration_configs, [:family_id, :name], unique: true
    add_index :integration_configs, :app_type
    add_index :integration_configs, :status
  end
end