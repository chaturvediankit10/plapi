class RenameColumnNameToPrograms < ActiveRecord::Migration[5.1]
  def change
  	remove_column :programs, :rate_arm, :integer
  	add_column :programs, :arm_basic, :string
  	add_column :programs, :arm_advanced, :string
  end
end
