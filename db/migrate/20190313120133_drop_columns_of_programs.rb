class DropColumnsOfPrograms < ActiveRecord::Migration[5.1]
  def change
    remove_column :programs, :jumbo
    remove_column :programs, :high_balance
  end
end
