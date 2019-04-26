class CreateSubSheets < ActiveRecord::Migration[5.2]
  def change
    create_table :sub_sheets do |t|
      t.string :name
      t.integer :sheet_id
      t.timestamps
    end
  end
end
