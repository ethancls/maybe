class AddConfigToImports < ActiveRecord::Migration[8.0]
  def change
    add_column :imports, :config, :json, default: {}
  end
end