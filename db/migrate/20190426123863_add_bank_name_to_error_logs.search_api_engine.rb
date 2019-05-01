# This migration comes from search_api_engine (originally 20190301141055)
class AddBankNameToErrorLogs < ActiveRecord::Migration[5.2]
  def change
    add_column :error_logs, :bank_name, :string
  end
end
