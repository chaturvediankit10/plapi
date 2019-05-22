class RenameAdjustmentColumnInProgram < ActiveRecord::Migration[5.1]
  def change
  	rename_column :programs, :adjustments, :adjustment_ids
  	add_column :programs, :arm_caps, :string
  end
end
