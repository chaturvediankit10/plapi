class CreateProgramAdjustments < ActiveRecord::Migration[5.2]
  def change
    create_table :program_adjustments do |t|
      t.integer :program_id
      t.integer :adjustment_id
      t.timestamps
    end
  end
end
