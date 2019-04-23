class Sheet < ApplicationRecord
  belongs_to :bank
  has_many :programs
  has_many :sub_sheets
end
