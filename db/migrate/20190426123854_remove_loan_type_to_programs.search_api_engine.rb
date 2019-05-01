# This migration comes from search_api_engine (originally 20190108104919)
class RemoveLoanTypeToPrograms < ActiveRecord::Migration[5.2]
  def change
  	remove_column :programs, :loan_type, :integer
  	add_column :programs, :loan_type, :string
  end
end
