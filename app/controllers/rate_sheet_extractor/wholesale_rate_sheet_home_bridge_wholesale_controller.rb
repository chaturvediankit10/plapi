class RateSheetExtractor::WholesaleRateSheetHomeBridgeWholesaleController < RateSheetExtractor::ApplicationController
	include Wholesale
	before_action :get_sheet, only: [:conventional_fixed_rate_products, :programs, :program_property,:conventional_arm_products, :government_products, :high_ltv_refinance,:jumbo_products,:jumbo_flex_product,:elite_plus_programs,:expanded_plus_programs,:simple_access_programs]
  before_action :get_program, only: [:single_program, :program_property]
  before_action :read_sheet, only: [:index,:conventional_fixed_rate_products,:programs,:conventional_arm_products,:government_products, :high_ltv_refinance,:jumbo_products,:jumbo_flex_product,:elite_plus_programs,:expanded_plus_programs,:simple_access_programs]

  def index
  	sub_sheet_names = get_sheets_names
    begin
      @xlsx.sheets.each do |sheet|
        if (sheet == "Rate Sheet")
          headers = ["Phone", "General Contacts", "Mortgagee Clause (Wholesale)"]
          @name = "HomeBridge Wholesale"
          @bank = Bank.find_or_create_by(name: @name)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
        sub_sheet_names.each do |sub_sheet|
          @sub_sheet = @sheet.sub_sheets.find_or_create_by(name: sub_sheet)
        end
      end
    rescue
      # the required headers are not all present
    end
  end

  def conventional_fixed_rate_products
  	@programs_ids = []
 		@xlsx.sheets.each do |sheet|
      if (sheet == "Rate Sheet")
      	start_range = 38
      	end_range = 	88
      	count1 = 1
      	count2 = 3
      	num1 = 5
      	num2 = 2
      	cl1 = 38
      	cl2 = 56
      	cl3 = 58
      	cl4 = 75
      	cl5 = 76
      	cl6 = 88
      	make_program start_range, end_range, count1, count2, num1, num2, cl1, cl2, cl3, cl4, cl5, cl6
      end
    end
    redirect_to programs_wholesale_rate_sheet_home_bridge_wholesale_path(@sheet_obj)
  end

  def conventional_arm_products
  	@programs_ids = []
 		@xlsx.sheets.each do |sheet|
      if (sheet == "Rate Sheet")
      	start_range = 139
      	end_range = 	167
      	count1 = 1
      	count2 = 3
      	num1 = 5
      	num2 = 2
      	cl1 = 0
      	cl2 = 0
      	cl3 = 0
      	cl4 = 0
      	cl5 = 0
      	cl6 = 0
      	make_program start_range, end_range, count1, count2, num1, num2, cl1, cl2, cl3, cl4, cl5, cl6
      end
    end
    redirect_to programs_wholesale_rate_sheet_home_bridge_wholesale_path(@sheet_obj)
  end

  def government_products
  	@programs_ids = []
 		@xlsx.sheets.each do |sheet|
      if (sheet == "Rate Sheet")
      	start_range = 224
      	end_range = 	292
      	count1 = 1
      	count2 = 3
      	num1 = 5
      	num2 = 2
      	cl1 = 0
      	cl2 = 0
      	cl3 = 0
      	cl4 = 0
      	cl5 = 0
      	cl6 = 0
      	make_program start_range, end_range, count1, count2, num1, num2, cl1, cl2, cl3, cl4, cl5, cl6
      end
    end
    redirect_to programs_wholesale_rate_sheet_home_bridge_wholesale_path(@sheet_obj)
  end

  def high_ltv_refinance
  	@programs_ids = []
 		@xlsx.sheets.each do |sheet|
      if (sheet == "Rate Sheet")
      	start_range = 326
      	end_range = 	354
      	count1 = 1
      	count2 = 3
      	num1 = 5
      	num2 = 2
      	cl1 = 0
      	cl2 = 0
      	cl3 = 0
      	cl4 = 0
      	cl5 = 0
      	cl6 = 0
      	make_program start_range, end_range, count1, count2, num1, num2, cl1, cl2, cl3, cl4, cl5, cl6
      end
    end
    redirect_to programs_wholesale_rate_sheet_home_bridge_wholesale_path(@sheet_obj)
  end

  def jumbo_products
  	@programs_ids = []
 		@xlsx.sheets.each do |sheet|
      if (sheet == "Rate Sheet")
      	start_range = 404
      	end_range = 	432
      	count1 = 1
      	count2 = 3
      	num1 = 5
      	num2 = 2
      	cl1 = 0
      	cl2 = 0
      	cl3 = 0
      	cl4 = 0
      	cl5 = 0
      	cl6 = 0
      	make_program start_range, end_range, count1, count2, num1, num2, cl1, cl2, cl3, cl4, cl5, cl6
      end
    end
    redirect_to programs_wholesale_rate_sheet_home_bridge_wholesale_path(@sheet_obj)
  end

  def jumbo_flex_product
  	@programs_ids = []
 		@xlsx.sheets.each do |sheet|
      if (sheet == "Rate Sheet")
      	start_range = 481
      	end_range = 	514
      	count1 = 1
      	count2 = 3
      	num1 = 5
      	num2 = 2
      	cl1 = 404
      	cl2 = 416
      	cl3 = 420
      	cl4 = 432
      	cl5 = 0
      	cl6 = 0
      	make_program start_range, end_range, count1, count2, num1, num2, cl1, cl2, cl3, cl4, cl5, cl6
      end
    end
    redirect_to programs_wholesale_rate_sheet_home_bridge_wholesale_path(@sheet_obj)
  end

  def elite_plus_programs
  	@programs_ids = []
 		@xlsx.sheets.each do |sheet|
      if (sheet == "Rate Sheet")
      	start_range = 559
      	end_range = 	576
      	count1 = 1
      	count2 = 3
      	num1 = 5
      	num2 = 2
      	cl1 = 0
      	cl2 = 0
      	cl3 = 0
      	cl4 = 0
      	cl5 = 0
      	cl6 = 0
      	make_program start_range, end_range, count1, count2, num1, num2, cl1, cl2, cl3, cl4, cl5, cl6
      end
    end
    redirect_to programs_wholesale_rate_sheet_home_bridge_wholesale_path(@sheet_obj)
  end

  def expanded_plus_programs
  	@programs_ids = []
 		@xlsx.sheets.each do |sheet|
      if (sheet == "Rate Sheet")
      	start_range = 612
      	end_range = 	629
      	count1 = 1
      	count2 = 2
      	num1 = 0
      	num2 = 2
      	cl1 = 0
      	cl2 = 0
      	cl3 = 0
      	cl4 = 0
      	cl5 = 0
      	cl6 = 0
      	make_program start_range, end_range, count1, count2, num1, num2, cl1, cl2, cl3, cl4, cl5, cl6
      end
    end
    redirect_to programs_wholesale_rate_sheet_home_bridge_wholesale_path(@sheet_obj)
  end

  # def simple_access_programs
  # 	@programs_ids = []
 	# 	@xlsx.sheets.each do |sheet|
  #     if (sheet == "Rate Sheet")
  #     	start_range = 224
  #     	end_range = 	292
  #     	count1 = 1
  #     	count2 = 3
  #     	num1 = 5
  #     	num2 = 2
  #     	cl1 = 0
  #     	cl2 = 0
  #     	cl3 = 0
  #     	cl4 = 0
  #     	cl5 = 0
  #     	cl6 = 0
  #     	make_program start_range, end_range, count1, count2, num1, num2, cl1, cl2, cl3, cl4, cl5, cl6
  #     end
  #   end
  #   redirect_to programs_wholesale_rate_sheet_home_bridge_wholesale_path(@sheet_obj)
  # end

  def programs
    @programs = @sheet_obj.programs
  end

  def single_program
  end

  private

  def get_sheets_names
    return ["CONVENTIONAL FIXED RATE PRODUCTS", "CONVENTIONAL ARM PRODUCTS", "GOVERNMENT PRODUCTS", "HIGH LTV REFINANCE", "JUMBO PRODUCTS", "JUMBO FLEX PRODUCT", "ELITE PLUS PROGRAMS", "EXPANDED PLUS PROGRAMS", "SIMPLE ACCESS PROGRAMS"]
  end

  def get_sheet
    @sheet_obj = SubSheet.find(params[:id])
  end

  def read_sheet
  	file = File.join(Rails.root + "other_sheets", 'Wholesale Rate Sheet _HomeBridge Wholesale_.xls')
    @xlsx = Roo::Spreadsheet.open(file)
  end

  def get_program
    @program = Program.find(params[:id])
  end
end
