class ProgramAdjustment < ApplicationRecord
	belongs_to :program
	belongs_to :adjustment
	validates :program_id, :uniqueness => { :scope => :adjustment_id }
end
