# This migration comes from search_api_engine (originally 20190311131351)
class ChangeJumboToBeBooleanInPrograms < ActiveRecord::Migration[5.2]
  def change
    change_column :programs, :jumbo, :boolean, :default => false
  end
end
