class AddArmBenchmarkToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :arm_benchmark, :string
    add_column :programs, :arm_margin, :float
  end
end
