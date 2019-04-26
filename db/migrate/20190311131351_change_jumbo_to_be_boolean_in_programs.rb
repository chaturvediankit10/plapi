class ChangeJumboToBeBooleanInPrograms < ActiveRecord::Migration[5.2]
  def change
    change_column :programs, :jumbo, :boolean, :default => false
  end
end
