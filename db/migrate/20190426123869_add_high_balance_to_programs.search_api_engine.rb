# This migration comes from search_api_engine (originally 20190311131823)
class AddHighBalanceToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :high_balance, :boolean, default: false
  end
end
