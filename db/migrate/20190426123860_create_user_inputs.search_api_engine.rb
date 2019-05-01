# This migration comes from search_api_engine (originally 20190204124401)
class CreateUserInputs < ActiveRecord::Migration[5.2]
  def change
    create_table :user_inputs do |t|
      t.text :property_type, array: true, default: []
      t.text :financing_type, array: true, default: []
      t.text :premium_type, array: true, default: []
      t.string :ltv, array: true, default: []
      t.string :fico, array: true, default: []
      t.text :refinance_option, array: true, default: []
      t.text :misc_adjuster, array: true, default: []
      t.boolean :lpmi
      t.integer :coverage
      t.integer :loan_amount 
      t.string :cltv
      t.boolean :dti
      t.float :interest_rate
      t.integer :lock_period
      t.string :state

      t.timestamps
    end
  end
end

