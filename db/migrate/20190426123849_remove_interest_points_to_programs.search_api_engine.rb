# This migration comes from search_api_engine (originally 20181221132423)
class RemoveInterestPointsToPrograms < ActiveRecord::Migration[5.2]
  def change
  	remove_column :programs, :interest_points, :text
  	add_column :programs, :base_rate, :json
  end
end
