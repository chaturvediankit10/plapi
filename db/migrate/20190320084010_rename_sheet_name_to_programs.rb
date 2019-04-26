class RenameSheetNameToPrograms < ActiveRecord::Migration[5.2]
  def change
  	rename_column :programs, :sheet_name, :loan_category
  	rename_column :error_logs, :sheet_name, :loan_category
  	rename_column :adjustments, :sheet_name, :loan_category
  end
end
