# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

	UserInput.find_or_create_by(property_type: ["Manufactured Home", "2nd Home", "3-4 Unit", "Non-Owner Occupied", "Condo", "2-4 Unit", "Investment Property"], financing_type: ["Subordinate Financing"],premium_type: ["Manufactured Home", "2nd Home", "3-4 Unit", "Non-Owner Occupied", "Condo", "2-4 Unit", "Investment Property", "Subordinate Financing"], ltv: ["96-97","91-95","86-90","81-85","76-80","71-75","61-70","0-60"],fico: ["+740", "740-759","720-739","700-719","680-699","660-679","640-659","620-639"],refinance_option: ["Cash Out", "Rate and Term", "IRRRL"],misc_adjuster: ["CA Escrow Waiver (Full or Taxes Only)", "CA Escrow Waiver (Insurance Only)"], lpmi: false,coverage: 30,dti: false, state: "CA")