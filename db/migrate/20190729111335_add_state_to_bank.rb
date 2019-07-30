class AddStateToBank < ActiveRecord::Migration[5.2]
  def change
    add_column :banks, :state, :string, array: true, default: []
  end
end
