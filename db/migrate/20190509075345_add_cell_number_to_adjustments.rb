class AddCellNumberToAdjustments < ActiveRecord::Migration[5.2]
  def change
    add_column :adjustments, :cell_number, :string
  end
end
