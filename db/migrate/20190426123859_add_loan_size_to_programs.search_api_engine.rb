# This migration comes from search_api_engine (originally 20190128093423)
class AddLoanSizeToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :loan_size, :string
  end
end
