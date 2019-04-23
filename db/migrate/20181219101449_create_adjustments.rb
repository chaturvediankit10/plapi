class CreateAdjustments < ActiveRecord::Migration[5.1]
  def change
    create_table :adjustments do |t|
    	t.json    :data
    	t.string  :program_title
    	t.string  :sheet_name
    	t.integer :program_ids, array: true, default: []
    	t.integer :program_id
      t.timestamps
    end
  end
end