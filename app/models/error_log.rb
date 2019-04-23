class ErrorLog < ApplicationRecord
  before_create :set_bank_name
  validate :validate_repeated_data
  def set_bank_name
    self.bank_name = Bank.joins(:sheets).where("sheets.name Like ?", self.loan_category).first.name rescue nil
  end

  def validate_repeated_data
    error_logs = self.class.where("loan_category Like ? AND error_detail Like ? AND created_at > ?", self.loan_category, self.error_detail, 24.hours.ago)
    if error_logs.any?
      errors.add(:created_at, 'Record is already exists')
    end
  end
end
