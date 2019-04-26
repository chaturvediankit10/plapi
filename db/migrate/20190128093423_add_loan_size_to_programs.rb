class AddLoanSizeToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :loan_size, :string
  end
end
