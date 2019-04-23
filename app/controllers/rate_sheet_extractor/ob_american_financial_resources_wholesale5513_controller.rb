class RateSheetExtractor::ObAmericanFinancialResourcesWholesale5513Controller < RateSheetExtractor::ApplicationController
  before_action :get_sheet, only: [:programs, :gnma, :gnma_hb, :fnma, :fhlmc, :hp, :jumbo]
  before_action :read_sheet, only: [:index, :gnma, :gnma_hb, :fnma, :fhlmc, :hp, :jumbo]
  before_action :get_program, only: [:single_program]

  def index
    file = File.join(Rails.root, 'OB_American_Financial_Resources_Wholesale5513.xls')
    xlsx = Roo::Spreadsheet.open(file)
    begin
      xlsx.sheets.each do |sheet|
        if (sheet == "GNMA")
          headers = ["Phone", "General Contacts", "Mortgagee Clause (Wholesale)"]
          @name = "American Financial Resource"
          @bank = Bank.find_or_create_by(name: @name)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
      end
    rescue
      # the required headers are not all present
    end
  end

  # #multiple program with same name issue
  def gnma
    @xlsx.sheets.each do |sheet|
      if (sheet == "GNMA")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 10
        end_range = 53
        row_count = 19
        column_count = 3
        num1 = 4
        num2 = 1
        inc_row = 1
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_american_financial_resources_wholesale5513_path(@sheet_obj)
  end

  def gnma_hb
    @xlsx.sheets.each do |sheet|
      if (sheet == "GNMA HB")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 10
        end_range = 30
        row_count = 20
        column_count = 3
        num1 = 4
        num2 = 1
        inc_row = 1
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_american_financial_resources_wholesale5513_path(@sheet_obj)
  end

  def fnma
    @xlsx.sheets.each do |sheet|
      if (sheet == "FNMA")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 10
        end_range = 72
        row_count = 19
        column_count = 3
        num1 = 4
        num2 = 1
        inc_row = 1
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_american_financial_resources_wholesale5513_path(@sheet_obj)
  end

  def fhlmc
    @xlsx.sheets.each do |sheet|
      if (sheet == "FHLMC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 10
        end_range = 72
        row_count = 19
        column_count = 3
        num1 = 4
        num2 = 1
        inc_row = 1
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_american_financial_resources_wholesale5513_path(@sheet_obj)
  end

  def hp
    @xlsx.sheets.each do |sheet|
      if (sheet == "HP")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 10
        end_range = 30
        row_count = 20
        column_count = 3
        num1 = 4
        num2 = 1
        inc_row = 1
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_american_financial_resources_wholesale5513_path(@sheet_obj)
  end

  def jumbo
    @xlsx.sheets.each do |sheet|
      if (sheet == "Jumbo")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 11
        end_range = 27
        row_count = 13
        column_count = 3
        num1 = 5
        num2 = 1
        inc_row = 3
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_american_financial_resources_wholesale5513_path(@sheet_obj)
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
		file = File.join(Rails.root + "other_sheets", 'OB_American_Financial_Resources_Wholesale5513.xls')
    @xlsx = Roo::Spreadsheet.open(file)
  end

  # create programs
  def make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
    (start_range..end_range).each do |r|
      row = sheet_data.row(r)
      if ((row.compact.count >= 1) && (row.compact.count <= 6)) && (!row.compact.include?("GOVERNMENT PRICE ADJUSTMENTS"))
        rr = r + inc_row
        max_column_section = row.compact.count - 1
        (0..max_column_section).each do |max_column|
          cc = num1 * max_column + num2

          begin
            @title = sheet_data.cell(r,cc)
            if @title.present? && !@title.include?("Rate") && !@title.include?("All-in") && !@title.include?("GOVERNMENT")
              @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
              @programs_ids << @program.id

              # Arm Basic
              if @program.program_name.include?("5/1 Arm")
                arm_basic = 5
              end

              # term
              if @title.scan(/\d+/).count == 1
                term = @title.scan(/\d+/)[0]
              else
                term = (@title.scan(/\d+/)[0]+ @title.scan(/\d+/)[1]).to_i
              end
              # High Balance
              if @title.include?("HIGH BAL") || @title.include?("HIGH BALANCE") || @title.include?("High Balance")
                loan_size = "High-Balance"
                jumbo_high_balance = true
              end
              # Loan-Type
              if @title.include?("Fixed")
                loan_type = "Fixed"
              elsif @title.include?("ARM")
                loan_type = "ARM"
              elsif @title.include?("Floating")
                loan_type = "Floating"
              elsif @title.include?("Variable")
                loan_type = "Variable"
              else
                loan_type = nil
              end

              # Streamline Vha, Fha, Usda
              fha = false
              va = false
              usda = false
              streamline = false
              full_doc = false
              if @title.include?("FHA")
                streamline = true
                fha = true
                full_doc = true
              elsif @title.include?("VA")
                streamline = true
                va = true
                full_doc = true
              elsif @title.include?("USDA")
                streamline = true
                usda = true
                full_doc = true
              end

              # Update Program
              @program.update(arm_basic: arm_basic,term: term, loan_size: loan_size, jumbo_high_balance: jumbo_high_balance,loan_type: loan_type,fha: fha, va: va, usda: usda, streamline: streamline, full_doc: full_doc)

              # Base rate
              @program.adjustments.destroy_all
              @block_hash = {}
              key = ''
              (1..row_count).each do |max_row|
                @data = []
                (0..column_count).each_with_index do |index, c_i|
                  rrr = rr + max_row
                  ccc = cc + c_i
                  value = sheet_data.cell(rrr,ccc)
                  if value.present?
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    else
                      @block_hash[key][15*(c_i+1)] = value
                    end
                    @data << value
                  end
                end
                if @data.compact.reject { |c| c.blank? }.length == 0
                  break # terminate the loop
                end
              end
              @program.update(base_rate: @block_hash)
            end
          rescue Exception => e
            error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
            error_log.save
          end
        end
      end
    end
  end
end
