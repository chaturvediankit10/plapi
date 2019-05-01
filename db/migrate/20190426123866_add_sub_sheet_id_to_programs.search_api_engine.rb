# This migration comes from search_api_engine (originally 20190306120308)
class AddSubSheetIdToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :sub_sheet_id, :integer
  end
end
