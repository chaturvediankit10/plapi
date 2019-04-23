class RateSheetExtractor::ObDirectMortgageCorpWholesale8443Controller < RateSheetExtractor::ApplicationController
  before_action :get_sheet, only: [:programs, :rate_sheet_single_page_excel]
  before_action :read_sheet, only: [:index, :rate_sheet_single_page_excel]
  before_action :get_program, only: [:single_program]

  def index
    file = File.join(Rails.root, 'OB_Direct_Mortgage_Corp_Wholesale8443.xls')
    xlsx = Roo::Spreadsheet.open(file)
    begin
      xlsx.sheets.each do |sheet|
        if (sheet == "RateSheet-SinglePageExcel")
          headers = ["Phone", "General Contacts", "Mortgagee Clause (Wholesale)"]
          @name = "Direct Mortgage Corp Wholesale"
          @bank = Bank.find_or_create_by(name: @name)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
      end
    rescue
      # the required headers are not all present
    end
  end

  def rate_sheet_single_page_excel
    @xlsx.sheets.each do |sheet|
      if (sheet == "RateSheet-SinglePageExcel")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 7
        end_range = 596
        row_count = 14
        column_count = 3
        num1 = 4
        num2 = 1
        inc_row = 1
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, inc_row, sheet
      end
    end
    redirect_to programs_ob_direct_mortgage_corp_wholesale8443_path(@sheet_obj)
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
  		file = File.join(Rails.root + "other_sheets", 'OB_Direct_Mortgage_Corp_Wholesale8443.xls')
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
            cc = 15 if max_column > 2
            @title = sheet_data.cell(r,cc)
            begin
              if @title.present? && @title.length >= 10 && !@title.include?("Program") && @title != "LP Single Life of Loan Lender Paid MI" && @title != "DU Single Life of Loan Lender Paid MI" && @title != "6228 DU 5-10 Properties Financed" && @title != "LP Single Life of Loan Borrower Paid MI" && @title != "DU Single Life of Loan Borrower Paid MI" && !@title.include?("Margin")
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @programs_ids << @program.id

                # Arm Basic
                if @program.program_name.include?("1/1")
                  arm_basic = 1
                elsif @program.program_name.include?("2/1")
                  arm_basic = 2
                elsif @program.program_name.include?("3/1")
                  arm_basic = 3
                elsif @program.program_name.include?("5/1")
                  arm_basic = 5
                elsif @program.program_name.include?("7/1")
                    arm_basic = 7
                elsif @program.program_name.include?("10/1")
                  arm_basic = 10
                end

                # fannie-mae and freddie-mac
                if @title.include?("DU")
                  fannie_mae = true
                elsif @title.include?("LP")
                  freddie_mac = true
                end


                # term
                if @title.scan(/\d+/).count == 1
                  term = @title.scan(/\d+/)[0]
                else
                  term = (@title.scan(/\d+/)[0]+ @title.scan(/\d+/)[1]).to_i
                end

                # Loan Size
                if @title.include?("HIGH BAL") || @title.include?("HIGH BALANCE") || @title.include?("High Balance")
                  loan_size = "High-Balance"
                  jumbo_high_balance = true
                elsif @title.include?("Conforming")
                  loan_size = "Conforming"
                  conforming = true
                elsif @title.include?("Jumbo")
                  loan_size = "Jumbo"
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

                #Loan-Purchase
                if @title.include?("Purchase")
                  loan_purpose = "Purchase"
                elsif @title.include?("Refinance")
                  loan_purpose = "Refinance"
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
                @program.update(arm_basic: arm_basic,term: term, loan_size: loan_size, jumbo_high_balance: jumbo_high_balance,loan_type: loan_type,fha: fha, va: va, usda: usda, streamline: streamline, full_doc: full_doc, loan_purpose: loan_purpose, fannie_mae: fannie_mae, freddie_mac: freddie_mac)

                # Base rate
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..row_count).each do |max_row|
                  @data = []
                  column_count = 5 if (cc == 9)
                  (0..column_count).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if ccc >= 12 && ccc < 15
                        c_i = (c_i - 2)
                      end
                      if (c_i == 0)
                        key = value
                        key = key.split('%').last
                        @block_hash[key] = {}
                      elsif (c_i == 1)
                        @block_hash[key][12] = value
                      elsif (c_i == 2)
                        @block_hash[key][30] = value
                      elsif (c_i == 3)
                        @block_hash[key][60] = value
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
