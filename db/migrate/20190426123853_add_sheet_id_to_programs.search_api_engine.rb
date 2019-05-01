# This migration comes from search_api_engine (originally 20190108103116)
class AddSheetIdToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :sheet_id, :integer
  end
end
