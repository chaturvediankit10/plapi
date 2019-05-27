class RemoveCellNumberToAdjustments < ActiveRecord::Migration[5.2]
  def change
  	remove_column :adjustments, :cell_number
  end
end