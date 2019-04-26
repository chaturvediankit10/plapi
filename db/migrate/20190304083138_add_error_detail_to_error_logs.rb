class AddErrorDetailToErrorLogs < ActiveRecord::Migration[5.2]
  def change
    add_column :error_logs, :error_detail, :text
  end
end
