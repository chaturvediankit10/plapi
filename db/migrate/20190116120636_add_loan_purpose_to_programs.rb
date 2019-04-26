class AddLoanPurposeToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :loan_purpose, :string
  end
end
