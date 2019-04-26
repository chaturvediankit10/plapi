class AddBankNameToErrorLogs < ActiveRecord::Migration[5.2]
  def change
    add_column :error_logs, :bank_name, :string
  end
end
