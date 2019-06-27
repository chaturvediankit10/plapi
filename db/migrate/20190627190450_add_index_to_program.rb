class AddIndexToProgram < ActiveRecord::Migration[5.2]
  def change
  	add_index(:programs, :bank_name)
	  add_index(:programs, :loan_category)
	  add_index(:programs, :program_category)
	  add_index(:programs, [:loan_purpose, :loan_type, :term])
	  add_index(:programs, [:loan_purpose, :loan_type, :arm_basic])
  end
end
