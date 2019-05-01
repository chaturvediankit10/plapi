# This migration comes from search_api_engine (originally 20190110073034)
class AddDefaultFalseToProgramsAttribute < ActiveRecord::Migration[5.2]
  def up
  change_column :programs, :jumbo_high_balance, :boolean, default: false
  change_column :programs, :conforming, :boolean, default: false
  change_column :programs, :fannie_mae, :boolean, default: false
  change_column :programs, :fannie_mae_home_ready, :boolean, default: false
  change_column :programs, :freddie_mac, :boolean, default: false
  change_column :programs, :freddie_mac_home_possible, :boolean, default: false
  change_column :programs, :fha, :boolean, default: false
  change_column :programs, :va, :boolean, default: false
  change_column :programs, :usda, :boolean, default: false
  change_column :programs, :streamline, :boolean, default: false
  change_column :programs, :full_doc, :boolean, default: false
end
end
