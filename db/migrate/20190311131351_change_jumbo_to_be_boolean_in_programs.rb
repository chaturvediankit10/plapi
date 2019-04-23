class ChangeJumboToBeBooleanInPrograms < ActiveRecord::Migration[5.1]
  def change
    change_column :programs, :jumbo, :boolean, :default => false
  end
end
