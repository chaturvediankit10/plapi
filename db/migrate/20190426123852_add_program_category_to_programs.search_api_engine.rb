# This migration comes from search_api_engine (originally 20190108081552)
class AddProgramCategoryToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :program_category, :string
    add_column :programs, :bank_name, :string
    remove_column :programs, :title, :string
  	add_column :programs, :program_name, :string
  	remove_column :programs, :interest_type, :string
  	add_column :programs, :rate_type, :string
  	remove_column :programs, :interest_subtype, :integer
  	add_column :programs, :rate_arm, :integer
  end
end
