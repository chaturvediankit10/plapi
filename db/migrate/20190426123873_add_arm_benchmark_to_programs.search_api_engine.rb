# This migration comes from search_api_engine (originally 20190409094748)
class AddArmBenchmarkToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :arm_benchmark, :string
    add_column :programs, :arm_margin, :float
  end
end
