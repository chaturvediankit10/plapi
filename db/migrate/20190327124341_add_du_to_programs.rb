class AddDuToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :du, :boolean
    add_column :programs, :lp, :boolean
  end
end
