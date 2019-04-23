class RateSheetExtractor::ObSunWestWholesaleDemo5907Controller < RateSheetExtractor::ApplicationController
  before_action :read_sheet, only: [:index,:ak, :agency_conforming_programs, :fhlmc_home_possible, :non_conforming_sigma_qm_prime_jumbo, :non_conforming_jw, :government_programs, :hecm_reverse_mortgage, :non_qm_sigma_seasoned_credit_event, :non_qm_sigma_no_credit_event_plus, :non_qm_real_prime_advantage, :non_qm_real_credit_advantage_a, :non_qm_real_credit_advantage_bbc, :non_qm_real_investor_income_a, :non_qm_real_investor_income_bb, :non_qm_real_dsc_ratio]
  before_action :get_sheet, only: [:programs, :ratesheet, :agency_conforming_programs, :fhlmc_home_possible, :non_conforming_sigma_qm_prime_jumbo, :non_conforming_jw, :government_programs, :hecm_reverse_mortgage, :non_qm_sigma_seasoned_credit_event, :non_qm_sigma_no_credit_event_plus, :non_qm_real_prime_advantage, :non_qm_real_credit_advantage_a, :non_qm_real_credit_advantage_bbc, :non_qm_real_investor_income_a, :non_qm_real_investor_income_bb, :non_qm_real_dsc_ratio]
  before_action :get_program, only: [:single_program]
  def index
    sub_sheet_names = get_sheets_names
    begin
      @xlsx.sheets.each do |sheet|
        if (sheet == "RATESHEET")
          headers = ["Phone", "General Contacts", "Mortgagee Clause (Wholesale)"]
          @name = "SunWest Wholesale"
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

  def agency_conforming_programs
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adj_hash = {}
        # Agency Conforming Programs
        (156..320).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + 2 # 2 / 7 / 12 / 17
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && @title != "Rate"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
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
                        @block_hash[key][15*(c_i+1)] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil? || @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # PRICE ADJUSTMENTS: CONFORMING PROGRAMS //adjustment
        (374..404).each do |r|
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == "LOAN TERM > 15 YEARS"
                  primary_key = "LoanSize/Term/FICO/LTV"
                  first_row = 377
                  end_row = 384
                  last_column = 10
                  first_column = 2
                  ltv_row = 375
                  ltv_adjustment range1, range2, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
                end
                if value == "CASH OUT REFINANCE "
                  primary_key = "LoanSize/RefinanceOption/FICO/LTV"
                  first_row = 389
                  end_row = 396
                  first_column = 2
                  last_column = 6
                  ltv_row = 387
                  cash_adjustment range1, range2, sheet_data, first_row, end_row, sheet, first_column, last_column, ltv_row, primary_key
                end
                if value == "ADDITIONAL LPMI ADJUSTMENTS"
                  primary_key = "LPMI/LoanSize/FICO/LTV"
                  first_row = 390
                  end_row = 393
                  first_column = 9
                  last_column = 12
                  ltv_row = 388
                  lpmi_adjustment range1, range2, sheet_data, first_row, end_row, sheet, first_column, last_column, ltv_row, primary_key
                end
                if value == "SUBORDINATE FINANCING"
                  primary_key = "FinancingType/LoanSize/LTV/CLTV/FICO"
                  first_row = 400
                  end_row = 404
                  first_column = 2
                  cltv_column = 4
                  last_column = 7
                  ltv_row = 399
                  sub_adjustment range1, range2, sheet_data, first_row, end_row, sheet, first_column, cltv_column, last_column, ltv_row, primary_key
                end
                if value == "LPMI COVERAGE BASED ADJUSTMENTS"
                  primary_key = "LPMI/RefinanceOption/FICO"
                  first_row = 399
                  end_row = 404
                  first_column = 9
                  last_column = 12
                  ltv_row = 397
                  lpmi_adjustment range1, range2, sheet_data, first_row, end_row, sheet, first_column, last_column, ltv_row, primary_key
                end
                if r == 376 && cc == 15
                  @adj_hash["PropertyType"] = {}
                  @adj_hash["PropertyType"]["2-4 Unit"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["PropertyType"]["2-4 Unit"] = new_val
                end

                if r == 377 && cc == 15
                  @adj_hash["PropertyType/Term/LTV"] = {}
                  @adj_hash["PropertyType/Term/LTV"]["Condo"] = {}
                  @adj_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                  @adj_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_val
                end
                if r == 378 && cc == 15
                  @adj_hash["PropertyType"]["Manufactured Home"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["PropertyType"]["Manufactured Home"] = new_val
                end
                if r == 379 && cc == 15
                  @adj_hash["FinancingType"] = {}
                  @adj_hash["FinancingType"]["Subordinate Financing"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["FinancingType"]["Subordinate Financing"] = new_val
                end
                if r == 380 && cc == 15
                  @adj_hash["PropertyType/LTV"] = {}
                  @adj_hash["PropertyType/LTV"]["Investment Property"] = {}
                  @adj_hash["PropertyType/LTV"]["Investment Property"]["0-75"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["PropertyType/LTV"]["Investment Property"]["0-75"] = new_val
                end
                if r == 381 && cc == 15
                  @adj_hash["PropertyType/LTV"]["Investment Property"]["75.01-80.01"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["PropertyType/LTV"]["Investment Property"]["75.01-80.01"] = new_val
                end
                if r == 382 && cc == 15
                  @adj_hash["PropertyType/LTV"]["Investment Property"]["80.01-85.00"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["PropertyType/LTV"]["Investment Property"]["80.01-85.00"] = new_val
                end
                if r == 383 && cc == 15
                  @adj_hash["LoanType/LTV"] = {}
                  @adj_hash["LoanType/LTV"]["ARM"] = {}
                  @adj_hash["LoanType/LTV"]["ARM"]["90-Inf"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["LoanType/LTV"]["ARM"]["90-Inf"] = new_val
                end
                if r == 384 && cc == 15
                  @adj_hash["LPMI/RefinanceOption/FICO"] = {}
                  @adj_hash["LPMI/RefinanceOption/FICO"]["true"] = {}
                  @adj_hash["LPMI/RefinanceOption/FICO"]["true"]["Cash Out"] = {}
                  @adj_hash["LPMI/RefinanceOption/FICO"]["true"]["Cash Out"]["680-719"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["LPMI/RefinanceOption/FICO"]["true"]["Cash Out"]["680-719"] = new_val
                end
                if r == 385 && cc == 15
                  @adj_hash["LPMI/RefinanceOption/FICO"]["true"]["Cash Out"]["660-679"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["LPMI/RefinanceOption/FICO"]["true"]["Cash Out"]["660-679"] = new_val
                end
                if r == 386 && cc == 15
                  @adj_hash["LoanSize/LoanType/LTV"] = {}
                  @adj_hash["LoanSize/LoanType/LTV"]["High-Balance"] = {}
                  @adj_hash["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"] = {}
                  @adj_hash["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"]["0-75"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"]["0-75"] = new_val
                end
                if r == 387 && cc == 15
                  @adj_hash["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"]["75-Inf"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"]["75-Inf"] = new_val
                end
                if r == 388 && cc == 15
                  @adj_hash["LoanSize/RefinanceOption"] = {}
                  @adj_hash["LoanSize/RefinanceOption"]["High-Balance"] = {}
                  @adj_hash["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = new_val
                end
                if r == 389 && cc == 15
                  @adj_hash["LoanPurpose/LoanSize/RefinanceOption"] = {}
                  @adj_hash["LoanPurpose/LoanSize/RefinanceOption"]["Purchase"] = {}
                  @adj_hash["LoanPurpose/LoanSize/RefinanceOption"]["Purchase"]["High-Balance"] = {}
                  @adj_hash["LoanPurpose/LoanSize/RefinanceOption"]["Purchase"]["High-Balance"]["Cash Out"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["LoanPurpose/LoanSize/RefinanceOption"]["Purchase"]["High-Balance"]["Cash Out"] = new_val
                end
                if r == 397 && cc == 15
                  @adj_hash["FNMA/FannieMaeProduct/FICO/LTV"] = {}
                  @adj_hash["FNMA/FannieMaeProduct/FICO/LTV"]["true"] = {}
                  @adj_hash["FNMA/FannieMaeProduct/FICO/LTV"]["true"]["HomeReady"] = {}
                  @adj_hash["FNMA/FannieMaeProduct/FICO/LTV"]["true"]["HomeReady"]["680-Inf"] = {}
                  @adj_hash["FNMA/FannieMaeProduct/FICO/LTV"]["true"]["HomeReady"]["680-Inf"]["80-Inf"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["FNMA/FannieMaeProduct/FICO/LTV"]["true"]["HomeReady"]["680-Inf"]["80-Inf"] = new_val
                end
                if r == 398 && cc == 15
                  @adj_hash["FNMA/FannieMaeProduct/FICO/LTV"]["true"]["HomeReady"]["0-680"] = {}
                  @adj_hash["FNMA/FannieMaeProduct/FICO/LTV"]["true"]["HomeReady"]["0-680"]["0-80"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["FNMA/FannieMaeProduct/FICO/LTV"]["true"]["HomeReady"]["0-680"]["0-80"] = new_val
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@adj_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def fhlmc_home_possible
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @property_hash = {}
        # FHLMC HOME POSSIBLE / HOMEONE / SUPER CONFORMING Programs
        (708..760).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + 2 # 2 / 7 / 12 / 17
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && @title != "Rate"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
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
                        @block_hash[key][15*(c_i+1)] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil? || @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # PRICE ADJUSTMENTS: FHLMC HOME POSSIBLE / HOMEONE / SUPER CONFORMING //adjustment // 3 more adjustment remaining for this programs
        (782..799).each do |r|
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == "LOAN TERM > 15 YEARS"
                  primary_key = "LoanSize/Term/FICO/LTV"
                  first_row = 785
                  end_row = 791
                  first_column = 2
                  last_column = 11
                  ltv_row = 783
                  start_range = 782
                  end_range = 799
                  ltv_adjustment start_range, end_range, sheet_data, first_row, end_row, sheet, first_column, last_column, ltv_row, primary_key
                end
                if value == "SUBORDINATE FINANCING  (Applicable to HomeOne)"
                  primary_key = "FinancingType/LoanSize/LTV/CLTV/FICO"
                  first_row = 795
                  end_row = 799
                  first_column = 15
                  cltv_column = 17
                  last_column = 20
                  ltv_row = 794
                  range1 = 782
                  range2 = 799
                  sub_adjustment range1, range2, sheet_data, first_row, end_row, sheet, first_column, cltv_column, last_column, ltv_row, primary_key
                end
                if r == 783 && cc == 15
                  @property_hash["PropertyType/Term/LTV"] = {}
                  @property_hash["PropertyType/Term/LTV"]["Condo"] = {}
                  @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                  @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_val
                end
                if r == 784 && cc == 15
                  @property_hash["PropertyType"] = {}
                  @property_hash["PropertyType"]["Manufactured Home"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @property_hash["PropertyType"]["Manufactured Home"] = new_val
                end
                if r == 785 && cc == 15
                  @property_hash["PropertyType"]["2 Unit"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @property_hash["PropertyType"]["2 Unit"] = new_val
                end
                if r == 786 && cc == 15
                  @property_hash["PropertyType/LTV"] = {}
                  @property_hash["PropertyType/LTV"]["3-4 Unit"] = {}
                  @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-80"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-80"] = new_val
                end
                if r == 787 && cc == 15
                  @property_hash["PropertyType/LTV"]["3-4 Unit"]["80-85"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @property_hash["PropertyType/LTV"]["3-4 Unit"]["80-85"] = new_val
                end
                if r == 788 && cc == 15
                  @property_hash["PropertyType/LTV"]["3-4 Unit"]["85-Inf"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @property_hash["PropertyType/LTV"]["3-4 Unit"]["85-Inf"] = new_val
                end
                if r == 789 && cc == 15
                  @property_hash["FinancingType"] = {}
                  @property_hash["FinancingType"]["Subordinate Financing"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @property_hash["FinancingType"]["Subordinate Financing"] = new_val
                end
                if r == 791 && cc == 15
                  @property_hash["FreddieMacProduct/LoanPurpose/LoanSize/RefinanceOption"] = {}
                  @property_hash["FreddieMacProduct/LoanPurpose/LoanSize/RefinanceOption"]["HomePossible"] = {}
                  @property_hash["FreddieMacProduct/LoanPurpose/LoanSize/RefinanceOption"]["HomePossible"]["Purchase"] = {}
                  @property_hash["FreddieMacProduct/LoanPurpose/LoanSize/RefinanceOption"]["HomePossible"]["Purchase"]["Conforming"] = {}
                  @property_hash["FreddieMacProduct/LoanPurpose/LoanSize/RefinanceOption"]["HomePossible"]["Purchase"]["Conforming"]["Cash Out"] = {}
                  cc = cc + 5
                  new_val = sheet_data.cell(r,cc)
                  @property_hash["FreddieMacProduct/LoanPurpose/LoanSize/RefinanceOption"]["HomePossible"]["Purchase"]["Conforming"]["Cash Out"] = new_val
                end
                if r == 795 && cc == 2
                  @property_hash["FreddieMacProduct/LTV/FICO"] = {}
                  @property_hash["FreddieMacProduct/LTV/FICO"]["HomePossible"] = {}
                  @property_hash["FreddieMacProduct/LTV/FICO"]["HomePossible"]["80-Inf"] = {}
                  @property_hash["FreddieMacProduct/LTV/FICO"]["HomePossible"]["80-Inf"]["680-Inf"] = {}
                  cc = cc + 2
                  new_val = sheet_data.cell(r,cc)
                  @property_hash["FreddieMacProduct/LTV/FICO"]["HomePossible"]["80-Inf"]["680-Inf"] = new_val
                end
                if r == 796 && cc == 3
                  @property_hash["FreddieMacProduct/LTV/FICO"]["HomePossible"]["80-Inf"]["0-680"] = {}
                  cc = cc + 1
                  new_val = sheet_data.cell(r,cc)
                  @property_hash["FreddieMacProduct/LTV/FICO"]["HomePossible"]["80-Inf"]["0-680"] = new_val
                end
                if r == 797 && cc == 2
                  @property_hash["FreddieMacProduct/LTV/FICO"]["HomePossible"]["0-80"] = {}
                  @property_hash["FreddieMacProduct/LTV/FICO"]["HomePossible"]["0-80"]["0-Inf"] = {}
                  cc = cc + 2
                  new_val = sheet_data.cell(r,cc)
                  @property_hash["FreddieMacProduct/LTV/FICO"]["HomePossible"]["0-80"]["0-Inf"] = new_val
                end
              end
              #ADJUSTMENT CAPS (Applicable to Home Possible products) Not completed
              if value == "ADJUSTMENT CAPS (Applicable to Home Possible products)"
                primary_key = "LoanType/Term/LTV/FICO"
                @caps_adjustment[primary_key] = {}
              end
              # ADJUSTMENT CAPS end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@property_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def non_conforming_sigma_qm_prime_jumbo
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @jumbo_hash = {}
        primary_key = ''
        ltv_key = ''
        #Non-Confirming: Sigma Programs
        (1101..1179).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + 2 # 2 / 7 / 12 / 17
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && @title != "ARM INFORMATION"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
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
                        @block_hash[key][15*(c_i+1)] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil? || @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        #NON-CONFORMING: SIGMA QM PRIME JUMBO //adjustment
        (1166..1199).each do |r|
          @jumbo_data = sheet_data.row(1167)
          @price_data = sheet_data.row(1183)
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == "PROGRAM SPECIFIC PRICE ADJUSTMENTS"
                  @jumbo_hash["State/LTV"] = {}
                  @jumbo_hash["LoanAmount/FICO/LTV"] = {}
                  @jumbo_hash["LoanAmount/FICO/LTV"]["0-1000000"] = {}
                  @jumbo_hash["LoanAmount/FICO/LTV"]["1000000-1500000"] = {}
                  @jumbo_hash["LoanAmount/FICO/LTV"]["1500000-2000000"] = {}
                  @jumbo_hash["LoanAmount/FICO/LTV"]["2000000-2500000"] = {}
                end
                if r == 1169 && cc == 14
                  @jumbo_hash["LockDay/LTV"] = {}
                  @jumbo_hash["LockDay/LTV"]["15"] = {}
                end
                if r == 1169 && cc >= 16 && cc <= 20
                  ltv_key = get_value @jumbo_data[cc-2]
                  @jumbo_hash["LockDay/LTV"]["15"][ltv_key] = {}
                  @jumbo_hash["LockDay/LTV"]["15"][ltv_key] = value
                end
                if r >= 1170 && r <= 1174 && cc == 14
                  primary_key = value.split.last
                  @jumbo_hash["State/LTV"][primary_key] = {}
                end
                if r >= 1170 && r <= 1174 && cc >= 16 && cc <= 20
                  ltv_key = get_value @jumbo_data[cc-2]
                  @jumbo_hash["State/LTV"][primary_key][ltv_key] = {}
                  @jumbo_hash["State/LTV"][primary_key][ltv_key] = value
                end
                if r == 1175 && cc == 14
                  @jumbo_hash["PropertyType/LTV"] = {}
                  @jumbo_hash["PropertyType/LTV"]["2 Unit"] = {}
                end
                if r == 1175 && cc >= 16 && cc <= 20
                  ltv_key = get_value @jumbo_data[cc-2]
                  @jumbo_hash["PropertyType/LTV"]["2 Unit"][ltv_key] = {}
                  @jumbo_hash["PropertyType/LTV"]["2 Unit"][ltv_key] = value
                end
                if r == 1176 && cc == 14
                  @jumbo_hash["PropertyType/LTV"]["Condo"] = {}
                end
                if r == 1176 && cc >= 16 && cc <= 20
                  ltv_key = get_value @jumbo_data[cc-2]
                  @jumbo_hash["PropertyType/LTV"]["Condo"][ltv_key] = {}
                  @jumbo_hash["PropertyType/LTV"]["Condo"][ltv_key] = value
                end
                if r == 1177 && cc == 14
                  @jumbo_hash["PropertyType/LTV"]["2nd Home"] = {}
                end
                if r == 1177 && cc >= 16 && cc <= 20
                  ltv_key = get_value @jumbo_data[cc-2]
                  @jumbo_hash["PropertyType/LTV"]["2nd Home"][ltv_key] = {}
                  @jumbo_hash["PropertyType/LTV"]["2nd Home"][ltv_key] = value
                end
                if r == 1178 && cc == 14
                  @jumbo_hash["LoanPurpose/LTV"] = {}
                  @jumbo_hash["LoanPurpose/LTV"]["Purchase"] = {}
                end
                if r == 1178 && cc >= 16 && cc <= 20
                  ltv_key = get_value @jumbo_data[cc-2]
                  @jumbo_hash["LoanPurpose/LTV"]["Purchase"][ltv_key] = {}
                  @jumbo_hash["LoanPurpose/LTV"]["Purchase"][ltv_key] = value
                end
                if r == 1179 && cc == 14
                  @jumbo_hash["RefinanceOption/LTV"] = {}
                  @jumbo_hash["RefinanceOption/LTV"]["Cash Out"] = {}
                end
                if r == 1179 && cc >= 16 && cc <= 20
                  ltv_key = get_value @jumbo_data[cc-2]
                  @jumbo_hash["RefinanceOption/LTV"]["Cash Out"][ltv_key] = {}
                  @jumbo_hash["RefinanceOption/LTV"]["Cash Out"][ltv_key] = value
                end
                if r >= 1185 && r <= 1189 && cc == 2
                  primary_key = get_value value
                  @jumbo_hash["LoanAmount/FICO/LTV"]["0-1000000"][primary_key] = {}
                  @jumbo_hash["LoanAmount/FICO/LTV"]["1000000-1500000"][primary_key] = {}
                end
                if r >= 1185 && r <= 1189 && cc >= 3 && cc <= 7
                  ltv_key = get_value @price_data[cc-2]
                  @jumbo_hash["LoanAmount/FICO/LTV"]["0-1000000"][primary_key][ltv_key] = {}
                  @jumbo_hash["LoanAmount/FICO/LTV"]["0-1000000"][primary_key][ltv_key] = value
                end
                if r >= 1185 && r <= 1189 && cc >= 8 && cc <= 12
                  ltv_key = get_value @price_data[cc-2]
                  @jumbo_hash["LoanAmount/FICO/LTV"]["1000000-1500000"][primary_key][ltv_key] = {}
                  @jumbo_hash["LoanAmount/FICO/LTV"]["1000000-1500000"][primary_key][ltv_key] = value
                end
                if r >= 1195 && r <= 1198 && cc == 2
                  primary_key = get_value value
                  @jumbo_hash["LoanAmount/FICO/LTV"]["1500000-2000000"][primary_key] = {}
                  @jumbo_hash["LoanAmount/FICO/LTV"]["2000000-2500000"][primary_key] = {}
                end
                if r >= 1195 && r <= 1198 && cc >= 3 && cc <= 7
                  ltv_key = get_value @price_data[cc-2]
                  @jumbo_hash["LoanAmount/FICO/LTV"]["1500000-2000000"][primary_key][ltv_key] = {}
                  @jumbo_hash["LoanAmount/FICO/LTV"]["1500000-2000000"][primary_key][ltv_key] = value
                end
                if r >= 1195 && r <= 1198 && cc >= 8 && cc <= 12
                  ltv_key = get_value @price_data[cc-2]
                  @jumbo_hash["LoanAmount/FICO/LTV"]["2000000-2500000"][primary_key][ltv_key] = {}
                  @jumbo_hash["LoanAmount/FICO/LTV"]["2000000-2500000"][primary_key][ltv_key] = value
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@jumbo_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def non_conforming_jw
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @price_hash = {}
        primary_key = ''
        ltv_key = ''
        cltv_key = ''
        first_key = ''
        (1386..1547).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + 2 # 2 / 7 / 12 / 17
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && @title != "Rate"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
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
                        @block_hash[key][15*(c_i+1)] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil? || @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        #NON-CONFORMING: JW /adjustment
        (1599..1614).each do |r|
          @price_data = sheet_data.row(1600)
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == "PRICE ADJUSTMENTS"
                  @price_hash["LoanSize/FICO/LTV"] = {}
                  @price_hash["LoanSize/FICO/LTV"]["Non-Conforming"] = {}
                end
                if value == "STATE SPECEFIC PRICE ADJUSTMENTS"
                  @price_hash["LoanSize/LoanType/State/Term"] = {}
                  @price_hash["LoanSize/LoanType/State/Term"]["Non-Conforming"] = {}
                  @price_hash["LoanSize/LoanType/State/Term"]["Non-Conforming"]["Fixed"] = {}
                  @price_hash["LoanSize/LoanType/State/ArmBasic"] = {}
                  @price_hash["LoanSize/LoanType/State/ArmBasic"]["Non-Conforming"] = {}
                  @price_hash["LoanSize/LoanType/State/ArmBasic"]["Non-Conforming"]["ARM"] = {}
                end
                if value == "PROGRAM SPECIFIC PRICE ADJUSTMENTS"
                  @price_hash["LoanSize/RefinanceOption/LTV"] = {}
                  @price_hash["LoanSize/RefinanceOption/LTV"]["Non-Conforming"] = {}
                  @price_hash["LoanSize/RefinanceOption/LTV"]["Non-Conforming"]["Cash Out"] = {}
                end
                if r >= 1602 && r <= 1607 && cc == 7
                  primary_key = get_value value
                  @price_hash["LoanSize/FICO/LTV"]["Non-Conforming"][primary_key] = {}
                end
                if r >= 1602 && r <= 1607 && cc >= 8 && cc <= 11
                  ltv_key = get_value @price_data[cc-2]
                  @price_hash["LoanSize/FICO/LTV"]["Non-Conforming"][primary_key][ltv_key] = {}
                  @price_hash["LoanSize/FICO/LTV"]["Non-Conforming"][primary_key][ltv_key] = value
                end
                if r >= 1601 && r <= 1610 && cc == 13
                  cltv_key = value.split.last
                  @price_hash["LoanSize/LoanType/State/Term"]["Non-Conforming"]["Fixed"][cltv_key] = {}
                  @price_hash["LoanSize/LoanType/State/ArmBasic"]["Non-Conforming"]["ARM"][cltv_key] = {}
                end
                if r >= 1601 && r <= 1610 && cc >= 15 && cc <= 17
                  first_key = get_value @price_data[cc-2]
                  @price_hash["LoanSize/LoanType/State/Term"]["Non-Conforming"]["Fixed"][cltv_key][first_key] = {}
                  @price_hash["LoanSize/LoanType/State/Term"]["Non-Conforming"]["Fixed"][cltv_key][first_key] = value
                end
                if r >= 1601 && r <= 1610 && cc >= 18 && cc <= 20
                  first_key = @price_data[cc-2].split("/").first
                  @price_hash["LoanSize/LoanType/State/ArmBasic"]["Non-Conforming"]["ARM"][cltv_key][first_key] = {}
                  @price_hash["LoanSize/LoanType/State/ArmBasic"]["Non-Conforming"]["ARM"][cltv_key][first_key] = value
                end
                if r == 1607 && cc == 2
                  @price_hash["LoanSize/PropertyType"] = {}
                  @price_hash["LoanSize/PropertyType"]["Non-Conforming"] = {}
                  @price_hash["LoanSize/PropertyType"]["Non-Conforming"]["Investment Property"] = {}
                  cc = cc + 3
                  new_val = sheet_data.cell(r,cc)
                  @price_hash["LoanSize/PropertyType"]["Non-Conforming"]["Investment Property"] = new_val
                end
                if r == 1608 && cc == 2
                  @price_hash["LoanSize/PropertyType"]["Non-Conforming"]["3 Unit"] = {}
                  cc = cc + 3
                  new_val = sheet_data.cell(r,cc)
                  @price_hash["LoanSize/PropertyType"]["Non-Conforming"]["3 Unit"] = new_val
                end
                if r == 1609 && cc == 2
                  @price_hash["LoanSize/PropertyType"]["Non-Conforming"]["4 Unit"] = {}
                  cc = cc + 3
                  new_val = sheet_data.cell(r,cc)
                  @price_hash["LoanSize/PropertyType"]["Non-Conforming"]["4 Unit"] = new_val
                end
                if r == 1610 && cc == 2
                  @price_hash["LoanSize/PropertyType"]["Non-Conforming"]["2nd Home"] = {}
                  cc = cc + 3
                  new_val = sheet_data.cell(r,cc)
                  @price_hash["LoanSize/PropertyType"]["Non-Conforming"]["2nd Home"] = new_val
                end
                if r == 1611 && cc == 2
                  @price_hash["LoanSize/LoanAmount"] = {}
                  @price_hash["LoanSize/LoanAmount"]["Non-Conforming"] = {}
                  @price_hash["LoanSize/LoanAmount"]["Non-Conforming"]["1000000-Inf"] = {}
                  cc = cc + 3
                  new_val = sheet_data.cell(r,cc)
                  @price_hash["LoanSize/LoanAmount"]["Non-Conforming"]["1000000-Inf"] = new_val
                end
                if r >= 1612 && r <= 1614 && cc == 2
                  ltv_key = get_value value
                  @price_hash["LoanSize/RefinanceOption/LTV"]["Non-Conforming"]["Cash Out"][ltv_key] = {}
                  cc = cc + 3
                  new_val = sheet_data.cell(r,cc)
                  @price_hash["LoanSize/RefinanceOption/LTV"]["Non-Conforming"]["Cash Out"][ltv_key] = new_val
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@price_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def government_programs
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @gov_hash = {}
        #GOVERNMENT PROGRAMS /programs
        (2180..2278).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 3) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 5*max_column + 2 # 2 / 7 / 12 / 17
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && @title != "Rate" && @title != "PROGRAM SPECIFIC PRICE ADJUSTMENTS"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
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
                        @block_hash[key][15*(c_i+1)] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil? || @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        #GOVERNMENT PROGRAMS /adjustments
        (2255..2278).each do |r|
          @ltv_data = sheet_data.row(2274)
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == "PROGRAM SPECIFIC PRICE ADJUSTMENTS"
                  @gov_hash["FICO"] = {}
                end
                if r == 2256 && cc == 14
                  @gov_hash["FHA"] = {}
                  @gov_hash["FHA"]["true"] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @gov_hash["FHA"]["true"] = new_val
                end
                if r == 2257 && cc == 14
                  @gov_hash["VA"] = {}
                  @gov_hash["VA"]["true"] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @gov_hash["VA"]["true"] = new_val
                end
                if r == 2258 && cc == 14
                  @gov_hash["USDA"] = {}
                  @gov_hash["USDA"]["true"] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @gov_hash["USDA"]["true"] = new_val
                end
                if r == 2260 && cc == 14
                  @gov_hash["LoanType/Term"] = {}
                  @gov_hash["LoanType/Term"]["Fixed"] = {}
                  @gov_hash["LoanType/Term"]["Fixed"]["16-29"] = {}
                  @gov_hash["LoanType/Term"]["Fixed"]["30"] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @gov_hash["LoanType/Term"]["Fixed"]["16-29"] = new_val
                  @gov_hash["LoanType/Term"]["Fixed"]["30"] = new_val
                end
                if r >= 2261 && r <= 2266 && cc == 14
                  primary_key = get_value value
                  @gov_hash["FICO"][primary_key] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @gov_hash["FICO"][primary_key] = new_val
                end
                if r == 2269 && cc == 14
                  @gov_hash["PropertyType"] = {}
                  @gov_hash["PropertyType"]["Manufactured Home"] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @gov_hash["PropertyType"]["Manufactured Home"] = new_val
                end
                if r == 2270 && cc == 14
                  @gov_hash["PropertyType"]["3-4 Unit"] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @gov_hash["PropertyType"]["3-4 Unit"] = new_val
                end
                if r == 2271 && cc == 14
                  @gov_hash["PropertyType"]["2nd Home"] = {}
                  @gov_hash["PropertyType"]["Investment Property"] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @gov_hash["PropertyType"]["2nd Home"] = new_val
                  @gov_hash["PropertyType"]["Investment Property"] = new_val
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@gov_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def hecm_reverse_mortgage
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def non_qm_sigma_seasoned_credit_event
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        (2434..2477).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 7))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3*max_column + 2 # 2 / 5 / 8 / 11 / 14
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && (cc <= 8) && @title.class == String && @title != "N/A"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..2).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][30] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def non_qm_sigma_no_credit_event_plus
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @spec_adjustment5 = {}
        # @spec_adjustment6 = {}
        primary_key = ''
        ltv_key = ''
        (2624..2675).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 7))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3*max_column + 2 # 2 / 5 / 8
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && (cc <= 8) && @title.class == String && @title != "N/A"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..2).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][30] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # Adjustment
        (2624..2738).each do |r|
          @ltv_data = sheet_data.row(2730)
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value == "ARM INFORMATION"
                primary_key = "LoanType/Term/LTV/FICO"
                first_row = 2626
                end_row = 2629
                first_column = 11
                last_column = 13
                ltv_row = 2625
                ltv_adjustment 2624, 2738, sheet_data, first_row, end_row,@sheet_name,first_column, last_column, ltv_row, primary_key
              end

              if value == "PROGRAM SPECIFIC PRICE ADJUSTMENTS "
                primary_key = "LoanType/Term/LTV/FICO"
                first_row = 2638
                end_row = 2652
                first_column = 13
                last_column = 20
                ltv_row = 2636
                ltv_adjustment 2624, 2738, sheet_data, first_row, end_row,@sheet_name,first_column, last_column, ltv_row, primary_key
              end

              if value == "FULL DOCUMENTATION / ASSET UTILIZATION"
                primary_key = "FICO/LTV"
                @spec_adjustment5[primary_key] = {}
              end

              if r >= 2732 && r <= 2738 && cc == 2
                ltv_key = value
                @spec_adjustment5[primary_key][ltv_key] = {}
              end

              if r >= 2732 && r <= 2738 && cc >= 3 && cc <= 11
                c_val = get_value @ltv_data[cc-2]
                @spec_adjustment5[primary_key][ltv_key][c_val] = value
              end

              # if value == "BANK STATEMENT DOCUMENTION / EXPRESS DOCUMENTION"
              #   primary_key = "LoanType/Term/LTV/FICO"
              #   @spec_adjustment6[primary_key] = {}
              # end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@spec_adjustment5]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def non_qm_real_prime_advantage
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @day_adjustment = {}
        @adj_hash = {}
        primary_key = ''
        ltv_key = ''
        # NON-QM: R.E.A.L PRIME ADVANTAGE Programs done
        (2791..2803).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 7))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3*max_column + 2 # 2 / 5 / 8
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && (cc <= 12) && @title.class == String #&& @title != "N/A"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  # progreach_pair { |name, val|  }am_property @program
                  @programs_ids << @program.id
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..2).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][30] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        #NON-QM: R.E.A.L PRIME ADVANTAGE /Adjustment Done
        (2791..2885).each do |r|
          @ltv_data = sheet_data.row(2730)
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == "PROGRAM SPECIFIC RATE ADJUSTMENTS"
                  @adj_hash["Dti/LTV"] = {}
                  @adj_hash["Dti/LTV"]["43.01-50.00"] = {}
                  @adj_hash["Dti/LTV"]["50.00-Inf"] = {}
                  @adj_hash["LoanPurpose/RefinanceOption/LTV"] = {}
                  @adj_hash["LoanPurpose/RefinanceOption/LTV"]["Refinance"] = {}
                  @adj_hash["LoanPurpose/RefinanceOption/LTV"]["Refinance"]["Cash Out"] = {}
                  @adj_hash["LTV"] = {}
                  @adj_hash["PropertyType/LTV"] = {}
                  @adj_hash["PropertyType/LTV"]["2nd Home"] = {}
                  @adj_hash["PropertyType/LTV"]["Condo"] = {}
                  @adj_hash["PropertyType/LTV"]["2-4 Unit"] = {}
                end
                if r == 2858 && cc == 16
                  @adj_hash["Dti/LTV"]["36.01-43.00"] = {}
                  @adj_hash["Dti/LTV"]["36.01-43.00"]["85.01-90.00"] = {}
                  cc = cc + 4
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["Dti/LTV"]["36.01-43.00"]["85.01-90.00"] = new_val
                end
                if r >= 2859 && r <= 2861 && cc == 16
                  ltv_key = value.downcase.split('ltv').last.tr('A-Za-z()% ','')
                  @adj_hash["Dti/LTV"]["43.01-50.00"][ltv_key] = {}
                  cc = cc + 4
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["Dti/LTV"]["43.01-50.00"][ltv_key] = new_val
                end
                if r >= 2862 && r <= 2864 && cc == 16
                  ltv_key = value.downcase.split('ltv').last.tr('A-Za-z()% ','')
                  ltv_key = get_value ltv_key
                  @adj_hash["Dti/LTV"]["50.00-Inf"][ltv_key] = {}
                  cc = cc + 4
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["Dti/LTV"]["50.00-Inf"][ltv_key] = new_val
                end
                if r >= 2865 && r <= 2868 && cc == 16
                  ltv_key = value.downcase.split('ltv').last.tr('A-Za-z()% ','')
                  ltv_key = get_value ltv_key
                  @adj_hash["LoanPurpose/RefinanceOption/LTV"]["Refinance"]["Cash Out"][ltv_key] = {}
                  cc = cc + 4
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["LoanPurpose/RefinanceOption/LTV"]["Refinance"]["Cash Out"][ltv_key] = new_val
                end
                if r >= 2869 && r <= 2871 && cc == 16
                  ltv_key = value.downcase.split('ltv').last.tr('A-Za-z()% ','')
                  ltv_key = get_value ltv_key
                  @adj_hash["LTV"][ltv_key] = {}
                  cc = cc + 4
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["LTV"][ltv_key] = new_val
                end
                if r >= 2872 && r <= 2873 && cc == 16
                  ltv_key = value.downcase.split('ltv').last.tr('A-Za-z()% ','')
                  ltv_key = get_value ltv_key
                  @adj_hash["PropertyType/LTV"]["2nd Home"][ltv_key] = {}
                  cc = cc + 4
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["PropertyType/LTV"]["2nd Home"][ltv_key] = new_val
                end
                if r >= 2874 && r <= 2875 && cc == 16
                  ltv_key = value.downcase.split('ltv').last.tr('A-Za-z()% ','')
                  ltv_key = get_value ltv_key
                  @adj_hash["PropertyType/LTV"]["Condo"][ltv_key] = {}
                  cc = cc + 4
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["PropertyType/LTV"]["Condo"][ltv_key] = new_val
                end
                if r >= 2878 && r <= 2879 && cc == 16
                  ltv_key = value.downcase.split('ltv').last.tr('A-Za-z()% ','')
                  ltv_key = get_value ltv_key
                  @adj_hash["PropertyType/LTV"]["2-4 Unit"][ltv_key] = {}
                  cc = cc + 4
                  new_val = sheet_data.cell(r,cc)
                  @adj_hash["PropertyType/LTV"]["2-4 Unit"][ltv_key] = new_val
                end
                if value == "ARM INFORMATION"
                  primary_key = "LoanType/Term/LTV/FICO"
                  first_row = 2799
                  end_row = 2802
                  first_column = 18
                  last_column = 20
                  ltv_row = 2798
                  ltv_adjustment 2791, 2885, sheet_data, first_row, end_row,@sheet_name,first_column, last_column, ltv_row, primary_key
                end

                if value == "FICO"
                  primary_key = "LoanType/LTV/FICO"
                  first_row = 2859
                  end_row = 2865
                  first_column = 2
                  last_column = 12
                  ltv_row = 2856
                  ltv_adjustment 2791, 2885, sheet_data, first_row, end_row,@sheet_name,first_column, last_column, ltv_row, primary_key
                end

                if value == "LOAN AMOUNT"
                  primary_key = "LoanType/LoanAmount/FICO"
                  first_row = 2867
                  end_row = 2874
                  first_column = 2
                  last_column = 12
                  ltv_row = 2856
                  ltv_adjustment 2791, 2885, sheet_data, first_row, end_row,@sheet_name,first_column, last_column, ltv_row, primary_key
                end

                if value == "45 Day Lock (Price Adjustment)"
                  primary_key = "LockDay"
                  c_val = sheet_data.cell(2855,20)
                  @day_adjustment[primary_key] = {}
                  @day_adjustment[primary_key]["45"] = c_val
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@day_adjustment,@adj_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def non_qm_real_credit_advantage_a
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @spec_adjustment12 = {}
        @day_adjustment6 = {}
        (2936..2948).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 7))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3*max_column + 2 # 2 / 5 / 8
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && (cc <= 12) && @title.class == String #&& @title != "N/A"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..2).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][30] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # # NON-QM: R.E.A.L CREDIT ADVANTAGE - A //Adjustment
        (2936..3036).each do |r|
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value == "PROGRAM SPECIFIC RATE ADJUSTMENTS"
                primary_key = "LoanType / RateLock"
                @spec_adjustment12[primary_key] = {}
                c_val = sheet_data.cell(r,cc+4)
                @spec_adjustment12[primary_key][value] = c_val
              end

              if r >= 3003 && r <= 3024 && cc == 16
                c_val = sheet_data.cell(r,cc+4)
                @spec_adjustment12[primary_key][value] = c_val
              end

              if value == "45 Day Lock (Price Adjustment)"
                primary_key = "RateType/LoanType/RateLock"
                c_val = sheet_data.cell(3445,20)
                @day_adjustment6[primary_key] = {}
                @day_adjustment6[primary_key][value] = c_val
              end

              if value == "FICO"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3004
                end_row = 3013
                first_column = 2
                last_column = 12
                ltv_row = 3001
                ltv_adjustment 2936, 3036, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end

              if value == "LOAN AMOUNT"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3015
                end_row = 3023
                first_column = 2
                last_column = 12
                ltv_row = 3001
                ltv_adjustment 2936, 3036, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@spec_adjustment12,@day_adjustment6]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def non_qm_real_credit_advantage_bbc
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @spec_adjustment8 = {}
        @day_adjustment2 = {}
        # #NON-QM: R.E.A.L CREDIT ADVANTAGE - B, B-, C /Program
        (3089..3101).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 7))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3*max_column + 2 # 2 / 5 / 8
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && (cc <= 12) && @title.class == String #&& @title != "N/A"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..2).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][30] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        #NON-QM: R.E.A.L CREDIT ADVANTAGE - B, B-, C /Adjustment
        (3089..3183).each do |r|
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value == "PROGRAM SPECIFIC RATE ADJUSTMENTS"
                first_key = "LoanType / RateLock"
                @spec_adjustment8[first_key] = {}
              end

              if r >= 3158 && r <= 3181 && cc == 16
                c_val = sheet_data.cell(r,cc+4)
                @spec_adjustment8[first_key][value] = c_val
              end

              if value == "45 Day Lock (Price Adjustment)"
                primary_key = "RateType/LoanType/RateLock"
                c_val = sheet_data.cell(3155,20)
                @day_adjustment2[primary_key] = {}
                @day_adjustment2[primary_key][value] = c_val
              end

              if value == "FICO"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3157
                end_row = 3167
                first_column = 2
                last_column = 11
                ltv_row = 3154
                ltv_adjustment 3089, 3183, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end

              if value == "LOAN AMOUNT"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3169
                end_row = 3172
                first_column = 2
                last_column = 11
                ltv_row = 3154
                ltv_adjustment 3089, 3183, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end

              # if value == "DOC TYPE"
              #   remaining
              # end

              if value == "R.E.A.L Credit Advantage - B"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3099
                end_row = 3102
                first_column = 14
                last_column = 16
                ltv_row = 3098
                ltv_adjustment 3089, 3183, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end

              if value == "R.E.A.L Credit Advantage - B- & C"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3099
                end_row = 3102
                first_column = 18
                last_column = 20
                ltv_row = 3098
                ltv_adjustment 3089, 3183, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@spec_adjustment8,@day_adjustment2]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def non_qm_real_investor_income_a
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @spec_adjustment9 = {}
        @day_adjustment3 = {}
        #NON-QM: R.E.A.L INVESTOR INCOME - A /Program
        (3237..3249).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 7))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3*max_column + 2 # 2 / 5 / 8
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && (cc <= 8) && @title.class == String #&& @title != "N/A"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..2).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][30] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        #NON-QM: R.E.A.L INVESTOR INCOME - A /Adjustment
        (3237..3280).each do |r|
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value == "PROGRAM SPECIFIC RATE ADJUSTMENTS"
                first_key = "LoanType / RateLock"
                @spec_adjustment9[first_key] = {}
              end

              if r >= 3266 && r <= 3279 && cc == 16
                c_val = sheet_data.cell(r,cc+4)
                @spec_adjustment9[first_key][value] = c_val
              end

              if value == "45 Day Lock (Price Adjustment)"
                primary_key = "RateType/LoanType/RateLock"
                c_val = sheet_data.cell(3252,6)
                @day_adjustment3[primary_key] = {}
                @day_adjustment3[primary_key][value] = c_val
              end

              if value == "FICO"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3257
                end_row = 3266
                first_column = 2
                last_column = 10
                ltv_row = 3254
                ltv_adjustment 3237, 3280, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end

              if value == "LOAN AMOUNT"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3268
                end_row = 3275
                first_column = 2
                last_column = 10
                ltv_row = 3254
                ltv_adjustment 3237, 3280, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end

              if value == "DOC TYPE"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3277
                end_row = 3280
                first_column = 2
                last_column = 10
                ltv_row = 3254
                ltv_adjustment 3237, 3280, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@spec_adjustment9,@day_adjustment3]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def non_qm_real_investor_income_bb
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @spec_adjustment10 = {}
        @day_adjustment4 = {}
        #NON-QM: R.E.A.L INVESTOR INCOME - B, B- /Program
        (3334..3346).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 7))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3*max_column + 2 # 2 / 5 / 8
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && (cc <= 12) && @title.class == String #&& @title != "N/A"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..2).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][30] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        #NON-QM: R.E.A.L INVESTOR INCOME - B, B- /Adjustments
        (3334..3379).each do |r|
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)

              if value == "PROGRAM SPECIFIC RATE ADJUSTMENTS"
                first_key = "LoanType / RateLock"
                @spec_adjustment10[first_key] = {}
              end

              if r >= 3358 && r <= 3378 && cc == 16
                c_val = sheet_data.cell(r,cc+4)
                @spec_adjustment10[first_key][value] = c_val
              end

              if value == "45 Day Lock (Price Adjustment)"
                primary_key = "RateType/LoanType/RateLock"
                c_val = sheet_data.cell(3355,20)
                @day_adjustment4[primary_key] = {}
                @day_adjustment4[primary_key][value] = c_val
              end

              if value == "FICO"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3351
                end_row = 3361
                first_column = 2
                last_column = 9
                ltv_row = 3348
                ltv_adjustment 3334, 3379, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end

              if value == "LOAN AMOUNT"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3363
                end_row = 3365
                first_column = 2
                last_column = 10
                ltv_row = 3254
                ltv_adjustment 3334, 3379, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
            # PREPAYMENT PENALTY #adjustment remaining
          end
        end
        adjustment = [@spec_adjustment10,@day_adjustment4]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def non_qm_real_dsc_ratio
    @xlsx.sheets.each do |sheet|
      if (sheet == "RATESHEET")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @spec_adjustment11 = {}
        @day_adjustment5 = {}
        # # NON-QM: R.E.A.L DSC RATIO /Programs
        (3433..3445).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 7))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3*max_column + 2 # 2 / 5 / 8
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && (cc <= 15) && @title.class == String #&& @title != "N/A"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @sheet_name = @program.sub_sheet.name
                  p_name = @title + " " + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..2).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][30] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # NON-QM: R.E.A.L DSC RATIO /Adjustment
        (3433..3527).each do |r|
          (0..sheet_data.last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value == "PROGRAM SPECIFIC RATE ADJUSTMENTS"
                primary_key = "LoanType / RateLock"
                @spec_adjustment11[primary_key] = {}
              end

              if r >= 3508 && r <= 3526 && cc == 16
                c_val = sheet_data.cell(r,cc+4)
                @spec_adjustment11[primary_key][value] = c_val
              end

              if value == "45 Day Lock (Price Adjustment)"
                primary_key = "RateType/LoanType/RateLock"
                c_val = sheet_data.cell(3445,20)
                @day_adjustment5[primary_key] = {}
                @day_adjustment5[primary_key][value] = c_val
              end

              if value == "FICO"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3512
                end_row = 3519
                first_column = 2
                last_column = 9
                ltv_row = 3509
                ltv_adjustment 3433, 3527, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end

              if value == "LOAN AMOUNT"
                primary_key = "LoanType/LTV/FICO"
                first_row = 3521
                end_row = 3527
                first_column = 2
                last_column = 10
                ltv_row = 3509
                ltv_adjustment 3433, 3527, sheet_data, first_row, end_row,sheet,first_column, last_column, ltv_row, primary_key
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@spec_adjustment11,@day_adjustment5]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_sun_west_wholesale_demo5907_path(@sheet_obj)
  end

  def programs
    @programs = @sheet_obj.programs
  end

  def single_program
  end

  private

    def read_sheet
			file = File.join(Rails.root + "other_sheets", 'OB_SunWest_Wholesale_Demo5907.xls')
      @xlsx = Roo::Spreadsheet.open(file)
    end

    def get_value value1
      if value1.present?
        if value1.include?("<=") || value1.include?("<")
          value1 = "0-"+value1.split("<=").last.tr('A-Za-z%$><= ','')
          value1 = value1.tr('–','-')
        elsif value1.include?(">") || value1.include?("+")
          value1 = value1.split(">").last.tr('A-Z=% ', '')+"-Inf"
          value1 = value1.tr('–','-')
        else
          value1 = value1.tr('A-Za-z% ','')
          value1 = value1.tr('–','-')
        end
      end
    end

    def get_sheet
      @sheet_obj = SubSheet.find(params[:id])
    end

    def get_program
      @program = Program.find(params[:id])
    end

    def program_property title
      # term
      if title.downcase.exclude?('arm')
        if title.scan(/\d+/).count > 1
          term = title.scan(/\d+/)[0] + term = title.scan(/\d+/)[1]  
        else
          term = title.scan(/\d+/)[0]
        end
      end

      # Arm Basic
      if title.include?("3/1") || title.include?("3 / 1")
        arm_basic = 3
      elsif title.include?("5/1") || title.include?("5 / 1")
        arm_basic = 5
      elsif title.include?("7/1") || title.include?("7 / 1")
        arm_basic = 7
      elsif title.include?("10/1") || title.include?("10 / 1") || title.include?("10 /1")
        arm_basic = 10
      end

       # Program Category
      if @program.program_name.include?("F30/F25")
        program_category = "F30/F25"
      elsif @program.program_name.include?("F15")
        program_category = "F15"
      elsif @program.program_name.include?("f30J")
        program_category = "f30J"
      elsif @program.program_name.include?("F15S")
        program_category = "F15S"
      elsif @program.program_name.include?("F30JS")
        program_category = "F30JS"
      elsif @program.program_name.include?("F5YT")
        program_category = "F5YT"
      elsif @program.program_name.include?("F5YTS")
        program_category = "F5YTS"
      elsif @program.program_name.include?("F5YTJ")
        program_category = "F5YTJ"
      end

      @program.update(term: term,program_category: program_category, arm_basic: arm_basic)
    end

    def ltv_adjustment range1, range2, sheet_data, first_row, end_row, sheet, first_column, last_column, ltv_row, primary_key
      @adjustment_hash = {}
      @adjustment_hash[primary_key] = {}
      @adjustment_hash[primary_key]["Conforming"] = {}
      @adjustment_hash[primary_key]["Conforming"]["15-Inf"] = {}
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
                if r >= first_row && r <= end_row && cc == first_column
                  ltv_key = get_value value
                  @adjustment_hash[primary_key]["Conforming"]["15-Inf"][ltv_key] = {}
                end
                if r >= first_row && r <= end_row && cc > first_column && cc <= last_column
                  cltv_key = get_value @ltv_data[cc-2]
                  @adjustment_hash[primary_key]["Conforming"]["15-Inf"][ltv_key][cltv_key] = {}
                  @adjustment_hash[primary_key]["Conforming"]["15-Inf"][ltv_key][cltv_key] = value
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
    end

    def cash_adjustment range1, range2, sheet_data, first_row, end_row, sheet, first_column, last_column, ltv_row, primary_key
      @adjustment_hash = {}
      @adjustment_hash[primary_key] = {}
      @adjustment_hash[primary_key]["Conforming"] = {}
      @adjustment_hash[primary_key]["Conforming"]["Cash Out"] = {}
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
                if r >= first_row && r <= end_row && cc == first_column
                  ltv_key = get_value value
                  @adjustment_hash[primary_key]["Conforming"]["Cash Out"][ltv_key] = {}
                end
                if r >= first_row && r <= end_row && cc > first_column && cc <= last_column
                  cltv_key = get_value @ltv_data[cc-2]
                  @adjustment_hash[primary_key]["Conforming"]["Cash Out"][ltv_key][cltv_key] = {}
                  @adjustment_hash[primary_key]["Conforming"]["Cash Out"][ltv_key][cltv_key] = value
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
    end

    def lpmi_adjustment range1, range2, sheet_data, first_row, end_row, sheet, first_column, last_column, ltv_row, primary_key
      @adjustment_hash = {}
      @adjustment_hash[primary_key] = {}
      @adjustment_hash[primary_key]["true"] = {}
      @adjustment_hash[primary_key]["true"]["Conforming"] = {}
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
                if r >= first_row && r <= end_row && cc == first_column
                  ltv_key = get_value value
                  @adjustment_hash[primary_key]["true"]["Conforming"][ltv_key] = {}
                end
                if r >= first_row && r <= end_row && cc > first_column && cc <= last_column
                  cltv_key = get_value @ltv_data[cc-2]
                  @adjustment_hash[primary_key]["true"]["Conforming"][ltv_key][cltv_key] = {}
                  @adjustment_hash[primary_key]["true"]["Conforming"][ltv_key][cltv_key] = value
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
    end

    def sub_adjustment range1, range2, sheet_data, first_row, end_row, sheet, first_column, cltv_column, last_column, ltv_row, primary_key
      @adjustment_hash = {}
      @adjustment_hash[primary_key] = {}
      @adjustment_hash[primary_key]["Subordinate Financing"] = {}
      @adjustment_hash[primary_key]["Subordinate Financing"]["Conforming"] = {}
      ltv_key = ''
      cltv_key = ''
      new_key = ''
      (range1..range2).each do |r|
        row = sheet_data.row(r)
        @ltv_data = sheet_data.row(ltv_row)
        if row.compact.count >= 1
          (0..last_column).each do |cc|
            begin
              value = sheet_data.cell(r,cc)
              if value.present?
                if r >= first_row && r <= end_row && cc == first_column
                  ltv_key = get_value value
                  @adjustment_hash[primary_key]["Subordinate Financing"]["Conforming"][ltv_key] = {}
                end
                if r >= first_row && r <= end_row && cc == cltv_column
                  new_key = get_value value
                  @adjustment_hash[primary_key]["Subordinate Financing"]["Conforming"][ltv_key][new_key] = {}
                end
                if r >= first_row && r <= end_row && cc > cltv_column && cc <= last_column
                  cltv_key = get_value @ltv_data[cc-2]
                  @adjustment_hash[primary_key]["Subordinate Financing"]["Conforming"][ltv_key][new_key][cltv_key] = {}
                  @adjustment_hash[primary_key]["Subordinate Financing"]["Conforming"][ltv_key][new_key][cltv_key] = value
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
    end

    def make_adjust(block_hash, sheet)
      block_hash.each do |hash|
        if hash.keys.count > 1
          hash.keys.each do |key|
            second_hash = {}
            second_hash[key] = hash[key]
            Adjustment.create(data: second_hash,loan_category: sheet)
          end
        else
          Adjustment.create(data: hash,loan_category: sheet)
        end
      end
    end

    def get_sheets_names
      return ["AGENCY CONFORMING PROGRAMS","FHLMC HOME POSSIBLE","NON CONFORMING SIGMA QM PRIME JUMBO","NON CONFORMING JW","GOVERNMENT PROGRAMS","HECM REVERSE MORTGAGE", "NON QM SIGMA SEASONED CREDIT EVENT","NON QM SIGMA NO CREDIT EVENT PLUS","NON QM REAL PRIME ADVANTAGE","NON QM REAL CREDIT ADVANTAGE A","NON QM REAL CREDIT ADVANTAGE BBC","NON QM REAL INVESTOR INCOME A","NON QM REAL INVESTOR INCOME BB","NON QM REAL DSC RATIO"]
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
