class DropProgramAdjustments < ActiveRecord::Migration[5.2]
  def change
  	drop_table :program_adjustments
  	remove_column :adjustments, :program_ids
  	remove_column :adjustments, :program_id
  end
end
