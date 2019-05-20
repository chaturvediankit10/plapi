class RenameAdjustmentColumnInProgram < ActiveRecord::Migration[5.1]
  def change
  	rename_column :programs, :adjustments, :adjustment_ids
  	# rename_column :programs, :du, :fannie_mae_du
  	# rename_column :programs, :lp, :freddie_mac_lp
  	# add_column :programs, :arm_caps, :string
  end
end
