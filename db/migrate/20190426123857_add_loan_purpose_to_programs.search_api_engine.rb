# This migration comes from search_api_engine (originally 20190116120636)
class AddLoanPurposeToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :loan_purpose, :string
  end
end
