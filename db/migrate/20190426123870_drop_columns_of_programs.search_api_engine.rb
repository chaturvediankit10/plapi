# This migration comes from search_api_engine (originally 20190313120133)
class DropColumnsOfPrograms < ActiveRecord::Migration[5.2]
  def change
    remove_column :programs, :jumbo
    remove_column :programs, :high_balance
  end
end
