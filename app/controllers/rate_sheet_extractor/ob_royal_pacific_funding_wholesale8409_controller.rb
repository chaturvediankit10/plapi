class RateSheetExtractor::ObRoyalPacificFundingWholesale8409Controller < RateSheetExtractor::ApplicationController
  before_action :get_program, only: [:single_program, :program_property]
  before_action :get_sheet, only: [:programs, :royal_pfc, :fha_standard_programs, :fha_streamline_programs, :va_standard_programs, :va_streamline_programs, :conventional_fixed_programs, :conventional_arm_programs, :freddie_mac_programs, :core_jumbo_minimum_loan_amount, :core_jumbo_minimum_loan_amount_above_agency_limit, :choice_advantage_plus, :choice_advantage, :choice_alternative, :choice_ascent, :choice_investor, :pivot_prime_jumbo]
  before_action :read_sheet, only: [:index,:royal_pfc, :fha_standard_programs, :fha_streamline_programs, :va_standard_programs, :va_streamline_programs, :conventional_fixed_programs, :conventional_arm_programs, :freddie_mac_programs, :core_jumbo_minimum_loan_amount, :core_jumbo_minimum_loan_amount_above_agency_limit, :choice_advantage_plus, :choice_advantage, :choice_alternative, :choice_ascent, :choice_investor, :pivot_prime_jumbo]

  def index
    begin
      @xlsx.sheets.each do |sheet|
        if (sheet == "Royal PFC")
          @name = "Royal Pacific Funding"
          @bank = Bank.find_or_create_by(name: @name)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
        sub_sheet_names.each do |sub_sheet|
          @sub_sheet = @sheet.sub_sheets.find_or_create_by(name: sub_sheet)
        end
      end
    rescue
    end
  end

  def fha_standard_programs
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 104
        end_range = 135
        row_count = 13
        column_count = 2
        num1 = 4
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def fha_streamline_programs
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 141
        end_range = 173
        row_count = 13
        column_count = 2
        num1 = 4
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def va_standard_programs
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 221
        end_range = 252
        row_count = 13
        column_count = 2
        num1 = 4
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def va_streamline_programs
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 258
        end_range = 290
        row_count = 13
        column_count = 2
        num1 = 4
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def conventional_fixed_programs
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 335
        end_range = 372
        row_count = 15
        column_count = 2
        num1 = 4
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def conventional_arm_programs
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 378
        end_range = 394
        row_count = 13
        column_count = 2
        num1 = 4
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def freddie_mac_programs
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 519
        end_range = 551
        row_count = 12
        column_count = 2
        num1 = 4
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def core_jumbo_minimum_loan_amount_above_agency_limit
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 608
        end_range = 620
        row_count = 12
        column_count = 2
        num1 = 4
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def choice_advantage_plus
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 694
        end_range = 708
        row_count = 12
        column_count = 2
        num1 = 4
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def choice_advantage
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 818
        end_range = 832
        row_count = 12
        column_count = 2
        num1 = 4
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def choice_alternative
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 877
        end_range = 891
        row_count = 12
        column_count = 2
        num1 = 12
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def choice_ascent
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 937
        end_range = 951
        row_count = 12
        column_count = 2
        num1 = 12
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def choice_investor
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 983
        end_range = 997
        row_count = 12
        column_count = 2
        num1 = 12
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
  end

  def pivot_prime_jumbo
    @xlsx.sheets.each do |sheet|
      if (sheet == "Royal PFC")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 1524
        end_range = 1555
        row_count = 11
        column_count = 2
        num1 = 12
        num2 = 2
        inc_row = 2
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_royal_pacific_funding_wholesale8409_path(@sheet_obj)
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
  def get_sheets_names
    return ["FHA STANDARD PROGRAMS", "FHA STREAMLINE PROGRAMS", "VA STANDARD PROGRAMS", "VA STREAMLINE PROGRAMS", "CONVENTIONAL FIXED PROGRAMS", "CONVENTIONAL ARM PROGRAMS", "FREDDIE MAC PROGRAMS", "Core Jumbo - Minimum Loan Amount $1.00 above Agency Limit", "Choice Advantage Plus", "Choice Advantage", "Choice Alternative", "Choice Ascent", "Choice Investor", "Pivot Prime Jumbo", "Pivot Core / Plus"]
  end

  def get_sheet
    @sheet_obj = SubSheet.find(params[:id])
  end

  def read_sheet
		file = File.join(Rails.root + "other_sheets", 'OB_Royal_Pacific_Funding_Wholesale8409.xls')
    @xlsx = Roo::Spreadsheet.open(file)
  end


  # create programs
  def make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
    (start_range..end_range).each do |r|
      row = sheet_data.row(r)
      if ((row.compact.count >= 1) && (row.compact.count <= 4))
        rr = r + inc_row
        max_column_section = row.compact.count - 1
        (0..max_column_section).each do |max_column|
          cc = num1 * max_column + num2
          cc = 7*max_column if ((max_column >= 1) && (start_range == 694 || start_range == 818 || start_range == 1524))
          begin
            @title = sheet_data.cell(r,cc)
            if @title.present? && @title.length > 8 && !@title.include?("Programs") && !@title.include?("Adjusters") && !@title.include?("Amount") && !@title.include?("Margin") && !@title.include?("Max") && !@title.include?("$") && !@title.include?("FICO") && !@title.include?("not allowed") && @title != "HomeReady Mortgage Caps" && !@title.include?("Non-Escrowed")
              @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
              @programs_ids << @program.id

              # Arm Basic
              if @program.program_name.include?("5/1 Arm")
                arm_basic = 5
              end

              # Arm Advanced
              if @program.program_name.include?("5/2/5")
                arm_advanced = "5/2/5"
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

              #fannie_mae_product
              if @program.program_name.include?("HomeReady")
                @program.fannie_mae_product = "HomeReady"
              end

              # fannie-mae and freddie-mac
              if @title.include?("DU")
                fannie_mae = true
              elsif @title.include?("LP")
                freddie_mac = true
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
                column_count = 5 if (cc > 6 && start_range == 694 || start_range == 818 || start_range == 1524)
                (0..column_count).each_with_index do |index, c_i|
                  rrr = rr + max_row
                  ccc = cc + c_i
                  value = sheet_data.cell(rrr,ccc)
                  if value.present?
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    else
                      if (ccc >= 7 && ccc <= 11) && (start_range == 694 || start_range == 818 || start_range == 1524)
                        c_i = c_i - 2 if (c_i > 0)
                      end
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
