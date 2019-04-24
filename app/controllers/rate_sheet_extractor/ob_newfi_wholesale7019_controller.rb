class RateSheetExtractor::ObNewfiWholesale7019Controller < RateSheetExtractor::ApplicationController
  before_action :read_sheet, only: [:index, :program, :biscayne_delegated_jumbo, :sequoia_portfolio_plus_products, :sequoia_expanded_products, :sequoia_investor_pro, :fha_buydown_fixed_rate_products, :fha_fixed_arm_products, :fannie_mae_homeready_products, :fnma_buydown_products, :fnma_conventional_fixed_rate, :fnma_conventional_high_balance, :fnma_conventional_arm, :olympic_piggyback_fixed, :olympic_piggyback_high_balance, :olympic_piggyback_arm]
  before_action :get_sheet, only: [:programs, :biscayne_delegated_jumbo, :sequoia_portfolio_plus_products, :sequoia_expanded_products, :sequoia_investor_pro, :fha_buydown_fixed_rate_products, :fha_fixed_arm_products, :fannie_mae_homeready_products, :fnma_buydown_products, :fnma_conventional_fixed_rate, :fnma_conventional_high_balance, :fnma_conventional_arm, :olympic_piggyback_fixed, :olympic_piggyback_high_balance, :olympic_piggyback_arm]
  before_action :get_program, only: [:single_program]
  def index
    begin
      @xlsx.sheets.each do |sheet|
        if (sheet == "BISCAYNE DELEGATED JUMBO")
          headers = ["Phone", "General Contacts", "Mortgagee Clause (Wholesale)"]
          @name = "Newfi Wholesale"
          @bank = Bank.find_or_create_by(name: @name)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
      end
    rescue
      # the required headers are not all present
    end
  end

  def biscayne_delegated_jumbo
    @xlsx.sheets.each do |sheet|
      if (sheet == "BISCAYNE DELEGATED JUMBO")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @ltv_data = []
        @cltv_data = []
        @adjustment_hash = {}
        @purpose_adjustment = {}
        @highAdjustment = {}
        ltv_key = ''
        cltv_key = ''
        primary_key = ''

        #program
        (51..92).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count < 4)) || row.include?("7/1 LIBOR ARM BISCAYNE JUMBO") || row.include?("10/1 LIBOR ARM BISCAYNE JUMBO")
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              if r == 77
                cc = 15
              else
                cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              end

              @title = sheet_data.cell(r,cc)
              if @title.present? && @title != "Rate"
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_property @title
                p_name = @title + sheet
                @program.update_fields p_name
                @programs_ids << @program.id
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    begin
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        elsif (c_i == 1)
                          @block_hash[key][30] = value
                        elsif (c_i == 2)
                          @block_hash[key][45] = value
                        elsif (c_i == 3)
                          @block_hash[key][60] = value
                        else
                          @block_hash[key][15*c_i] = value
                        end
                        @data << value
                      end
                    rescue Exception => e
                      error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
                      error_log.save
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              end
            end
          end
        end
        # adjustments
        (108..153).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(109)
          @cltv_data = sheet_data.row(136)
          (0..13).each do |cc|
            value = sheet_data.cell(r,cc)
            begin
              if value.present?
                if value == "Biscayne High Balance Price Adjustments"
                  primary_key = "HighBalance/FICO/CLTV"
                  @highAdjustment[primary_key] = {}
                end
                if r == 108 && value == "CLTV"
                  primary_key = "FICO/CLTV"
                  @adjustment_hash[primary_key] = {}
                end
                # CLTV
                if r >= 110 && r <= 115 && cc == 4
                  ltv_key = value
                  @adjustment_hash[primary_key][ltv_key] = {}
                end
                if r >= 110 && r <= 115 && cc >= 5 && cc <= 12
                  cltv_key = get_value @ltv_data[cc-3]
                  @adjustment_hash[primary_key][ltv_key][cltv_key] = {}
                  @adjustment_hash[primary_key][ltv_key][cltv_key] = value
                end
                if r == 119 && cc == 4
                  @purpose_adjustment = {}
                  @purpose_adjustment["RefinanceOption/CLTV"] = {}
                  @purpose_adjustment["RefinanceOption/CLTV"]["Cash Out"] = {}
                end
                if r == 119 && cc >= 5 && cc <= 12
                  cltv_key = get_value @ltv_data[cc-3]
                  @purpose_adjustment["RefinanceOption/CLTV"]["Cash Out"][cltv_key] = {}
                  @purpose_adjustment["RefinanceOption/CLTV"]["Cash Out"][cltv_key] = value
                end

                if r == 120 && cc == 4
                  @purpose_adjustment2 ={}
                  @purpose_adjustment2["LoanPurpose/CLTV"] = {}
                  @purpose_adjustment2["LoanPurpose/CLTV"]["Purchase"] = {}
                end
                if r == 120 && cc >= 5 && cc <= 12
                  cltv_key = get_value @ltv_data[cc-3]
                  @purpose_adjustment2["LoanPurpose/CLTV"]["Purchase"][cltv_key] = {}
                  @purpose_adjustment2["LoanPurpose/CLTV"]["Purchase"][cltv_key] = value
                end

                if r == 121 && cc == 4
                  @purpose_adjustment3 ={}
                  @purpose_adjustment3["LoanAmount/CLTV"] = {}
                  @purpose_adjustment3["LoanAmount/CLTV"]["0-1500000"] = {}
                end
                if r == 121 && cc >= 5 && cc <= 12
                  cltv_key = get_value @ltv_data[cc-3]
                  @purpose_adjustment3["LoanAmount/CLTV"]["0-1500000"][cltv_key] = {}
                  @purpose_adjustment3["LoanAmount/CLTV"]["0-1500000"][cltv_key] = value
                end

                if r == 122 && cc == 4
                  @purpose_adjustment4 ={}
                  @purpose_adjustment4["LoanAmount/CLTV"] = {}
                  @purpose_adjustment4["LoanAmount/CLTV"]["1500000-Inf"] = {}
                end
                if r == 122 && cc >= 5 && cc <= 12
                  cltv_key = get_value @ltv_data[cc-3]
                  @purpose_adjustment4["LoanAmount/CLTV"]["1500000-Inf"][cltv_key] = {}
                  @purpose_adjustment4["LoanAmount/CLTV"]["1500000-Inf"][cltv_key] = value
                end

                if r == 123 && cc == 4
                  @purpose_adjustment5 ={}
                  @purpose_adjustment5["LTV/CLTV"] = {}
                  @purpose_adjustment5["LTV/CLTV"]["80-Inf"] = {}
                end
                if r == 123 && cc >= 5 && cc <= 12
                  cltv_key = get_value @ltv_data[cc-3]
                  @purpose_adjustment5["LTV/CLTV"]["80-Inf"][cltv_key] = {}
                  @purpose_adjustment5["LTV/CLTV"]["80-Inf"][cltv_key] = value
                end

                if r == 125 && cc == 4
                  @purpose_adjustment6 ={}
                  @purpose_adjustment6["PropertyType/CLTV"] = {}
                  @purpose_adjustment6["PropertyType/CLTV"]["Non-Owner Occupied"] = {}
                end
                if r == 125 && cc >= 5 && cc <= 12
                  cltv_key = get_value @ltv_data[cc-3]
                  @purpose_adjustment6["PropertyType/CLTV"]["Non-Owner Occupied"][cltv_key] = {}
                  @purpose_adjustment6["PropertyType/CLTV"]["Non-Owner Occupied"][cltv_key] = value
                end

                # Biscayne High Balance Price Adjustments
                @fico_data = ["680-699", "700-719", "720-739", "740-759", "760-779", "780-850"]
                 if r == 137 && cc==4
                  @highAdjustment ={}
                  @highAdjustment["LoanSize/FICO/CLTV"] = {}
                  @highAdjustment["LoanSize/FICO/CLTV"]["High-Balance"] = {}
                end

                if  r == 137 && cc==4
                  @fico_data.each do |fico_data|
                    @highAdjustment["LoanSize/FICO/CLTV"]["High-Balance"][fico_data] = {}
                  end
                end

                if r >= 137 && r <= 142 && cc >= 5 && cc <= 13
                  cltv_key = get_value @cltv_data[cc-3]
                  @highAdjustment["LoanSize/FICO/CLTV"]["High-Balance"][@fico_data[r-137]][cltv_key] = value
                end

                if  r == 146 && cc==4
                  @highAdjustment1 ={}
                  @highAdjustment1["RefinanceOption/CLTV"] = {}
                  @highAdjustment1["RefinanceOption/CLTV"]["Cash Out"] = {}
                end

                if r == 146 && cc >= 5 && cc <= 13
                  cltv_key = get_value @ltv_data[cc-3]
                  @highAdjustment1["RefinanceOption/CLTV"]["Cash Out"][cltv_key] = {}
                  @highAdjustment1["RefinanceOption/CLTV"]["Cash Out"][cltv_key] = value
                end

                if  r == 147 && cc==4
                  @highAdjustment2 ={}
                  @highAdjustment2["LoanPurpose/CLTV"] = {}
                  @highAdjustment2["LoanPurpose/CLTV"]["Purchase"] = {}
                end

                if r == 147 && cc >= 5 && cc <= 13
                  cltv_key = get_value @ltv_data[cc-3]
                  @highAdjustment2["LoanPurpose/CLTV"]["Purchase"][cltv_key] = {}
                  @highAdjustment2["LoanPurpose/CLTV"]["Purchase"][cltv_key] = value
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@adjustment_hash, @purpose_adjustment, @purpose_adjustment2, @purpose_adjustment3, @purpose_adjustment4, @purpose_adjustment5, @purpose_adjustment6, @highAdjustment, @highAdjustment1, @highAdjustment2]
        make_adjust(adjustment,sheet)

        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def sequoia_portfolio_plus_products
    @xlsx.sheets.each do |sheet|
      if (sheet == "SEQUOIA PORTFOLIO PLUS PRODUCTS")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @cashout = {}
        @additional_hash = {}
        @rate_hash = {}
        @cashout_hash = {}
        @other_adjustment = {}
        @ltv_data = []
        primary_key = ''
        ltv_key = ''
        #program
        (51..92).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @term = program_property @title
                  p_name = @title + sheet
                  @program.update_fields p_name
                  @programs_ids << @program.id
                end
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    begin
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else                          
                          @block_hash[key][15*c_i] = value
                        end
                        @data << value
                      end
                    rescue Exception => e
                      error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                      error_log.save
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # Adjustments
        (100..172).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(104)
          (0..19).each do |cc|
            value = sheet_data.cell(r,cc)
            if value.present?
              if value == "Full Doc Pricing Adjustments"
                @adjustment_hash["FICO/LTV"] = {}
                @cashout["RefinanceOption/FICO/LTV"] = {}
                @cashout["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                @additional_hash["PropertyType/LTV"] = {}
              end
              if value == "Bank Statement Pricing Adjustments"
                @rate_hash["FICO/LTV"] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                @other_adjustment["PropertyType/LTV"] = {}
              end
              if r >= 105 && r <= 110 && cc == 3
                primary_key = get_value value
                @adjustment_hash["FICO/LTV"][primary_key] = {}
              end
              if r >= 105 && r <= 110 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @adjustment_hash["FICO/LTV"][primary_key][ltv_key] = {}
                @adjustment_hash["FICO/LTV"][primary_key][ltv_key] = value
              end
              if r >= 113 && r <= 118 && cc == 3
                primary_key = get_value value
                @cashout["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
              end
              if r >= 113 && r <= 118 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @cashout["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = {}
                @cashout["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = value
              end
              if r == 121 && cc == 3
                @additional_hash["LoanAmount/LTV"] = {}
                @additional_hash["LoanAmount/LTV"]["1500000"] = {}
              end
              if r == 121 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @additional_hash["LoanAmount/LTV"]["1500000"][ltv_key] = {}
                @additional_hash["LoanAmount/LTV"]["1500000"][ltv_key] = value
              end
              if r == 122 && cc == 3
                @additional_hash["LoanType/LTV"] = {}
                @additional_hash["LoanType/LTV"]["ARM"] = {}
                @additional_hash["LoanType/Term/LTV"] = {}
                @additional_hash["LoanType/Term/LTV"]["Fixed"] = {}
                @additional_hash["LoanType/Term/LTV"]["Fixed"]["30"] = {}
              end
              if r == 122 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @additional_hash["LoanType/LTV"]["ARM"][ltv_key] = {}
                @additional_hash["LoanType/LTV"]["ARM"][ltv_key] = value
                @additional_hash["LoanType/Term/LTV"]["Fixed"]["30"][ltv_key] = {}
                @additional_hash["LoanType/Term/LTV"]["Fixed"]["30"][ltv_key] = value
              end
              if r >= 123 && r <= 126 && cc == 3
                if value == "Investment"
                  primary_key = "Investment Property"
                else
                  primary_key = value
                end
                @additional_hash["PropertyType/LTV"][primary_key] = {}
              end
              if r >= 123 && r <= 126 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @additional_hash["PropertyType/LTV"][primary_key][ltv_key] = {}
                @additional_hash["PropertyType/LTV"][primary_key][ltv_key] = value
              end
              if r == 127 && cc == 3
                @additional_hash["LoanType/Term"] = {}
                @additional_hash["LoanType/Term"]["Fixed"] = {}
                @additional_hash["LoanType/Term"]["Fixed"]["40"] = {}
              end
              if r == 127 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @additional_hash["LoanType/Term"]["Fixed"]["40"][ltv_key] = {}
                @additional_hash["LoanType/Term"]["Fixed"]["40"][ltv_key] = value
              end
              if r == 128 && cc == 3
                @additional_hash["FullDoc/LTV"] = {}
                @additional_hash["FullDoc/LTV"]["true"] = {}
              end
              if r == 128 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @additional_hash["FullDoc/LTV"]["true"][ltv_key] = {}
                @additional_hash["FullDoc/LTV"]["true"][ltv_key] = value
              end
              if r >= 136 && r <= 141 && cc == 3
                primary_key = get_value value
                @rate_hash["FICO/LTV"][primary_key] = {}
              end
              if r >= 136 && r <= 141 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @rate_hash["FICO/LTV"][primary_key][ltv_key] = {}
                @rate_hash["FICO/LTV"][primary_key][ltv_key] = value
              end
              if r >= 144 && r <= 149 && cc == 3
                primary_key = get_value value
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
              end
              if r >= 144 && r <= 149 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = value
              end
              if r == 152 && cc == 3
                @other_adjustment["LoanAmount/LTV"] = {}
                @other_adjustment["LoanAmount/LTV"]["1500000"] = {}
              end
              if r == 152 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @other_adjustment["LoanAmount/LTV"]["1500000"][ltv_key] = {}
                @other_adjustment["LoanAmount/LTV"]["1500000"][ltv_key] = value
              end
              if r == 153 && cc == 3
                @other_adjustment["LoanType/LTV"] = {}
                @other_adjustment["LoanType/LTV"]["ARM"] = {}
                @other_adjustment["LoanType/Term/LTV"] = {}
                @other_adjustment["LoanType/Term/LTV"]["Fixed"] = {}
                @other_adjustment["LoanType/Term/LTV"]["Fixed"]["30"] = {}
              end
              if r == 153 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @other_adjustment["LoanType/LTV"]["ARM"][ltv_key] = {}
                @other_adjustment["LoanType/LTV"]["ARM"][ltv_key] = value
                @other_adjustment["LoanType/Term/LTV"]["Fixed"]["30"][ltv_key] = {}
                @other_adjustment["LoanType/Term/LTV"]["Fixed"]["30"][ltv_key] = value
              end
              if r >= 154 && r <= 157 && cc == 3
                if value == "Investment"
                  primary_key = "Investment Property"
                else
                  primary_key = value
                end
                @other_adjustment["PropertyType/LTV"][primary_key] = {}
              end
              if r >= 154 && r <= 157 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @other_adjustment["PropertyType/LTV"][primary_key][ltv_key] = {}
                @other_adjustment["PropertyType/LTV"][primary_key][ltv_key] = value
              end
              if r == 158 && cc == 3
                @other_adjustment["LoanType/Term"] = {}
                @other_adjustment["LoanType/Term"]["Fixed"] = {}
                @other_adjustment["LoanType/Term"]["Fixed"]["40"] = {}
              end
              if r == 158 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @other_adjustment["LoanType/Term"]["Fixed"]["40"][ltv_key] = {}
                @other_adjustment["LoanType/Term"]["Fixed"]["40"][ltv_key] = value
              end
              if r == 159 && cc == 3
                @other_adjustment["FullDoc/LTV"] = {}
                @other_adjustment["FullDoc/LTV"]["true"] = {}
              end
              if r == 159 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @other_adjustment["FullDoc/LTV"]["true"][ltv_key] = {}
                @other_adjustment["FullDoc/LTV"]["true"][ltv_key] = value
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@cashout,@additional_hash,@rate_hash,@cashout_hash,@other_adjustment]
        make_adjust(adjustment,sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def sequoia_expanded_products
    @xlsx.sheets.each do |sheet|
      if (sheet == "SEQUOIA EXPANDED PRODUCTS")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @cashout = {}
        @additional_hash = {}
        @rate_hash = {}
        @cashout_hash = {}
        @other_adjustment = {}
        @ltv_data = []
        primary_key = ''
        ltv_key = ''
        #program
        (51..92).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              @title = sheet_data.cell(r,cc)
                begin
                  @title = sheet_data.cell(r,cc)
                  if @title.present?
                    @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                    @term = program_property @title
                    p_name = @title + sheet
                    @program.update_fields p_name
                    @programs_ids << @program.id
                  end

                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                rescue Exception => e
                  error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                  error_log.save
                end
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    begin
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][15*c_i] = value
                        end
                        @data << value
                      end
                    rescue Exception => e
                      error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                      error_log.save
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
            end
          end
        end
        # Adjustments
        (100..183).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(104)
          (0..19).each do |cc|
            value = sheet_data.cell(r,cc)
            if value.present?
              if value == "Full Doc Pricing Adjustments"
                @adjustment_hash["FICO/LTV"] = {}
                @cashout["RefinanceOption/FICO/LTV"] = {}
                @cashout["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                @additional_hash["PropertyType/LTV"] = {}
              end
              if value == "Bank Statement Pricing Adjustments"
                @rate_hash["FICO/LTV"] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                @other_adjustment["PropertyType/LTV"] = {}
              end
              if r >= 105 && r <= 112 && cc == 3
                primary_key = get_value value
                @adjustment_hash["FICO/LTV"][primary_key] = {}
              end
              if r >= 105 && r <= 112 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @adjustment_hash["FICO/LTV"][primary_key][ltv_key] = {}
                @adjustment_hash["FICO/LTV"][primary_key][ltv_key] = value
              end
              if r >= 115 && r <= 122 && cc == 3
                primary_key = get_value value
                @cashout["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
              end
              if r >= 115 && r <= 122 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @cashout["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = {}
                @cashout["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = value
              end
              if r == 125 && cc == 3
                @additional_hash["LoanAmount/LTV"] = {}
                @additional_hash["LoanAmount/LTV"]["1500000"] = {}
              end
              if r == 125 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @additional_hash["LoanAmount/LTV"]["1500000"][ltv_key] = {}
                @additional_hash["LoanAmount/LTV"]["1500000"][ltv_key] = value
              end
              if r == 126 && cc == 3
                @additional_hash["LoanType/LTV"] = {}
                @additional_hash["LoanType/LTV"]["ARM"] = {}
                @additional_hash["LoanType/Term/LTV"] = {}
                @additional_hash["LoanType/Term/LTV"]["Fixed"] = {}
                @additional_hash["LoanType/Term/LTV"]["Fixed"]["30"] = {}
              end
              if r == 126 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @additional_hash["LoanType/LTV"]["ARM"][ltv_key] = {}
                @additional_hash["LoanType/LTV"]["ARM"][ltv_key] = value
                @additional_hash["LoanType/Term/LTV"]["Fixed"]["30"][ltv_key] = {}
                @additional_hash["LoanType/Term/LTV"]["Fixed"]["30"][ltv_key] = value
              end
              if r >= 127 && r <= 130 && cc == 3
                if value == "Investment"
                  primary_key = "Investment Property"
                else
                  primary_key = value
                end
                @additional_hash["PropertyType/LTV"][primary_key] = {}
              end
              if r >= 127 && r <= 130 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @additional_hash["PropertyType/LTV"][primary_key][ltv_key] = {}
                @additional_hash["PropertyType/LTV"][primary_key][ltv_key] = value
              end
              if r == 131 && cc == 3
                @additional_hash["LoanType/Term"] = {}
                @additional_hash["LoanType/Term"]["Fixed"] = {}
                @additional_hash["LoanType/Term"]["Fixed"]["40"] = {}
              end
              if r == 131 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @additional_hash["LoanType/Term"]["Fixed"]["40"][ltv_key] = {}
                @additional_hash["LoanType/Term"]["Fixed"]["40"][ltv_key] = value
              end
              if r == 132 && cc == 3
                @additional_hash["FullDoc/LTV"] = {}
                @additional_hash["FullDoc/LTV"]["true"] = {}
              end
              if r == 132 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @additional_hash["FullDoc/LTV"]["true"][ltv_key] = {}
                @additional_hash["FullDoc/LTV"]["true"][ltv_key] = value
              end
              if r >= 140 && r <= 147 && cc == 3
                primary_key = get_value value
                @rate_hash["FICO/LTV"][primary_key] = {}
              end
              if r >= 140 && r <= 147 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @rate_hash["FICO/LTV"][primary_key][ltv_key] = {}
                @rate_hash["FICO/LTV"][primary_key][ltv_key] = value
              end
              if r >= 150 && r <= 157 && cc == 3
                primary_key = get_value value
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
              end
              if r >= 150 && r <= 157 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = value
              end
              if r == 160 && cc == 3
                @other_adjustment["LoanAmount/LTV"] = {}
                @other_adjustment["LoanAmount/LTV"]["1500000"] = {}
              end
              if r == 160 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @other_adjustment["LoanAmount/LTV"]["1500000"][ltv_key] = {}
                @other_adjustment["LoanAmount/LTV"]["1500000"][ltv_key] = value
              end
              if r == 161 && cc == 3
                @other_adjustment["LoanType/LTV"] = {}
                @other_adjustment["LoanType/LTV"]["ARM"] = {}
                @other_adjustment["LoanType/Term/LTV"] = {}
                @other_adjustment["LoanType/Term/LTV"]["Fixed"] = {}
                @other_adjustment["LoanType/Term/LTV"]["Fixed"]["30"] = {}
              end
              if r == 161 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @other_adjustment["LoanType/LTV"]["ARM"][ltv_key] = {}
                @other_adjustment["LoanType/LTV"]["ARM"][ltv_key] = value
                @other_adjustment["LoanType/Term/LTV"]["Fixed"]["30"][ltv_key] = {}
                @other_adjustment["LoanType/Term/LTV"]["Fixed"]["30"][ltv_key] = value
              end
              if r >= 162 && r <= 165 && cc == 3
                if value == "Investment"
                  primary_key = "Investment Property"
                else
                  primary_key = value
                end
                @other_adjustment["PropertyType/LTV"][primary_key] = {}
              end
              if r >= 162 && r <= 165 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @other_adjustment["PropertyType/LTV"][primary_key][ltv_key] = {}
                @other_adjustment["PropertyType/LTV"][primary_key][ltv_key] = value
              end
              if r == 166 && cc == 3
                @other_adjustment["LoanType/Term"] = {}
                @other_adjustment["LoanType/Term"]["Fixed"] = {}
                @other_adjustment["LoanType/Term"]["Fixed"]["40"] = {}
              end
              if r == 166 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @other_adjustment["LoanType/Term"]["Fixed"]["40"][ltv_key] = {}
                @other_adjustment["LoanType/Term"]["Fixed"]["40"][ltv_key] = value
              end
              if r == 167 && cc == 3
                @other_adjustment["FullDoc/LTV"] = {}
                @other_adjustment["FullDoc/LTV"]["true"] = {}
              end
              if r == 167 && cc >= 5 && cc <= 19
                ltv_key = get_value @ltv_data[cc-3]
                @other_adjustment["FullDoc/LTV"]["true"][ltv_key] = {}
                @other_adjustment["FullDoc/LTV"]["true"][ltv_key] = value
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@cashout,@additional_hash,@rate_hash,@cashout_hash,@other_adjustment]
        make_adjust(adjustment,sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def sequoia_investor_pro
    @xlsx.sheets.each do |sheet|
      if (sheet == "SEQUOIA INVESTOR PRO")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @other_adjustment = {}
        @other_adjustment1 = {}
        primary_key = ''
        secondary_key = ''

        # programs
        (51..92).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              @title = sheet_data.cell(r,cc)
              if @title.present?
                begin
                  @title = sheet_data.cell(r,cc)
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @term = program_property @title
                  p_name = @title + sheet
                    @program.update_fields p_name
                  @program.update(arm_advanced: nil)
                  @programs_ids << @program.id

                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                rescue Exception => e
                  error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                  error_log.save
                end
              end
              @program.adjustments.destroy_all
              @block_hash = {}
              key = ''
              (1..50).each do |max_row|
                @data = []
                (0..4).each_with_index do |index, c_i|
                  rrr = rr + max_row
                  ccc = cc + c_i
                  value = sheet_data.cell(rrr,ccc)
                  begin
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      else
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  rescue Exception => e
                    error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
                    error_log.save
                  end
                end
                if @data.compact.reject { |c| c.blank? }.length == 0
                  break # terminate the loop
                end
              end
              if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                @block_hash.shift
              end
              @program.update(base_rate: @block_hash,loan_category: sheet)
            end
          end
        end
        # Adjustments
        (77..105).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(81)
          if row.compact.count >= 1
            (0..12).each do |cc|
              value = sheet_data.cell(r,cc)
              begin
                if value.present?
                  if value == " Price Adjustments"
                    @adjustment_hash["FICO/LTV"] = {}
                    @other_adjustment1["LoanAmount/LTV"] = {}
                  end
                  # FICO x LTV
                  if r >= 82 && r <= 89 && cc == 5
                    primary_key = get_value value
                    @adjustment_hash["FICO/LTV"][primary_key] = {}
                  end
                  if r >= 82 && r <= 89 && cc >= 7 && cc <= 12
                    secondary_key = @ltv_data[cc-3]*100
                    @adjustment_hash["FICO/LTV"][primary_key][secondary_key] = {}
                    @adjustment_hash["FICO/LTV"][primary_key][secondary_key] = value
                  end

                  if r >= 82 && r <= 89 && cc == 5
                    primary_key = get_value value
                    @adjustment_hash["FICO/LTV"][primary_key] = {}
                  end
                  if r >= 82 && r <= 89 && cc >= 7 && cc <= 12
                    secondary_key = @ltv_data[cc-3]*100
                    @adjustment_hash["FICO/LTV"][primary_key][secondary_key] = {}
                    @adjustment_hash["FICO/LTV"][primary_key][secondary_key] = value
                  end

                  if r == 93 && cc == 5
                    @other_adjustment["ArmBasic/LTV"] = {}
                    @other_adjustment["ArmBasic/LTV"]["5/1 ARM"] = {}
                  end
                  if r ==93 && cc >= 7 && cc <= 12
                    secondary_key = @ltv_data[cc-3]*100
                    @other_adjustment["ArmBasic/LTV"]["5/1 ARM"][secondary_key] = {}
                    @other_adjustment["ArmBasic/LTV"]["5/1 ARM"][secondary_key] = value
                  end

                  if r >= 94 && r <= 98 && cc == 5
                    primary_key = get_value value
                    @other_adjustment1["LoanAmount/LTV"][primary_key] = {}
                  end
                  if r >= 94 && r <= 98 && cc >= 7 && cc <= 12
                    secondary_key = @ltv_data[cc-3]*100
                    @other_adjustment1["LoanAmount/LTV"][primary_key][secondary_key] = {}
                    @other_adjustment1["LoanAmount/LTV"][primary_key][secondary_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash, @other_adjustment, @other_adjustment1]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def fha_buydown_fixed_rate_products
    @xlsx.sheets.each do |sheet|
      if (sheet == "FHA BUYDOWN FIXED RATE PRODUCTS")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @other_adjustment = {}
        @other_adjustment1 = {}
        primary_key = ''
        secondary_key = ''
        ltv_key = ''

        #program
        (51..93).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              @title = sheet_data.cell(r,cc)
              if @title.present?
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @term = program_property @title
                p_name = @title + sheet
                    @program.update_fields p_name
                @programs_ids << @program.id

                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    begin
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][15*c_i] = value
                        end

                        @data << value
                      end
                    rescue Exception => e
                      error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
                      error_log.save
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              end
            end
          end
        end

        # Adjustments
        (101..120).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(104)
          if row.compact.count >= 1
            (0..19).each do |cc|
              value = sheet_data.cell(r,cc)
              begin
                if value.present?
                  if value == "FICO - Loan Amount "
                    @adjustment_hash["FICO/LoanAmount"] = {}
                    @other_adjustment["MiscAdjuster"] = {}
                    @other_adjustment1["LoanAmount"] = {}
                  end
                  # FICO - Loan Amount
                  if r >= 105 && r <= 110 && cc == 5
                    secondary_key = get_value value
                    @adjustment_hash["FICO/LoanAmount"][secondary_key] = {}
                  end

                  if r >= 105 && r <= 110 && cc > 5 && cc <= 8
                    if @ltv_data[cc-1].include?('k')
                      ltv_key = get_value @ltv_data[cc-1]
                      ltv_key = get_value @ltv_data[cc-1] + "000"
                    end
                    @adjustment_hash["FICO/LoanAmount"][secondary_key][ltv_key] = {}
                    @adjustment_hash["FICO/LoanAmount"][secondary_key][ltv_key] = value
                  end

                  # Other Adjustments
                  if r == 115 && cc == 14
                    primary_key = "Escrow Waiver Fee"
                    @other_adjustment["MiscAdjuster"][primary_key] = {}
                    cc = cc + 4
                    new_value = sheet_data.cell(r,cc)
                    @other_adjustment["MiscAdjuster"][primary_key] = new_value
                  end

                  if r == 116 && cc == 14
                    primary_key = value.split("<$").last
                    if primary_key.include?(",")
                      primary_key = primary_key.tr(',', '')
                    end
                    @other_adjustment1["LoanAmount"]["0-"+primary_key] = {}
                    cc = cc + 4
                    new_value = sheet_data.cell(r,cc)
                    @other_adjustment1["LoanAmount"]["0-"+primary_key] = new_value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash, @other_adjustment, @other_adjustment1]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def fha_fixed_arm_products
    @xlsx.sheets.each do |sheet|
      if (sheet == "FHA FIXED ARM PRODUCTS")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []

        #program
        (51..115).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              @title = sheet_data.cell(r,cc)
                begin
                  @title = sheet_data.cell(r,cc)
                  if @title.present?
                    @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                    @term = program_property @title
                    p_name = @title + sheet
                    @program.update_fields p_name
                    @programs_ids << @program.id
                  end

                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                rescue Exception => e
                  error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                  error_log.save
                end

                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    begin
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][15*c_i] = value
                        end
                        @data << value
                      end
                    rescue Exception => e
                      error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                      error_log.save
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
            end
          end
        end
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def fannie_mae_homeready_products
    @xlsx.sheets.each do |sheet|
      if (sheet == "FANNIE MAE HOMEREADY PRODUCTS")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @price_adjustment = {}
        @family_adjustment = {}
        @high_adjustment = {}
        ltv_key = ''
        secondary_key = ''
        primary_key = ''
        ltv_key1 = ''
        secondary_key1 = ''
        primary_key1 = ''
        #program
        (51..92).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && @title != "5/1 CMT ARM 1/1/5 VA"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @term = program_property @title
                  p_name = @title + sheet
                    @program.update_fields p_name
                  @programs_ids << @program.id

                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..4).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][15*c_i] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                    @block_hash.shift
                  end
                  @program.update(base_rate: @block_hash,loan_category: sheet)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Adjustments
        (101..128).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(104)
          @cltv_data = sheet_data.row(114)
          (0..16).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == " Price Adjustments"
                  primary_key = "FICO/LTV"
                  @price_adjustment[primary_key] = {}
                end
                if value == "Multi Family 2- 4 Unit LTV/FICO Adjusters"
                  @family_adjustment["PropertyType/FICO/LTV"] = {}
                  @family_adjustment["PropertyType/FICO/LTV"]["2-4 Unit"] = {}
                end
                if value == "Condo LTV/FICO Adjusters"
                  @family_adjustment["PropertyType/FICO/LTV"]["Condo"] = {}
                end
                if value == "HIGH BALANCE"
                  @high_adjustment["LoanSize/LoanType/LTV"] = {}
                  @high_adjustment["LoanSize/LoanType/LTV"]["High-Balance"] = {}
                  @high_adjustment["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"] = {}
                  @high_adjustment["LoanType/RefinanceOption"] = {}
                  @high_adjustment["LoanType/RefinanceOption"]["Fixed"] = {}
                  @high_adjustment["LoanType/RefinanceOption"]["ARM"] = {}
                end
                if r >= 105 && r <= 112 && cc == 7
                  secondary_key = get_value value
                  @price_adjustment[primary_key][secondary_key] = {}
                end
                if r >= 105 && r <= 112 && cc > 7 && cc <= 112
                  ltv_key = get_value @ltv_data[cc-1]
                  if ltv_key.include?("%")
                    ltv_key = ltv_key.tr('% ','')
                  else
                    ltv_key
                  end
                  @price_adjustment[primary_key][secondary_key][ltv_key] = {}
                  @price_adjustment[primary_key][secondary_key][ltv_key] = value
                end
                # Multi Family 2- 4 Unit LTV/FICO Adjusters
                if r >= 115 && r <= 122 && cc == 6
                  ltv_key = get_value value
                  @family_adjustment["PropertyType/FICO/LTV"]["2-4 Unit"][ltv_key] = {}
                end
                if r >= 115 && r <= 122 && cc > 6 && cc <= 10
                  cltv_key = get_value @cltv_data[cc-1]
                  if cltv_key.include?("%")
                    cltv_key = cltv_key.tr('% ','')
                  else
                    cltv_key
                  end
                  @family_adjustment["PropertyType/FICO/LTV"]["2-4 Unit"][ltv_key][cltv_key] = {}
                  @family_adjustment["PropertyType/FICO/LTV"]["2-4 Unit"][ltv_key][cltv_key] = value
                end
                # Condo LTV/FICO Adjusters
                if r >= 115 && r <= 122 && cc == 12
                  ltv_key1 = get_value value
                  @family_adjustment["PropertyType/FICO/LTV"]["Condo"][ltv_key1] = {}
                end
                if r >= 115 && r <= 122 && cc > 12 && cc <= 16
                  cltv_key1 = get_value @cltv_data[cc-1]
                  if cltv_key1.include?("%")
                    cltv_key1 = cltv_key1.tr('% ','')
                  else
                    cltv_key1
                  end
                  @family_adjustment["PropertyType/FICO/LTV"]["Condo"][ltv_key1][cltv_key1] = {}
                  @family_adjustment["PropertyType/FICO/LTV"]["Condo"][ltv_key1][cltv_key1] = value
                end
                # HIGH BALANCE
                if r >= 124 && r <= 126 && cc == 9
                  if value.include?("LTV/CLTV >75% <=90%")
                    ltv_key = value.tr('A-Z/%>< ','').tr('=','-')
                  else
                    ltv_key = get_value value
                  end
                  @high_adjustment["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"][ltv_key] = {}
                  cc = cc + 4
                  new_val = sheet_data.cell(r,cc)
                  @high_adjustment["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"][ltv_key] = new_val
                end
                if r == 127 && cc == 9
                  ltv_key = "Rate and Term"
                  @high_adjustment["LoanType/RefinanceOption"]["Fixed"][ltv_key] = {}
                  @high_adjustment["LoanType/RefinanceOption"]["ARM"][ltv_key] = {}
                  cc = cc + 4
                  new_val = sheet_data.cell(r,cc)
                  @high_adjustment["LoanType/RefinanceOption"]["Fixed"][ltv_key] = new_val
                  @high_adjustment["LoanType/RefinanceOption"]["ARM"][ltv_key] = new_val
                end
                if r == 128 && cc == 9
                  ltv_key = "Cash Out"
                  @high_adjustment["LoanType/RefinanceOption"]["Fixed"][ltv_key] = {}
                  @high_adjustment["LoanType/RefinanceOption"]["ARM"][ltv_key] = {}
                  cc = cc + 4
                  new_val = sheet_data.cell(r,cc)
                  @high_adjustment["LoanType/RefinanceOption"]["Fixed"][ltv_key] = new_val
                  @high_adjustment["LoanType/RefinanceOption"]["ARM"][ltv_key] = new_val
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@price_adjustment,@family_adjustment,@high_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def fnma_buydown_products
    @xlsx.sheets.each do |sheet|
      if (sheet == "FNMA BUYDOWN PRODUCTS")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        range1 = 101
        range2 = 131
        @other_adjustment = {}
        @secondary_hash = {}
        primary_key = ''
        ltv_key = ''
        cltv_key = ''
        ltv_data = ''

        #program
        (51..93).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              @title = sheet_data.cell(r,cc)
                begin
                  @title = sheet_data.cell(r,cc)
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @term = program_property @title
                  p_name = @title + sheet
                    @program.update_fields p_name
                  @programs_ids << @program.id

                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                rescue Exception => e
                  error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                  error_log.save
                end

                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    begin
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][15*c_i] = value
                        end
                        @data << value
                      end
                    rescue Exception => e
                      error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
                      error_log.save
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
              if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                @block_hash.shift
              end
              @program.update(base_rate: @block_hash,loan_category: sheet)
            end
          end
        end

        # Adjustments
        (range1..range2).each do |r|
          @ltv_data = sheet_data.row(117)
          (0..sheet_data.last_column).each do |cc|
            value = sheet_data.cell(r,cc)
            if value.present?
              if value == "LTV / FICO (Terms > 15 years only)"
                first_row = 105
                end_row = 108
                last_column = 13
                first_column = 5
                ltv_row = 104
                num = 3
                ltv_adjustment range1, range2, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row,num
              end
              # Loans With Secondary Financing
              if value == "Loans With Secondary Financing"
                primary_key = "LTV/CLTV/FICO"
                @secondary_hash[primary_key] = {}
              end
              if r >= 118 && r <= 122 && cc == 4
                ltv_key = get_value value
                @secondary_hash[primary_key][ltv_key] = {}
              end
              if r >= 118 && r <= 122 && cc == 5
                cltv_key = get_value value
                @secondary_hash[primary_key][ltv_key][cltv_key] = {}
              end
              if r >= 118 && r <= 122 && cc > 5 && cc <= 7
                ltv_data = get_value @ltv_data[cc-3]
                ltv_data = ltv_data.tr(')( ','')
                @secondary_hash[primary_key][ltv_key][cltv_key][ltv_data] = {}
                @secondary_hash[primary_key][ltv_key][cltv_key][ltv_data] = value
              end
              # Other Adjustments
              if r == 108 && cc == 15
                @other_adjustment["PropertyType"] = {}
                @other_adjustment["PropertyType"]["2-4 Unit"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType"]["2-4 Unit"] = new_value
              end
              if r == 109 && cc == 15
                @other_adjustment["PropertyType/Term/LTV"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_value
              end
              if r == 110 && cc == 15
                @other_adjustment["LoanSize/RefinanceOption"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = new_value
              end
              if r == 111 && cc == 15
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Rate and Term"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Rate and Term"] = new_value
              end
              if r == 130 && cc == 14
                @other_adjustment["MiscAdjuster"] = {}
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = new_value
              end
              if r == 131 && cc == 14
                @other_adjustment["LoanAmount"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["0-150000"] = new_value
              end
              if value == "LTV / FICO (Terms > 15 years only)"
                first_row = 105
                end_row = 108
                last_column = 13
                first_column = 5
                ltv_row = 104
                num = 3
                ltv_adjustment range1, range2, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row,num
              end
              # Loans With Secondary Financing
              if value == "Loans With Secondary Financing"
                primary_key = "LTV/CLTV/FICO"
                @secondary_hash[primary_key] = {}
              end
              if r >= 118 && r <= 122 && cc == 4
                ltv_key = get_value value
                @secondary_hash[primary_key][ltv_key] = {}
              end
              if r >= 118 && r <= 122 && cc == 5
                cltv_key = get_value value
                @secondary_hash[primary_key][ltv_key][cltv_key] = {}
              end
              if r >= 118 && r <= 122 && cc > 5 && cc <= 7
                ltv_data = get_value @ltv_data[cc-3]
                ltv_data = ltv_data.tr(')( ','')
                @secondary_hash[primary_key][ltv_key][cltv_key][ltv_data] = {}
                @secondary_hash[primary_key][ltv_key][cltv_key][ltv_data] = value
              end
              # Other Adjustments
              if r == 108 && cc == 15
                @other_adjustment["PropertyType"] = {}
                @other_adjustment["PropertyType"]["2-4 Unit"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType"]["2-4 Unit"] = new_value
              end
              if r == 109 && cc == 15
                @other_adjustment["PropertyType/Term/LTV"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_value
              end
              if r == 110 && cc == 15
                @other_adjustment["LoanSize/RefinanceOption"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = new_value
              end
              if r == 111 && cc == 15
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Rate and Term"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Rate and Term"] = new_value
              end
              if r == 130 && cc == 14
                @other_adjustment["MiscAdjuster"] = {}
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = new_value
              end
              if r == 131 && cc == 14
                @other_adjustment["LoanAmount"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["0-150000"] = new_value
              end
            end
          end
        end
        adjustment = [@secondary_hash,@other_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def fnma_conventional_fixed_rate
    @xlsx.sheets.each do |sheet|
      if (sheet == "FNMA Conventional Fixed Rate")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        range1 = 137
        range2 = 178
        @cashout_hash = {}
        @lpmi_hash = {}
        @other_adjustment = {}
        @secondary_hash = {}
        primary_key = ''
        ltv_key = ''
        cltv_key = ''
        ltv_data = ''

        #program
        (51..93).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              @title = sheet_data.cell(r,cc)
              if @title.present?
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @term = program_property @title
                p_name = @title + sheet
                    @program.update_fields p_name
                @programs_ids << @program.id
              end

              @program.adjustments.destroy_all
              @block_hash = {}
              key = ''
              (1..50).each do |max_row|
                @data = []
                (0..4).each_with_index do |index, c_i|
                  rrr = rr + max_row
                  ccc = cc + c_i
                  value = sheet_data.cell(rrr,ccc)
                  if value.present?
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    else
                      @block_hash[key][15*c_i] = value
                    end
                    @data << value
                  end
                end
                if @data.compact.reject { |c| c.blank? }.length == 0
                  break # terminate the loop
                end
              end
              if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                @block_hash.shift
              end
              @program.update(base_rate: @block_hash,loan_category: sheet)
            end
          end
        end

        # Adjustments
        (range1..range2).each do |r|
          @ltv_data = sheet_data.row(153)
          @lpmi_data = sheet_data.row(166)
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value == "LTV / FICO (Terms > 15 years only)"
                first_row = 141
                end_row = 147
                last_column = 12
                first_column = 4
                ltv_row = 140
                num = 1
                ltv_adjustment range1, range2, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row,num
              end
              if value == "Cash Out Refinance"
                @cashout_hash["RefinanceOption/FICO/LTV"] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
              end
              if value == "LPMI Single Premium Rate Card"
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["20-Inf"] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["0-20"] = {}
              end
              # Cash Out Refinance
              if r >= 154 && r <= 160 && cc == 4
                primary_key = get_value value
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
              end
              if r >= 154 && r <= 160 && cc >= 5 && cc <= 8
                ltv_key = get_value @ltv_data[cc-1]
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = value
              end
              # LPMI Single Premium Rate Card
              if r >= 167 && r <= 170 && cc == 2
                if value.include?("below")
                  primary_key = "0-"+value.tr('a-z% ','')
                else
                  primary_key = value.sub('to','-').tr('% ','')
                end
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["20-Inf"][primary_key] = {}
              end
              if r >= 167 && r <= 170 && cc >= 5 && cc <= 11
                ltv_key = get_value @lpmi_data[cc-1]
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["20-Inf"][primary_key][ltv_key] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["20-Inf"][primary_key][ltv_key] = value
              end
              if r >= 173 && r <= 176 && cc == 2
                if value.include?("below")
                  primary_key = "0-"+value.tr('a-z% ','')
                else
                  primary_key = value.sub('to','-').tr('% ','')
                end
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["0-20"][primary_key] = {}
              end
              if r >= 173 && r <= 176 && cc >= 5 && cc <= 11
                ltv_key = get_value @lpmi_data[cc-1]
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["0-20"][primary_key][ltv_key] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["0-20"][primary_key][ltv_key] = value
              end
              if r == 178 && cc == 2
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"]["2nd Home"] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"]["2nd Home"]["Rate and Term"] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"]["2nd Home"]["Rate and Term"]["0-20"] = {}
              end
              if r == 178 && cc >= 5 && cc <= 11
                ltv_key = get_value @lpmi_data[cc-1]
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"]["2nd Home"]["Rate and Term"]["0-20"][ltv_key] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"]["2nd Home"]["Rate and Term"]["0-20"][ltv_key] = value
              end
              # Other Adjustments
              if r == 141 && cc == 14
                @other_adjustment["PropertyType/LTV"] = {}
                @other_adjustment["PropertyType/LTV"]["Investment Property"] = {}
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["0-75"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["0-75"] = {}
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["0-75"] = new_value
              end
              if r == 142 && cc == 14
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["75-80"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["75-80"] = {}
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["75-80"] = new_value
              end
              if r == 143 && cc == 14
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["80-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["80-Inf"] = {}
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["80-Inf"] = new_value
              end
              if r == 144 && cc == 14
                @other_adjustment["PropertyType"] = {}
                @other_adjustment["PropertyType"]["2-4 Unit"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType"]["2-4 Unit"] = new_value
              end
              if r == 145 && cc == 14
                @other_adjustment["PropertyType/LTV/Term"] = {}
                @other_adjustment["PropertyType/LTV/Term"]["Condo"] = {}
                @other_adjustment["PropertyType/LTV/Term"]["Condo"]["75-Inf"] = {}
                @other_adjustment["PropertyType/LTV/Term"]["Condo"]["75-Inf"]["15-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV/Term"]["Condo"]["75-Inf"]["15-Inf"] = new_value
              end
              if r == 146 && cc == 14
                @other_adjustment["LoanSize/RefinanceOption"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = new_value
              end
              if r == 147 && cc == 14
                @other_adjustment["LoanSize/LoanType/RefinanceOption"] = {}
                @other_adjustment["LoanSize/LoanType/RefinanceOption"]["High-Balance"] = {}
                @other_adjustment["LoanSize/LoanType/RefinanceOption"]["High-Balance"]["ARM"] = {}
                @other_adjustment["LoanSize/LoanType/RefinanceOption"]["High-Balance"]["ARM"]["Rate and Term"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/LoanType/RefinanceOption"]["High-Balance"]["ARM"]["Rate and Term"] = new_value
              end
              if r == 166 && cc == 13
                @other_adjustment["MiscAdjuster"] = {}
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = new_value
              end
              if r == 167 && cc == 13
                @other_adjustment["LoanAmount"] = {}
                @other_adjustment["LoanAmount"]["150000"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["150000"] = new_value
              end
              if r == 168 && cc == 13
                @other_adjustment["LoanAmount"]["250000-Inf"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["250000-Inf"] = new_value
              end
              if r == 169 && cc == 13
                @other_adjustment["LoanAmount"]["200000-250000"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["200000-250000"] = new_value
              end
              if r == 170 && cc == 13
                primary_key = "FICO"
                secondary_key =  "0-680"
                if @other_adjustment[primary_key] = {}
                  cc = cc + 4
                  new_value = sheet_data.cell(r,cc)
                  @other_adjustment[primary_key][secondary_key] = new_value
                end
              end
              if r == 171 && cc == 13
                @other_adjustment["LoanAmount/State"] = {}
                @other_adjustment["LoanAmount/State"]["275000-Inf"] = {}
                @other_adjustment["LoanAmount/State"]["275000-Inf"]["CA"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount/State"]["275000-Inf"]["CA"] = new_value
              end
              if r == 172 && cc == 13
                @other_adjustment["LoanAmount/State"]["200000-275000"] = {}
                @other_adjustment["LoanAmount/State"]["200000-275000"]["CA"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount/State"]["200000-275000"]["CA"] = new_value
              end
              # Loans With Secondary Financing
              if value == "Loans With Secondary Financing"
                @secondary_hash["LTV/CLTV/FICO"] = {}
              end
              if r >= 154 && r <= 158 && cc == 12
                ltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key] = {}
              end
              if r >= 154 && r <= 158 && cc == 13
                cltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key] = {}
              end
              if r >= 154 && r <= 158 && cc > 13 && cc <= 15
                ltv_data = get_value @ltv_data[cc-1]
                ltv_data = ltv_data.tr('() ','')
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = {}
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = value
                if r >= 154 && r <= 158 && cc > 13 && cc <= 15
                  ltv_data = get_value @ltv_data[cc-1]
                  ltv_data = ltv_data.tr('() ','')
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = {}
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = value
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@cashout_hash,@lpmi_hash,@secondary_hash,@other_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def fnma_conventional_high_balance
    @xlsx.sheets.each do |sheet|
      if (sheet == "FNMA Conventional High Balance")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        range1 = 137
        range2 = 184
        @cashout_hash = {}
        @lpmi_hash = {}
        @other_adjustment = {}
        @secondary_hash = {}
        primary_key = ''
        ltv_key = ''
        cltv_key = ''
        ltv_data = ''

        #program
        (51..93).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              @title = sheet_data.cell(r,cc)
                begin
                  @title = sheet_data.cell(r,cc)
                  if @title.present?
                    @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                    @term = program_property @title
                    p_name = @title + sheet
                    @program.update_fields p_name
                    @programs_ids << @program.id
                  end
                  @program.adjustments.destroy_all
                rescue Exception => e
                  error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                  error_log.save
                end
              @program.adjustments.destroy_all
              @block_hash = {}
              key = ''
              (1..50).each do |max_row|
                @data = []
                (0..4).each_with_index do |index, c_i|
                  rrr = rr + max_row
                  ccc = cc + c_i
                  begin
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      else
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  rescue Exception => e
                    error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                    error_log.save
                  end
                end
                if @data.compact.reject { |c| c.blank? }.length == 0
                  break # terminate the loop
                end
              end
              if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                @block_hash.shift
              end
              @program.update(base_rate: @block_hash,loan_category: sheet)
            end
          end
        end

        # Adjustments
        (range1..range2).each do |r|
          @ltv_data = sheet_data.row(153)
          @lpmi_data = sheet_data.row(172)
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value == "LTV / FICO (Terms > 15 years only)"
                first_row = 141
                end_row = 147
                last_column = 12
                first_column = 4
                ltv_row = 140
                num = 1
                ltv_adjustment range1, range2, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row,num
              end
              # Cash Out Refinance
              if value == "Cash Out Refinance"
                @cashout_hash["RefinanceOption/FICO/LTV"] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
              end
              # LPMI Single Premium Rate Card
              if value == "LPMI Single Premium Rate Card"
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["20-Inf"] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["0-20"] = {}
              end
              # Cash Out Refinance
              if r >= 154 && r <= 160 && cc == 4
                primary_key = get_value value
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
              end
              if r >= 154 && r <= 160 && cc >= 5 && cc <= 8
                ltv_key = get_value @ltv_data[cc-1]
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = value
              end
              # LPMI Single Premium Rate Card
              if r >= 173 && r <= 176 && cc == 2
                if value.include?("below")
                  primary_key = "0-"+value.tr('a-z% ','')
                else
                  primary_key = value.sub('to','-').tr('% ','')
                end
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["20-Inf"][primary_key] = {}
              end
              if r >= 173 && r <= 176 && cc >= 5 && cc <= 11
                ltv_key = get_value @lpmi_data[cc-1]
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["20-Inf"][primary_key][ltv_key] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["20-Inf"][primary_key][ltv_key] = value
              end
              if r >= 179 && r <= 182 && cc == 2
                if value.include?("below")
                  primary_key = "0-"+value.tr('a-z% ','')
                else
                  primary_key = value.sub('to','-').tr('% ','')
                end
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["0-20"][primary_key] = {}
              end
              if r >= 179 && r <= 182 && cc >= 5 && cc <= 11
                ltv_key = get_value @lpmi_data[cc-1]
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["0-20"][primary_key][ltv_key] = {}
                @lpmi_hash["LPMI/LoanType/RefinanceOption/Term/LTV/FICO"]["true"]["Fixed"]["Rate and Term"]["0-20"][primary_key][ltv_key] = value
              end
              if r == 184 && cc == 2
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"]["2nd Home"] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"]["2nd Home"]["Rate and Term"] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"]["2nd Home"]["Rate and Term"]["0-20"] = {}
              end
              if r == 184 && cc >= 5 && cc <= 11
                ltv_key = get_value @lpmi_data[cc-1]
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"]["2nd Home"]["Rate and Term"]["0-20"][ltv_key] = {}
                @lpmi_hash["LPMI/LoanType/PropertyType/RefinanceOption/Term/FICO"]["true"]["Fixed"]["2nd Home"]["Rate and Term"]["0-20"][ltv_key] = value
              end
              # Other Adjustments
              if r == 141 && cc == 14
                @other_adjustment["PropertyType/LTV"] = {}
                @other_adjustment["PropertyType/LTV"]["Investment Property"] = {}
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["0-75"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["0-75"] = new_value
              end

              if r == 142 && cc == 14
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["75-80"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["75-80"] = new_value
              end
              if r == 143 && cc == 14
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["80-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["80-Inf"] = new_value
              end
              if r == 144 && cc == 14
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["2-4 Unit"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["2-4 Unit"] = new_value
              end
              if r == 145 && cc == 14
                @other_adjustment["PropertyType/LTV/Term"] = {}
                @other_adjustment["PropertyType/LTV/Term"]["Condo"] = {}
                @other_adjustment["PropertyType/LTV/Term"]["Condo"]["75-Inf"] = {}
                @other_adjustment["PropertyType/LTV/Term"]["Condo"]["75-Inf"]["15-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV/Term"]["Condo"]["75-Inf"]["15-Inf"] = new_value
              end
              if r == 146 && cc == 14
                @other_adjustment["LoanSize/RefinanceOption"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = new_value
              end
              if r == 147 && cc == 14
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Rate and Term"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Rate and Term"] = new_value
              end
              if r == 166 && cc == 14
                @other_adjustment["MiscAdjuster"] = {}
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = new_value
              end
              if r == 167 && cc == 14
                @other_adjustment["LoanAmount"] = {}
                @other_adjustment["LoanAmount"]["0-150000"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["0-150000"] = new_value
              end
              if r == 168 && cc == 14
                @other_adjustment["LoanAmount"]["300000-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["300000-Inf"] = new_value
              end
              if r == 169 && cc == 14
                @other_adjustment["LoanAmount"]["200000-300000"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["200000-300000"] = new_value
              end
              if r == 170 && cc == 14
                primary_key = "FICO"
                secondary_key =  "640-679"
                if @other_adjustment[primary_key] = {}
                  cc = cc + 1
                  new_value = sheet_data.cell(r,cc)
                  @other_adjustment[primary_key][secondary_key] = new_value
                end
              end
              # Loans With Secondary Financing
              if value == "Loans With Secondary Financing"
                @secondary_hash["LTV/CLTV/FICO"] = {}
              end
              if r >= 154 && r <= 158 && cc == 12
                ltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key] = {}
              end
              if r >= 154 && r <= 158 && cc == 13
                cltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key] = {}
              end
              if r >= 154 && r <= 158 && cc > 13 && cc <= 15
                ltv_data = get_value @ltv_data[cc-1]
                ltv_data = ltv_data.tr('() ','')
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = {}
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = value
                # Loans With Secondary Financing
                if value == "Loans With Secondary Financing"
                  @secondary_hash["LTV/CLTV/FICO"] = {}
                end
                if r >= 154 && r <= 158 && cc == 12
                  ltv_key = get_value value
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key] = {}
                end
                if r >= 154 && r <= 158 && cc == 13
                  cltv_key = get_value value
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key] = {}
                end
                if r >= 154 && r <= 158 && cc > 13 && cc <= 15
                  ltv_data = get_value @ltv_data[cc-1]
                  ltv_data = ltv_data.tr('() ','')
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = {}
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = value
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@cashout_hash,@secondary_hash,@other_adjustment,@lpmi_hash]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def fnma_conventional_arm
    @xlsx.sheets.each do |sheet|
      if (sheet == "FNMA Conventional Arm")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        range1 = 137
        range2 = 171
        @cashout_hash = {}
        @other_adjustment = {}
        @secondary_hash = {}
        primary_key = ''
        ltv_key = ''
        cltv_key = ''
        ltv_data = ''

        #program
        (51..93).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              @title = sheet_data.cell(r,cc)
                begin
                  if @title.present?
                    @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                    @term = program_property @title
                    p_name = @title + sheet
                    @program.update_fields p_name
                    @programs_ids << @program.id
                  end

                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  lock_hash = {}
                rescue Exception => e
                  error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                  error_log.save
                end
              @program.adjustments.destroy_all
              @block_hash = {}
              key = ''
              lock_hash = {}
              (1..50).each do |max_row|
                @data = []
                (0..4).each_with_index do |index, c_i|
                  rrr = rr + max_row
                  ccc = cc + c_i
                  begin
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      else
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  rescue Exception => e
                    error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
                    error_log.save
                  end
                end
                if @data.compact.reject { |c| c.blank? }.length == 0
                  break # terminate the loop
                end
              end
              if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                @block_hash.shift
              end
              @program.update(base_rate: @block_hash,loan_category: sheet)
            end
          end
        end

        # Adjustments
        (range1..range2).each do |r|
          @ltv_data = sheet_data.row(154)
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value == "LTV / FICO (Terms > 15 years only)"
                first_row = 141
                end_row = 147
                last_column = 12
                first_column = 4
                ltv_row = 140
                num = 1
                ltv_adjustment range1, range2, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row,num
              end
              # Cash out Refinance
              if value == "Cash out Refinance"
                @cashout_hash["RefinanceOption/FICO/LTV"] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
              end
              # Cash Out Refinance
              if r >= 155 && r <= 161 && cc == 4
                primary_key = get_value value
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
              end
              if r >= 155 && r <= 161 && cc >= 5 && cc <= 8
                ltv_key = get_value @ltv_data[cc-1]
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = value
              end
              # Other Adjustments
              if r == 141 && cc == 14
                @other_adjustment["PropertyType/LTV"] = {}
                @other_adjustment["PropertyType/LTV"]["Investment Property"] = {}
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["0-75"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["0-75"] = new_value
              end
              if r == 142 && cc == 14
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["75-80"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["75-80"] = new_value
              end
              if r == 143 && cc == 14
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["80-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/LTV"]["Investment Property"]["80-Inf"] = new_value
              end
              if r == 144 && cc == 14
                @other_adjustment["PropertyType"] = {}
                @other_adjustment["PropertyType"]["2-4 Unit"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType"]["2-4 Unit"] = new_value
              end
              if r == 145 && cc == 14
                @other_adjustment["PropertyType/Term/LTV"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_value
              end
              if r == 146 && cc == 14
                @other_adjustment["LoanSize/RefinanceOption"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = new_value
              end
              if r == 147 && cc == 14
                @other_adjustment["LoanSize/LoanType/LTV"] = {}
                @other_adjustment["LoanSize/LoanType/LTV"]["High-Balance"] = {}
                @other_adjustment["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"] = {}
                @other_adjustment["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"]["0-75"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"]["0-75"] = new_value
              end
              if r == 148 && cc == 14
                @other_adjustment["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"]["75-90"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"]["75-90"] = new_value
              end
              if r == 149 && cc == 14
                @other_adjustment["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"]["90-95"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"]["90-95"] = new_value
              end
              if r == 150 && cc == 14
                @other_adjustment["LoanSize/RefinanceOption"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Rate and Term"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Rate and Term"] = new_value
              end
              if r == 165 && cc == 12
                @other_adjustment["MiscAdjuster"] = {}
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = new_value
              end
              if r == 166 && cc == 12
                @other_adjustment["LoanAmount"] = {}
                @other_adjustment["LoanAmount"]["0-150000"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["0-150000"] = new_value
              end
              if r == 167 && cc == 12
                @other_adjustment["LoanAmount"]["250000-Inf"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["250000-Inf"] = new_value
              end
              if r == 168 && cc == 12
                @other_adjustment["LoanAmount"]["200000-250000"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["200000-250000"] = new_value
              end
              if r == 169 && cc == 12
                primary_key = "FICO"
                secondary_key =  "0-680"
                if @other_adjustment[primary_key] = {}
                  cc = cc + 4
                  new_value = sheet_data.cell(r,cc)
                  @other_adjustment[primary_key][secondary_key] = new_value
                end
              end
              if r == 170 && cc == 12
                @other_adjustment["LoanAmount/State"] = {}
                @other_adjustment["LoanAmount/State"]["275000-Inf"] = {}
                @other_adjustment["LoanAmount/State"]["275000-Inf"]["CA"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount/State"]["275000-Inf"]["CA"] = new_value
              end
              if r == 171 && cc == 12
                @other_adjustment["LoanAmount/State"]["200000-275000"] = {}
                cc = cc + 4
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount/State"]["200000-275000"] = new_value
              end

              # Loans With Secondary Financing
              if value == "Loan With Secondary Financing"
                @secondary_hash["LTV/CLTV/FICO"] = {}
              end
              if r >= 155 && r <= 159 && cc == 12
                ltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key] = {}
              end
              if r >= 155 && r <= 159 && cc == 13
                cltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key] = {}
              end
              if r >= 155 && r <= 159 && cc > 13 && cc <= 15
                ltv_data = get_value @ltv_data[cc-1]
                ltv_data = ltv_data.tr('() ','')
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = {}
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = value
                # Loans With Secondary Financing
                if value == "Loan With Secondary Financing"
                  @secondary_hash["LTV/CLTV/FICO"] = {}
                end
                if r >= 155 && r <= 159 && cc == 12
                  ltv_key = get_value value
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key] = {}
                end
                if r >= 155 && r <= 159 && cc == 13
                  cltv_key = get_value value
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key] = {}
                end
                if r >= 155 && r <= 159 && cc > 13 && cc <= 15
                  ltv_data = get_value @ltv_data[cc-1]
                  ltv_data = ltv_data.tr('() ','')
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = {}
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = value
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@secondary_hash,@cashout_hash,@other_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def olympic_piggyback_fixed
    @xlsx.sheets.each do |sheet|
      if (sheet == "Olympic PiggyBack Fixed")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        range1 = 137
        range2 = 174
        @cashout_hash = {}
        @other_adjustment = {}
        @secondary_hash = {}
        @property_hash = {}
        primary_key = ''
        ltv_key = ''
        cltv_key = ''
        ltv_data = ''

        #program
        (51..93).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              @title = sheet_data.cell(r,cc)
                begin
                  @title = sheet_data.cell(r,cc)
                  if @title.present?
                    @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                    @term = program_property @title
                    p_name = @title + sheet
                    @program.update_fields p_name
                    @programs_ids << @program.id
                  end

                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                rescue Exception => e
                  error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                  error_log.save
                end

              @program.adjustments.destroy_all
              @block_hash = {}
              key = ''
              (1..50).each do |max_row|
                @data = []
                (0..4).each_with_index do |index, c_i|
                  rrr = rr + max_row
                  ccc = cc + c_i
                  begin
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      else
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  rescue Exception => e
                    error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
                    error_log.save
                  end
                end
                if @data.compact.reject { |c| c.blank? }.length == 0
                  break # terminate the loop
                end
              end
              if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                @block_hash.shift
              end
              @program.update(base_rate: @block_hash,loan_category: sheet)
            end
          end
        end

        # Adjustments
        (range1..range2).each do |r|
          @ltv_data = sheet_data.row(154)
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value == "LTV / FICO (Terms > 15 years only)"
                first_row = 141
                end_row = 144
                last_column = 8
                first_column = 4
                ltv_row = 140
                num = 1
                ltv_adjustment range1, range2, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row,num
              end
              if value == "Cash Out Refinance"
                @cashout_hash["RefinanceOption/FICO/LTV"] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                @property_hash["LoanType/CLTV"] = {}
                @property_hash["LoanType/CLTV"]["Fixed"] = {}
              end
              # Cash Out Refinance
              if r >= 155 && r <= 158 && cc == 4
                primary_key = get_value value
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
              end
              if r >= 155 && r <= 158 && cc >= 5 && cc <= 8
                ltv_key = get_value @ltv_data[cc-1]
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = value
              end
              # OLYMPIC FIXED 2ND MORTGAGE
              if r == 168 && cc == 4
                @property_hash["LoanType/RefinanceOption/LoanAmount"] = {}
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"] = {}
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"]["Cash Out"] = {}
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"]["Cash Out"]["100000"] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"]["Cash Out"]["100000"] = new_val
              end
              if r == 169 && cc == 4
                @property_hash["LoanType/PropertyType"] = {}
                @property_hash["LoanType/PropertyType"]["Fixed"] = {}
                @property_hash["LoanType/PropertyType"]["Fixed"]["2nd Home"] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/PropertyType"]["Fixed"]["2nd Home"] = new_val
              end
              if r >= 170 && r <= 173 && cc == 4
                primary_key = value.tr('A-Z% ','')
                @property_hash["LoanType/CLTV"]["Fixed"][primary_key] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/CLTV"]["Fixed"][primary_key] = new_val
              end
              if r == 174 && cc == 4
                @property_hash["LoanType/Term"] = {}
                @property_hash["LoanType/Term"]["Fixed"] = {}
                @property_hash["LoanType/Term"]["Fixed"]["15"] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/Term"]["Fixed"]["15"] = new_val
              end
              # Other Adjustments
              if r == 146 && cc == 14
                @other_adjustment["PropertyType/Term/LTV"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_value
              end
              if r == 147 && cc == 14
                @other_adjustment["LoanSize/RefinanceOption"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = new_value
              end
              if r == 148 && cc == 14
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Rate and Term"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Rate and Term"] = new_value
              end
              # Loans With Secondary Financing
              if value == "Loans With Secondary Financing"
                @secondary_hash["LTV/CLTV/FICO"] = {}
              end

              if r >= 155 && r <= 158 && cc == 12
                ltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key] = {}
              end
              if r >= 155 && r <= 158 && cc == 13
                cltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key] = {}
              end
              if r >= 155 && r <= 158 && cc > 13 && cc <= 15
                ltv_data =  get_value @ltv_data[cc-1]
                ltv_data = ltv_data.tr('() ','')
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = {}
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = value
              end
              # Other Adjustments
              if r == 168 && cc == 12
                @other_adjustment["MiscAdjuster"] = {}
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = new_value
              end
              if r == 169 && cc == 12
                @other_adjustment["LoanAmount"] = {}
                @other_adjustment["LoanAmount"]["0-150000"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["0-150000"] = new_value
                if r >= 155 && r <= 158 && cc == 12
                  ltv_key = get_value value
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key] = {}
                end
                if r >= 155 && r <= 158 && cc == 13
                  cltv_key = get_value value
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key] = {}
                end
                if r >= 155 && r <= 158 && cc > 13 && cc <= 15
                  ltv_data =  get_value @ltv_data[cc-1]
                  ltv_data = ltv_data.tr('() ','')
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = {}
                  @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = value
                end
                # Other Adjustments
                if r == 168 && cc == 12
                  @other_adjustment["MiscAdjuster"] = {}
                  @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = {}
                  cc = cc + 1
                  new_value = sheet_data.cell(r,cc)
                  @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = new_value
                end
                if r == 169 && cc == 12
                  @other_adjustment["LoanAmount"] = {}
                  @other_adjustment["LoanAmount"]["0-150000"] = {}
                  cc = cc + 1
                  new_value = sheet_data.cell(r,cc)
                  @other_adjustment["LoanAmount"]["0-150000"] = new_value
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@secondary_hash,@cashout_hash,@other_adjustment,@property_hash]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def olympic_piggyback_high_balance
    @xlsx.sheets.each do |sheet|
      if (sheet == "Olympic PiggyBack High Balance")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        range1 = 137
        range2 = 172
        @cashout_hash = {}
        @other_adjustment = {}
        @secondary_hash = {}
        @property_hash = {}
        primary_key = ''
        ltv_key = ''
        cltv_key = ''
        ltv_data = ''
        #program
        (51..93).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              @title = sheet_data.cell(r,cc)
              if @title.present?
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @term = program_property @title
                p_name = @title + sheet
                    @program.update_fields p_name
                @programs_ids << @program.id
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    begin
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][15*c_i] = value
                        end
                        @data << value
                      end
                    rescue Exception => e
                      error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
                      error_log.save
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end                
                end
                if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              end
            end
          end
        end

        # Adjustments
        (range1..range2).each do |r|
          @ltv_data = sheet_data.row(153)
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value == "LTV / FICO (Terms > 15 years only)"
                first_row = 141
                end_row = 144
                last_column = 8
                first_column = 4
                ltv_row = 140
                num = 1
                ltv_adjustment range1, range2, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row,num
              end
              if value == "Cash Out Refinance"
                @cashout_hash["RefinanceOption/FICO/LTV"] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
              end
              if value == "OLYMPIC FIXED 2ND MORTGAGE"
                @property_hash["LoanType/CLTV"] = {}
                @property_hash["LoanType/CLTV"]["Fixed"] = {}
              end
              # Cash Out Refinance
              if r >= 154 && r <= 157 && cc == 4
                primary_key = get_value value
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
              end
              if r >= 154 && r <= 157 && cc >= 5 && cc <= 8
                ltv_key = get_value @ltv_data[cc-1]
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = value
              end
              # OLYMPIC FIXED 2ND MORTGAGE
              if r == 166 && cc == 4
                @property_hash["LoanType/RefinanceOption/LoanAmount"] = {}
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"] = {}
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"]["Cash Out"] = {}
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"]["Cash Out"]["100000"] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"]["Cash Out"]["100000"] = new_val
              end
              if r == 167 && cc == 4
                @property_hash["LoanType/PropertyType"] = {}
                @property_hash["LoanType/PropertyType"]["Fixed"] = {}
                @property_hash["LoanType/PropertyType"]["Fixed"]["2nd Home"] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/PropertyType"]["Fixed"]["2nd Home"] = new_val
              end
              if r >= 168 && r <= 171 && cc == 4
                primary_key = value.tr('A-Z% ','')
                @property_hash["LoanType/CLTV"]["Fixed"][primary_key] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/CLTV"]["Fixed"][primary_key] = new_val
              end
              if r == 172 && cc == 4
                @property_hash["LoanType/Term"] = {}
                @property_hash["LoanType/Term"]["Fixed"] = {}
                @property_hash["LoanType/Term"]["Fixed"]["15"] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/Term"]["Fixed"]["15"] = new_val
              end
               # Other Adjustments
              if r == 145 && cc == 14
                @other_adjustment["PropertyType/Term/LTV"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_value
              end
              if r == 146 && cc == 14
                @other_adjustment["LoanSize/RefinanceOption"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = new_value
              end
              if r == 147 && cc == 14
                @other_adjustment["LoanSize/RefinanceOption"]["Rate and Term"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["Rate and Term"] = new_value
              end
              # Other Adjustments
              if r == 166 && cc == 12
                @other_adjustment["MiscAdjuster"] = {}
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = {}
                cc = cc + 1
                new_val = sheet_data.cell(r,cc)
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = new_val
              end
              if r == 167 && cc == 12
                @other_adjustment["LoanAmount"] = {}
                @other_adjustment["LoanAmount"]["0-100000"] = {}
                cc = cc + 1
                new_val = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["0-100000"] = new_val
              end
              # Loans With Secondary Financing
              if value == "Loans With Secondary Financing"
                @secondary_hash["LTV/CLTV/FICO"] = {}
              end
              if r >= 154 && r <= 157 && cc == 12
                ltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key] = {}
              end
              if r >= 154 && r <= 157 && cc == 13
                cltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key] = {}
              end
              if r >= 154 && r <= 157 && cc > 13 && cc <= 15
                ltv_data = get_value @ltv_data[cc-1]
                ltv_data = ltv_data.tr('() ','')
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = {}
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = value
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@secondary_hash,@other_adjustment,@property_hash,@cashout_hash]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def olympic_piggyback_arm
    @xlsx.sheets.each do |sheet|
      if (sheet == "Olympic PiggyBack ARM")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        range1 = 139
        range2 = 175
        @cashout_hash = {}
        @other_adjustment = {}
        @secondary_hash = {}
        @property_hash = {}
        primary_key = ''
        ltv_key = ''
        cltv_key = ''
        ltv_data = ''
        #program
        (51..93).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + (3+max_column) # 3 / 9 / 15
              @title = sheet_data.cell(r,cc)
                begin
                  @title = sheet_data.cell(r,cc)
                  if @title.present?
                    @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                    @term = program_property @title
                    p_name = @title + sheet
                    @program.update_fields p_name
                    @programs_ids << @program.id
                  end

                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                rescue Exception => e
                  error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                  error_log.save
                end
              @program.adjustments.destroy_all
              @block_hash = {}
              key = ''
              (1..50).each do |max_row|
                @data = []
                (0..4).each_with_index do |index, c_i|
                  rrr = rr + max_row
                  ccc = cc + c_i
                  begin
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      else
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  rescue Exception => e
                    error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
                    error_log.save
                  end
                end
                if @data.compact.reject { |c| c.blank? }.length == 0
                  break # terminate the loop
                end
              end
              if @block_hash.keys.first.nil? || @block_hash.keys.first == "Rate"
                @block_hash.shift
              end
              @program.update(base_rate: @block_hash,loan_category: sheet)
            end
          end
        end
        # Adjustments

        (range1..range2).each do |r|
          @ltv_data = sheet_data.row(156)
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value == "LTV / FICO (Terms > 15 years only)"
                @other_adjustment["LoanType/LoanSize/LTV"] = {}
                @other_adjustment["LoanType/LoanSize/LTV"]["ARM"] = {}
                @other_adjustment["LoanType/LoanSize/LTV"]["ARM"]["High-Balance"] = {}
                first_row = 141
                end_row = 144
                last_column = 8
                first_column = 4
                ltv_row = 140
                num = 1
                ltv_adjustment range1, range2, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row,num
              end
              if value == "Cash Out Refinance"
                @cashout_hash["RefinanceOption/FICO/LTV"] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
              end
              if value == "OLYMPIC FIXED 2ND MORTGAGE"
                @property_hash["LoanType/CLTV"] = {}
                @property_hash["LoanType/CLTV"]["Fixed"] = {}
              end
              # Cash Out Refinance
              if r >= 157 && r <= 160 && cc == 4
                primary_key = get_value value
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
              end
              if r >= 157 && r <= 160 && cc >= 5 && cc <= 8
                ltv_key = get_value @ltv_data[cc-1]
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = {}
                @cashout_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][ltv_key] = value
              end
              # OLYMPIC FIXED 2ND MORTGAGE
              if r == 169 && cc == 4
                @property_hash["LoanType/RefinanceOption/LoanAmount"] = {}
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"] = {}
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"]["Cash Out"] = {}
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"]["Cash Out"]["100000"] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/RefinanceOption/LoanAmount"]["Fixed"]["Cash Out"]["100000"] = new_val
              end
              if r == 170 && cc == 4
                @property_hash["LoanType/PropertyType"] = {}
                @property_hash["LoanType/PropertyType"]["Fixed"] = {}
                @property_hash["LoanType/PropertyType"]["Fixed"]["2nd Home"] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/PropertyType"]["Fixed"]["2nd Home"] = new_val
              end
              if r >= 171 && r <= 174 && cc == 4
                primary_key = value.tr('A-Z% ','')
                @property_hash["LoanType/CLTV"]["Fixed"][primary_key] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/CLTV"]["Fixed"][primary_key] = new_val
              end
              if r == 175 && cc == 4
                @property_hash["LoanType/Term"] = {}
                @property_hash["LoanType/Term"]["Fixed"] = {}
                @property_hash["LoanType/Term"]["Fixed"]["15"] = {}
                cc = cc + 2
                new_val = sheet_data.cell(r,cc)
                @property_hash["LoanType/Term"]["Fixed"]["15"] = new_val
              end
              # Other Adjustments
              if r == 146 && cc == 14
                @other_adjustment["PropertyType/Term/LTV"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_value
              end
              if r == 147 && cc == 14
                @other_adjustment["LoanSize/RefinanceOption"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"] = {}
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = new_value
              end
              if r >= 148 && r <= 150 && cc == 14
                if value.include?("<=")
                  ltv_key = get_value value
                else
                  ltv_key = value.tr('A-Za-z%/ ','')
                end
                @other_adjustment["LoanType/LoanSize/LTV"]["ARM"]["High-Balance"][ltv_key] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanType/LoanSize/LTV"]["ARM"]["High-Balance"][ltv_key] = new_value
              end
              if r == 151 && cc == 14
                @other_adjustment["LoanType/LoanSize/RefinanceOption"] = {}
                @other_adjustment["LoanType/LoanSize/RefinanceOption"]["ARM"] = {}
                @other_adjustment["LoanType/LoanSize/RefinanceOption"]["ARM"]["High-Balance"] = {}
                @other_adjustment["LoanType/LoanSize/RefinanceOption"]["ARM"]["High-Balance"]["Rate and Term"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanType/LoanSize/RefinanceOption"]["ARM"]["High-Balance"]["Rate and Term"] = new_value
              end
              if r == 170 && cc == 12
                @other_adjustment["MiscAdjuster"] = {}
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["MiscAdjuster"]["Escrow Waiver Fee"] = new_value
              end
              if r == 171 && cc == 12
                @other_adjustment["LoanAmount"] = {}
                @other_adjustment["LoanAmount"]["0-150000"] = {}
                cc = cc + 1
                new_value = sheet_data.cell(r,cc)
                @other_adjustment["LoanAmount"]["0-150000"] = new_value
              end
              # Loans With Secondary Financing
              if value == "Loans With Secondary Financing"
                @secondary_hash["LTV/CLTV/FICO"] = {}
              end
              if r >= 157 && r <= 160 && cc == 12
                ltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key] = {}
              end
              if r >= 157 && r <= 160 && cc == 13
                cltv_key = get_value value
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key] = {}
              end
              if r >= 157 && r <= 160 && cc > 13 && cc <= 15
                ltv_data = get_value @ltv_data[cc-1]
                ltv_data = ltv_data.tr('() ','')
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = {}
                @secondary_hash["LTV/CLTV/FICO"][ltv_key][cltv_key][ltv_data] = value
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@cashout_hash,@secondary_hash,@other_adjustment,@property_hash]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_newfi_wholesale7019_path(@sheet_obj)
  end

  def programs
    @programs = @sheet_obj.programs
  end

  def single_program
  end

  private

  def get_value value1
    if value1.present?
      if value1.include?("<=") || value1.include?("<")
        value1 = "0-"+value1.split("<=").last.tr('A-Za-z%$><=/, ','')
        value1 = value1.tr('–','-')
      elsif value1.include?(">")
        value1 = value1.split(">").last.tr('A-Za-z%$><=, ', '')+"-Inf"
        value1 = value1.tr('–','-')
      elsif value1.include?("+")
        value1.split("+")[0] + "-Inf"
        value1 = value1.tr('–','-')
      else
        value1 = value1.tr('% ','')
        value1 = value1.tr('–','-')
      end
    end
  end

  def get_sheet
    @sheet_obj = Sheet.find(params[:id])
  end

  def get_program
    @program = Program.find(params[:id])
  end

  def read_sheet
		file = File.join(Rails.root + "other_sheets", 'OB_Newfi_Wholesale7019.xls')
    @xlsx = Roo::Spreadsheet.open(file)
  end
  def program_property title

    if title.include?("YEAR") || title.include?("YR") || title.include?("yr") || title.include?("Yr")
      term = title.scan(/\d+/)[0]
    end
       # Arm Basic
    if title.include?("3/1") || title.include?("3 / 1")
      arm_basic = 3
    elsif title.include?("5/1") || title.include?("5 / 1")
      arm_basic = 5
    elsif title.include?("7/1") || title.include?("7 / 1")
      arm_basic = 7
    elsif title.include?("10/1") || title.include?("10 / 1")
      arm_basic = 10
    end
    # Arm_advanced
    if title.downcase.include?("arm")
      arm_advanced = title.downcase.split("arm").last.tr('A-Za-z ','')
      if arm_advanced.include?('/')
        arm_advanced = arm_advanced.tr('/','-')
      else
        arm_advanced
      end
    end
    @program.update(term: term, arm_basic: arm_basic, arm_advanced: arm_advanced) 
  end

  def make_adjust(block_hash, sheet)
    block_hash.each do |hash|
      if hash.present?
        hash.each do |key|
          data = {}
          data[key[0]] = key[1]
          Adjustment.create(data: data,loan_category: sheet)
        end
      end
    end
  end

  def ltv_adjustment range1, range2, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row,num
    @adjustment_hash = {}
    primary_key = ''
    ltv_key = ''
    cltv_key = ''
    (range1..range2).each do |r|
      row = sheet_data.row(r)
      @ltv_data = sheet_data.row(ltv_row)
      if row.compact.count >= 1
        (0..last_column).each do |cc|
          begin
            value = sheet_data.cell(r,cc)
            if value.present?
              if value == "LTV / FICO (Terms > 15 years only)"
                primary_key = "LoanType/Term/LTV/FICO"
                @adjustment_hash["Term/FICO/LTV"] = {}
                @adjustment_hash["Term/FICO/LTV"]["15-Inf"] = {}
              end
              if r >= first_row && r <= end_row && cc == first_column
                ltv_key = get_value value
                @adjustment_hash["Term/FICO/LTV"]["15-Inf"][ltv_key] = {}
              end
              if r >= first_row && r <= end_row && cc > first_column && cc <= last_column
                cltv_key = get_value @ltv_data[cc-num]
                @adjustment_hash["Term/FICO/LTV"]["15-Inf"][ltv_key][cltv_key] = {}
                @adjustment_hash["Term/FICO/LTV"]["15-Inf"][ltv_key][cltv_key] = value
              end
            end
          rescue Exception => e
            error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
            error_log.save
          end
        end
      end
    end
    adjustment = [@adjustment_hash]
    make_adjust(adjustment,sheet)
    create_program_association_with_adjustment(sheet)
  end

  def create_program_association_with_adjustment(sheet)
    adjustment_list = Adjustment.where(loan_category: sheet)
    program_list = Program.where(loan_category: sheet)

    adjustment_list.each_with_index do |adj_ment, index|
      key_list = adj_ment.data.keys.first.split("/")
      program_filter1={}
      program_filter2={}
      include_in_input_values = false
      if key_list.present?
        key_list.each_with_index do |key_name, key_index|
          if (Program.column_names.include?(key_name.underscore))
            unless (Program.column_for_attribute(key_name.underscore).type.to_s == "boolean")
              program_filter1[key_name.underscore] = nil
            else
              if (Program.column_for_attribute(key_name.underscore).type.to_s == "boolean")
                program_filter2[key_name.underscore] = true
              end
            end
            include_in_input_values = true
          else
            if(Adjustment::INPUT_VALUES.include?(key_name))
              include_in_input_values = true
            end
          end
        end

        if (include_in_input_values)
          program_list1 = program_list.where.not(program_filter1)
          program_list2 = program_list1.where(program_filter2)

          if program_list2.present?
            program_list2.map{ |program| program.adjustments << adj_ment unless program.adjustments.include?(adj_ment) }
          end
        end
      end
    end
  end
end
