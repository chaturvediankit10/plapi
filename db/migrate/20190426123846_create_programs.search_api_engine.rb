# This migration comes from search_api_engine (originally 20181206095711)
class CreatePrograms < ActiveRecord::Migration[5.2]
  def change
    create_table :programs do |t|
      t.integer :bank_id
      t.string :title
      t.integer :loan_type
      t.integer :term
      t.integer :interest_type
      t.integer :interest_subtype
      t.boolean :jumbo_high_balance
      t.boolean :conforming
      t.boolean :fannie_mae
      t.boolean :fannie_mae_home_ready
      t.boolean :freddie_mac
      t.boolean :freddie_mac_home_possible
      t.boolean :fha
      t.boolean :va
      t.boolean :usda
      t.boolean :streamline
      t.boolean :full_doc
      t.text :interest_points
      t.text :adjustments
      t.timestamps
    end
  end
end