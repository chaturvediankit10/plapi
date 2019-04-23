class RemoveInterestPointsToPrograms < ActiveRecord::Migration[5.1]
  def change
  	remove_column :programs, :interest_points, :text
  	add_column :programs, :base_rate, :json
  end
end
