class RenameAdjustmentColumnInProgram < ActiveRecord::Migration[5.1]
  def change
  	rename_column :programs, :adjustments, :adjustment_ids
  	add_column :programs, :arm_caps, :string
  	rename_column :programs, :du, :fannie_mae_du
  	rename_column :programs, :lp, :freddie_mac_lp
  end
end
