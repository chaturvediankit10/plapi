class RateSheetExtractor::ObAccMortgage9933Controller < RateSheetExtractor::ApplicationController
  before_action :get_sheet, only: [:programs, :rates]
  before_action :get_program, only: [:single_program]
  before_action :read_sheet, only: [:index,:rates]

  def index
    begin
      @xlsx.sheets.each do |sheet|
        if (sheet == "Rates")
          @name = "ACC Mortgage"
          @bank = Bank.find_or_create_by(name: @name)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
      end
    rescue
    end
  end

  def rates
    @xlsx.sheets.each do |sheet|
      if (sheet == "Rates")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        # programs
      end
    end
    redirect_to programs_florida_capital_web5203_path(@sheet_obj)
  end

  def programs
    @programs = @sheet_obj.programs
  end

  def single_program
  end

  def get_program
    @program = Program.find(params[:id])
  end
  private

  def get_sheet
    @sheet_obj = Sheet.find(params[:id])
  end

  def read_sheet
  	file = File.join(Rails.root + "other_sheets", 'OB_ACC_Mortgage9933.xls')
    @xlsx = Roo::Spreadsheet.open(file)
  end
end
