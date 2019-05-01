# This migration comes from search_api_engine (originally 20181206094852)
class CreateBanks < ActiveRecord::Migration[5.2]
  def change
    create_table :banks do |t|
      t.string :name
      t.integer :nmls
      t.string :phone
      t.string :address1
      t.string :address2
      t.string :city
      t.string :state_code
      t.string :zip
      t.string :state_eligibility
      t.timestamps
    end
  end
end