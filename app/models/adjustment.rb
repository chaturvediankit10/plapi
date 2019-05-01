class Adjustment < ApplicationRecord
  #validates :program_title, presence: true, uniqueness: {message: "already exists"}
  before_create :check_details
  has_many :program_adjustments
  has_many :programs, through: :program_adjustments
  def check_details
  end

  MAIN_KEYS = {
    "All Conforming ARMs (Does not include LP Open Access)" => "Conforming/Term/LTV/FICO",
    "All Fixed Conforming\n(does not apply to terms <=15yrs)" => "Conforming/RateType/Term/LTV/FICO",
    "All Fixed Conforming\n(does not apply to terms <=15yrs with LTV <=95)" => "Conforming/RateType/Term/LTV/FICO",
    "All Conforming\n(does not apply to Fixed terms <=15yrs with LTV <=95)" => "Conforming/RateType/Term/LTV/FICO",
    "Cash-Out" => "RefinanceOption/FICO/LTV",
    "Lender Paid MI Adjustments" => "Term/LTV/FICO",
    "Premium Adjustments" => "LPMI/PremiumType/FICO",
    "LTV Adjustments" => "LPMI/Term/LTV/FICO",
    "Loan Size Adjusters" => "LoanAmount/LoanPurpose",
    "Number Of Units" => "PropertyType/LTV",
    "Subordinate Financing" => "FinancingType/LTV/CLTV/FICO",
    "Misc Adjusters" => "PropertyType/LTV/Term",
    "Non Owner Occupied" => "PropertyType/LTV",
    "Loan Size Adjustments" => "LoanAmount/LoanPurpose",
    "Super Conforming" => "Conforming/LTV/FICO",
    "Super Conforming Adjustments" => "LoanPurpose/RefinanceOption",
    "Subordinate Financing\nExcludes Community Seconds®" => "FinancingType/LTV/CLTV/FICO"
  }

  INPUT_VALUES = [
    "PropertyType",
    "FinancingType",
    "PremiumType",
    "LTV",
    "FICO",
    "RefinanceOption",
    "MiscAdjuster",
    "LPMI",
    "Coverage",
    "LoanAmount",
    "CLTV",
    "InterestRate",
    "LockDay",
    "State",
    "Term",
    "LoanType",
    "ArmBasic",
    "ArmAdvanced",
    "FannieMaeProduct",
    "FreddieMacProduct",
    "LoanPurpose",
    "LoanSize",
    "ProgramCategory",
    "DTI"
  ]
end
