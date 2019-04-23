class SubSheet < ApplicationRecord
  belongs_to :sheet
  has_many :programs


  SUBSHEETS = [
    "FHA STANDARD PROGRAMS",
    "FHA STREAMLINE PROGRAMS",
    "VA STANDARD PROGRAMS",
    "VA STREAMLINE PROGRAMS",
    "CONVENTIONAL FIXED PROGRAMS",
    "CONVENTIONAL ARM PROGRAMS",
    "CONVENTIONAL PRICE ADJUSTMENTS",
    "FREDDIE MAC PROGRAMS",
    "FREDDIE MAC PRICE ADJUSTMENTS",
    "Core Jumbo - Minimum Loan Amount $1.00 above Agency Limit",
    "Choice Advantage Plus", "Choice Advantage",
    "Choice Alternative",
    "Choice Ascent",
    "Choice Investor",
    "Leverage - Prime",
    "Leverage - Lite",
    "Leverage - Investor",
    "Leverage - Investor DSCR",
    "Pivot Prime Jumbo",
    "Pivot Core / Plus"
  ]
end
