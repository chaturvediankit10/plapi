class RenameJumboHighBalanceColumnOfPrograms < ActiveRecord::Migration[5.1]
  def change
    rename_column :programs, :jumbo_high_balance, :jumbo
  end
end
