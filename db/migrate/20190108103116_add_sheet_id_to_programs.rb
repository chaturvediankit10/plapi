class AddSheetIdToPrograms < ActiveRecord::Migration[5.1]
  def change
    add_column :programs, :sheet_id, :integer
  end
end
