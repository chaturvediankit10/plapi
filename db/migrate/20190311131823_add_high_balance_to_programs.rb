class AddHighBalanceToPrograms < ActiveRecord::Migration[5.1]
  def change
    add_column :programs, :high_balance, :boolean, default: false
  end
end
