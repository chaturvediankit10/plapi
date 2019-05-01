# This migration comes from search_api_engine (originally 20190109115312)
class AddLockPeriodToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :lock_period, :integer, array: true, default: []
    add_column :programs, :loan_limit_type, :string, array: true, default: []
  end
end
