# This migration comes from search_api_engine (originally 20190311130644)
class RenameJumboHighBalanceColumnOfPrograms < ActiveRecord::Migration[5.2]
  def change
    rename_column :programs, :jumbo_high_balance, :jumbo
  end
end
