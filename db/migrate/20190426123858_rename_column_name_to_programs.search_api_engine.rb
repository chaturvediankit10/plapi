# This migration comes from search_api_engine (originally 20190121105544)
class RenameColumnNameToPrograms < ActiveRecord::Migration[5.2]
  def change
  	remove_column :programs, :rate_arm, :integer
  	add_column :programs, :arm_basic, :string
  	add_column :programs, :arm_advanced, :string
  end
end
