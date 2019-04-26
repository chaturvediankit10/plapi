class AddLockPeriodToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :lock_period, :integer, array: true, default: []
    add_column :programs, :loan_limit_type, :string, array: true, default: []
  end
end
