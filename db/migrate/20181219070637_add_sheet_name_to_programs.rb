class AddSheetNameToPrograms < ActiveRecord::Migration[5.1]
  def change
    add_column :programs, :sheet_name, :string
  end
end
