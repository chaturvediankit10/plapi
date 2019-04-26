class RemoveLoanTypeToPrograms < ActiveRecord::Migration[5.2]
  def change
  	remove_column :programs, :loan_type, :integer
  	add_column :programs, :loan_type, :string
  end
end
