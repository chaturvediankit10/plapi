# This migration comes from search_api_engine (originally 20190205080327)
class AddFannieMaeProductToPrograms < ActiveRecord::Migration[5.2]
  def change
    add_column :programs, :fannie_mae_product, :string
    add_column :programs, :freddie_mac_product, :string
  end
end
