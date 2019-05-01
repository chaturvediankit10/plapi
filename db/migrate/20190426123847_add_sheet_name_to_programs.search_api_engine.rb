# This migration comes from search_api_engine (originally 20181219070637)
class AddSheetNameToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :sheet_name, :string
  end
end
