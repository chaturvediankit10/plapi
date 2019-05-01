# This migration comes from search_api_engine (originally 20190327124341)
class AddDuToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :du, :boolean
    add_column :programs, :lp, :boolean
  end
end
