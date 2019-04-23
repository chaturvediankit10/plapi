class RateSheetExtractor::ObCardinalFinancialWholesale10742Controller < RateSheetExtractor::ApplicationController
  before_action :read_sheet, only: [:index,:ak, :fannie_mae_products, :freddie_mac_products, :fha_va_usda_products, :non_conforming_jumbo_core, :non_conforming_jumbo_x]
  # before_action :check_sheet_empty , only:[:ak, :sheet1]
  before_action :get_sheet, only: [:programs, :ak, :fannie_mae_products, :freddie_mac_products, :fha_va_usda_products, :non_conforming_jumbo_core, :non_conforming_jumbo_x]
  before_action :get_program, only: [:single_program, :program_property]


  def index
    sub_sheet_names = get_sheets_names
    begin
      @xlsx.sheets.each do |sheet|
        if (sheet == "AK")
          headers = ["Phone", "General Contacts", "Mortgagee Clause (Wholesale)"]
          @name = "Cardinal Financial"
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

  def ak
    @xlsx.sheets.each do |sheet|
      if (sheet == "AK")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @ltv_data = []
        @sub_data = []
        @lpmi_data = []
        ltv_key = ''
        primary_key = ''
        @adjustment_hash = {}
        @cashout_adjustment = {}
        @cashout_hash = {}
        @product_hash = {}
        @subordinate_hash = {}
        @sub_hash = {}
        @additional_hash = {}
        @lpmi_hash = {}
        @freddie_adjustment_hash = {}
        @relief_cashout_adjustment = {}
        @property_hash = {}
        @jumbo_hash = {}
        @non_jumbo_hash = {}
      end
    end
    redirect_to programs_ob_cardinal_financial_wholesale10742_path(@sheet_obj)
  end

  def fannie_mae_products
    @xlsx.sheets.each do |sheet|
      if (sheet == "AK")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @cashout_adjustment = {}
        @product_hash = {}
        @subordinate_hash = {}
        @additional_hash = {}
        @lpmi_hash = {}
        ltv_key = ''
        primary_key = ''
        # Fannie Mae Programs
        (71..298).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each_with_index do |max_column, index|
              index = index +1
              cc = 1 + max_column*10 + index# (2 / 13 / 24 / 35)
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  @sheet_name = @program.sub_sheet.name
                  # Program Property
                  p_name = @title + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..8).each_with_index do |index, c_i|
                      rrr = rr + max_row +1
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][15*(c_i/2)] = value unless @block_hash[key].nil?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                end
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Fannie Mae Adjustments
        (353..429).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(356)
          @sub_data = sheet_data.row(386)
          @lpmi_data = sheet_data.row(410)
          if row.compact.count >= 1
            (2..42).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Fannie Mae Loan Level Price Adjustments"
                    @adjustment_hash["FannieMae/Term/FICO/LTV"] = {}
                    @adjustment_hash["FannieMae/Term/FICO/LTV"]["true"] = {}
                    @adjustment_hash["FannieMae/Term/FICO/LTV"]["true"]["15-Inf"] = {}
                  end
                  # if value == "Lender Paid Mortgage Insurance"
                  #   @lpmi_hash["LPMI/Term/FICO/LTV"] = {}
                  #   @lpmi_hash["LPMI/Term/FICO/LTV"]["true"] = {}
                  #   @lpmi_hash["LPMI/Term/FICO/LTV"]["true"]["20-Inf"] = {}
                  # end
                  if value == "All Eligible Mortgages  Cash-Out Refinance  LLPAs"
                    @cashout_adjustment["FannieMae/RefinanceOption/FICO/LTV"] = {}
                    @cashout_adjustment["FannieMae/RefinanceOption/FICO/LTV"]["true"] = {}
                    @cashout_adjustment["FannieMae/RefinanceOption/FICO/LTV"]["true"]["Cash Out"] = {}
                  end
                  if value == "All Eligible Mortgages Product Feature  LLPAs"
                    @product_hash["FannieMae/LoanSize/RefinanceOption/LTV"] = {}
                    @product_hash["FannieMae/LoanSize/RefinanceOption/LTV"]["true"] = {}
                    @product_hash["FannieMae/LoanSize/RefinanceOption/LTV"]["true"]["High-Balance"] = {}
                    @product_hash["FannieMae/LoanSize/RefinanceOption/LTV"]["true"]["High-Balance"]["Rate and Term"] = {}
                    @product_hash["FannieMae/LoanSize/RefinanceOption/LTV"]["true"]["High-Balance"]["Cash Out"] = {}
                  end
                  if value == "Mortgages with Subordinate Financing4"
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"] = {}
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"] = {}
                  end

                  # All Eligible Mortgages - LLPAs for Terms > 15 Years
                  if r >= 357 && r <= 365 && cc == 9
                    ltv_key = get_value value
                    @adjustment_hash["FannieMae/Term/FICO/LTV"]["true"]["15-Inf"][ltv_key] = {}
                  end
                  if r >= 357 && r <= 365 && cc >= 18 && cc <= 44
                    ltv_data =  get_value @ltv_data[cc-2]
                    @adjustment_hash["FannieMae/Term/FICO/LTV"]["true"]["15-Inf"][ltv_key][ltv_data] = {}
                    @adjustment_hash["FannieMae/Term/FICO/LTV"]["true"]["15-Inf"][ltv_key][ltv_data] = value
                  end

                  # All Eligible Mortgages  Cash-Out Refinance  LLPAs
                  if r >= 367 && r <= 373 && cc == 9
                    ltv_key = get_value value
                    @cashout_adjustment["FannieMae/RefinanceOption/FICO/LTV"]["true"]["Cash Out"][ltv_key] = {}
                  end
                  if r >= 367 && r <= 373 && cc >= 18 && cc <= 44
                    ltv_data =  get_value @ltv_data[cc-2]
                    @cashout_adjustment["FannieMae/RefinanceOption/FICO/LTV"]["true"]["Cash Out"][ltv_key][ltv_data] = {}
                    @cashout_adjustment["FannieMae/RefinanceOption/FICO/LTV"]["true"]["Cash Out"][ltv_key][ltv_data] = value
                  end

                  # All Eligible Mortgages Product Feature  LLPAs
                  if r == 375 && cc == 9
                    @product_hash["FannieMae/LoanType/LTV"] = {}
                    @product_hash["FannieMae/LoanType/LTV"]["true"] = {}
                    @product_hash["FannieMae/LoanType/LTV"]["true"]["ARM"] = {}
                  end
                  if r == 375 && cc >= 18 && cc <= 44
                    ltv_data =  get_value @ltv_data[cc-2]
                    @product_hash["FannieMae/LoanType/LTV"]["true"]["ARM"][ltv_data] = {}
                    @product_hash["FannieMae/LoanType/LTV"]["true"]["ARM"][ltv_data] = value
                  end
                  if r == 376 && cc == 9
                    @product_hash["FannieMae/PropertyType/LTV"] = {}
                    @product_hash["FannieMae/PropertyType/LTV"]["true"] = {}
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["Manufactured Home"] = {}
                  end
                  if r == 376 && cc >= 18 && cc <= 44
                    ltv_data =  get_value @ltv_data[cc-2]
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["Manufactured Home"][ltv_data] = {}
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["Manufactured Home"][ltv_data] = value
                  end
                  if r == 377 && cc == 9
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["Investment Property"] = {}
                  end
                  if r == 377 && cc >= 18 && cc <= 44
                    ltv_data =  get_value @ltv_data[cc-2]
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["Investment Property"][ltv_data] = {}
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["Investment Property"][ltv_data] = value
                  end
                  if r == 378 && cc >= 18 && cc <= 44
                    ltv_data =  get_value @ltv_data[cc-2]
                    @product_hash["FannieMae/LoanSize/RefinanceOption/LTV"]["true"]["High-Balance"]["Rate and Term"][ltv_data] = {}
                    @product_hash["FannieMae/LoanSize/RefinanceOption/LTV"]["true"]["High-Balance"]["Rate and Term"][ltv_data] = value
                  end
                  if r == 379 && cc >= 18 && cc <= 44
                    ltv_data =  get_value @ltv_data[cc-2]
                    @product_hash["FannieMae/LoanSize/RefinanceOption/LTV"]["true"]["High-Balance"]["Cash Out"][ltv_data] = {}
                    @product_hash["FannieMae/LoanSize/RefinanceOption/LTV"]["true"]["High-Balance"]["Cash Out"][ltv_data] = value
                  end
                  if r == 380 && cc == 9
                    @product_hash["FannieMae/LoanSize/LoanType/LTV"] = {}
                    @product_hash["FannieMae/LoanSize/LoanType/LTV"]["true"] = {}
                    @product_hash["FannieMae/LoanSize/LoanType/LTV"]["true"]["High-Balance"] = {}
                    @product_hash["FannieMae/LoanSize/LoanType/LTV"]["true"]["High-Balance"]["ARM"] = {}
                  end
                  if r == 380 && cc >= 18 && cc <= 44
                    ltv_data =  get_value @ltv_data[cc-2]
                    @product_hash["FannieMae/LoanSize/LoanType/LTV"]["true"]["High-Balance"]["ARM"][ltv_data] = {}
                    @product_hash["FannieMae/LoanSize/LoanType/LTV"]["true"]["High-Balance"]["ARM"][ltv_data] = value
                  end
                  if r == 381 && cc == 9
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["2-4 Unit"] = {}
                  end
                  if r == 381 && cc >= 18 && cc <= 44
                    ltv_data =  get_value @ltv_data[cc-2]
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["2-4 Unit"][ltv_data] = {}
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["2-4 Unit"][ltv_data] = value
                  end
                  if r == 382 && cc == 9
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["Condo"] = {}
                  end
                  if r == 382 && cc >= 18 && cc <= 44
                    ltv_data =  get_value @ltv_data[cc-2]
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["Condo"][ltv_data] = {}
                    @product_hash["FannieMae/PropertyType/LTV"]["true"]["Condo"][ltv_data] = value
                  end

                  # subordinate adjustment
                  if r == 387 && cc == 6
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"]["0-Inf"] = {}
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"]["0-Inf"]["0-Inf"] = {}
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"]["0-Inf"]["0-Inf"]["0-720"] = {}
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"]["0-Inf"]["0-Inf"]["720-Inf"] = {}
                  end
                  if r == 387 && cc >= 12 && cc <= 15
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"]["0-Inf"]["0-Inf"]["0-720"] = value
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"]["0-Inf"]["0-Inf"]["720-Inf"] = value
                  end
                  if r >= 388 && r <= 392 && cc == 6
                    primary_key = get_value value
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key] = {}
                  end
                  if r >= 388 && r <= 392 && cc == 9
                    ltv_key = get_value value
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key] = {}
                  end
                  if r >= 388 && r <= 392 && cc >= 12 && cc <= 15
                    sub_data = get_value @sub_data[cc-2]
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key][sub_data] = {}
                    @subordinate_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key][sub_data] = value
                  end
                  # Additional Adjustments5
                  if r == 394 && cc == 6
                    @additional_hash["RefinanceOption"] = {}
                    @additional_hash["RefinanceOption"]["Cash Out"] = {}
                    cc = cc + 8
                    new_val = sheet_data.cell(r,cc)
                    @additional_hash["RefinanceOption"]["Cash Out"] = new_val
                  end
                  if r == 395 && cc == 6
                    @additional_hash["MiscAdjuster/FICO"] = {}
                    @additional_hash["MiscAdjuster/FICO"]["Escrow Waiver"] = {}
                    @additional_hash["MiscAdjuster/FICO"]["Escrow Waiver"]["0-700"] = {}
                    cc = cc + 8
                    new_val = sheet_data.cell(r,cc)
                    @additional_hash["MiscAdjuster/FICO"]["Escrow Waiver"]["0-700"] = new_val
                  end
                  if r == 396 && cc == 6
                    @additional_hash["MiscAdjuster/State/FICO"] = {}
                    @additional_hash["MiscAdjuster/State/FICO"]["Escrow Waiver"] = {}
                    @additional_hash["MiscAdjuster/State/FICO"]["Escrow Waiver"]["CA"] = {}
                    @additional_hash["MiscAdjuster/State/FICO"]["Escrow Waiver"]["CA"]["0-700"] = {}
                    cc = cc + 8
                    new_val = sheet_data.cell(r,cc)
                    @additional_hash["MiscAdjuster/State/FICO"]["Escrow Waiver"]["CA"]["0-700"] = new_val
                  end
                  if r == 397 && cc == 6
                    @additional_hash["LoanType/LTV"] = {}
                    @additional_hash["LoanType/LTV"]["ARM"] = {}
                    @additional_hash["LoanType/LTV"]["ARM"]["90-Inf"] = {}
                    cc = cc + 8
                    new_val = sheet_data.cell(r,cc)
                    @additional_hash["LoanType/LTV"]["ARM"]["90-Inf"] = new_val
                  end
                  if r == 397 && cc == 6
                    @additional_hash["LockDay"] = {}
                    @additional_hash["LockDay"]["90"] = {}
                    cc = cc + 8
                    new_val = sheet_data.cell(r,cc)
                    @additional_hash["LockDay"]["90"] = new_val
                  end
                  if r == 404 && cc == 2
                    @additional_hash["State"] = {}
                    @additional_hash["State"]["AL"] = {}
                    cc = cc + 8
                    new_val = sheet_data.cell(r,cc)
                    @additional_hash["State"]["AL"] = new_val
                  end
                  if r == 396 && cc == 37
                    @additional_hash["FICO/LTV"] = {}
                    @additional_hash["FICO/LTV"]["680-inf"] = {}
                    @additional_hash["FICO/LTV"]["680-inf"]["80-Inf"] = {}
                    @additional_hash["FICO/LTV"]["680-inf"]["80-Inf"] = value
                  end
                  if r == 397 && cc == 37
                    @additional_hash["FICO/LTV"]["0-680"] = {}
                    @additional_hash["FICO/LTV"]["0-680"]["0-80"] = {}
                    @additional_hash["FICO/LTV"]["0-680"]["0-80"] = value
                  end
                  # Lender Paid Mortgage Insurance
                  if r == 424 && cc == 7
                    @lpmi_hash["LPMI/Term/FICO"] = {}
                    @lpmi_hash["LPMI/Term/FICO"]["true"] = {}
                    @lpmi_hash["LPMI/Term/FICO"]["true"]["0-25"] = {}
                  end
                  if r == 424 && cc >= 15 && cc <= 33
                    lpmi_key = get_value @lpmi_data[cc-2]
                    @lpmi_hash["LPMI/Term/FICO"]["true"]["0-25"][lpmi_key] = {}
                    @lpmi_hash["LPMI/Term/FICO"]["true"]["0-25"][lpmi_key] = value
                  end
                  if r == 425 && cc == 7
                    @lpmi_hash["LPMI/RefinanceOption/FICO"] = {}
                    @lpmi_hash["LPMI/RefinanceOption/FICO"]["true"] = {}
                    @lpmi_hash["LPMI/RefinanceOption/FICO"]["true"]["Cash Out"] = {}
                  end
                  if r == 425 && cc >= 15 && cc <= 33
                    lpmi_key = get_value @lpmi_data[cc-2]
                    @lpmi_hash["LPMI/RefinanceOption/FICO"]["true"]["Cash Out"][lpmi_key] = {}
                    @lpmi_hash["LPMI/RefinanceOption/FICO"]["true"]["Cash Out"][lpmi_key] = value
                  end
                  if r == 426 && cc == 7
                    @lpmi_hash["LPMI/PropertyType/FICO"] = {}
                    @lpmi_hash["LPMI/PropertyType/FICO"]["true"] = {}
                    @lpmi_hash["LPMI/PropertyType/FICO"]["true"]["Investment Property"] = {}
                  end
                  if r == 426 && cc >= 15 && cc <= 33
                    lpmi_key = get_value @lpmi_data[cc-2]
                    @lpmi_hash["LPMI/PropertyType/FICO"]["true"]["Investment Property"][lpmi_key] = {}
                    @lpmi_hash["LPMI/PropertyType/FICO"]["true"]["Investment Property"][lpmi_key] = value
                  end
                  if r == 427 && cc == 7
                    @lpmi_hash["LPMI/LoanAmount/FICO"] = {}
                    @lpmi_hash["LPMI/LoanAmount/FICO"]["true"] = {}
                    @lpmi_hash["LPMI/LoanAmount/FICO"]["true"]["484350-Inf"] = {}
                  end
                  if r == 427 && cc >= 15 && cc <= 33
                    lpmi_key = get_value @lpmi_data[cc-2]
                    @lpmi_hash["LPMI/LoanAmount/FICO"]["true"]["484350-Inf"][lpmi_key] = {}
                    @lpmi_hash["LPMI/LoanAmount/FICO"]["true"]["484350-Inf"][lpmi_key] = value
                  end
                  if r == 428 && cc == 7
                    @lpmi_hash["LPMI/RefinanceOption/LTV"]["true"]["Rate and Term"] = {}
                  end
                  if r == 428 && cc >= 15 && cc <= 33
                    lpmi_key = get_value @lpmi_data[cc-2]
                    @lpmi_hash["LPMI/RefinanceOption/LTV"]["true"]["Rate and Term"][lpmi_key] = {}
                    @lpmi_hash["LPMI/RefinanceOption/LTV"]["true"]["Rate and Term"][lpmi_key] = value
                  end
                  if r == 429 && cc == 7
                    @lpmi_hash["LPMI/PropertyType/LTV"]["true"]["2nd Home"] = {}
                  end
                  if r == 429 && cc >= 15 && cc <= 33
                    lpmi_key = get_value @lpmi_data[cc-2]
                    @lpmi_hash["LPMI/PropertyType/LTV"]["true"]["2nd Home"][lpmi_key] = {}
                    @lpmi_hash["LPMI/PropertyType/LTV"]["true"]["2nd Home"][lpmi_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@cashout_adjustment,@product_hash,@subordinate_hash,@additional_hash,@lpmi_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_cardinal_financial_wholesale10742_path(@sheet_obj)
  end

  def freddie_mac_products
    @xlsx.sheets.each do |sheet|
      if (sheet == "AK")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @freddie_adjustment_hash = {}
        @cashout_hash = {}
        @sub_hash = {}
        @property_hash = {}
        @sub_hash = {}
        ltv_key = ''
        primary_key = ''
        (458..684).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each_with_index do |max_column, index|
              index = index +1
              cc = 1 + max_column*10 + index# (2 / 13 / 24 / 35)
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  @sheet_name = @program.sub_sheet.name
                  # Program Property
                  p_name = @title + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..8).each_with_index do |index, c_i|
                      rrr = rr + max_row +1
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          if @program.lock_period.length <= 3
                            @program.lock_period << 15*(c_i/2)
                            @program.save
                          end
                          @block_hash[key][15*(c_i/2)] = value unless @block_hash[key].nil?
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
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # Freddie Adjustments
        (740..835).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(743)
          @sub_data = sheet_data.row(785)
          @lpmi_data = sheet_data.row(816)
          if row.compact.count >= 1
            (2..42).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Freddie Mac Loan Level Price Adjustments"
                    @freddie_adjustment_hash["FreddieMac/Term/FICO/LTV"] = {}
                    @freddie_adjustment_hash["FreddieMac/Term/FICO/LTV"]["true"] = {}
                    @freddie_adjustment_hash["FreddieMac/Term/FICO/LTV"]["true"]["15-Inf"] = {}
                  end
                  if value == "All Eligible Mortgages - Relief Refinance Mortgages - LLPAs for Terms > 15 Years"
                    @freddie_adjustment_hash["FreddieMac/LoanPurpose/Term/FICO/LTV"] = {}
                    @freddie_adjustment_hash["FreddieMac/LoanPurpose/Term/FICO/LTV"]["true"] = {}
                    @freddie_adjustment_hash["FreddieMac/LoanPurpose/Term/FICO/LTV"]["true"]["Refinance"] = {}
                    @freddie_adjustment_hash["FreddieMac/LoanPurpose/Term/FICO/LTV"]["true"]["Refinance"]["15-Inf"] = {}
                  end
                  if value == "All Eligible Mortgages  Cash-Out Refinance  LLPAs"
                    @cashout_hash["FreddieMac/RefinanceOption/FICO/LTV"] = {}
                    @cashout_hash["FreddieMac/RefinanceOption/FICO/LTV"]["true"] = {}
                    @cashout_hash["FreddieMac/RefinanceOption/FICO/LTV"]["true"]["Cash Out"] = {}
                  end
                  if value == "Mortgages with Subordinate Financing5 - Other Than Relief Refinance Mortgages"
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"] = {}
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"] = {}
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"] = {}
                  end
                  if value == "Mortgages with Subordinate Financing7- Relief Refinance Mortgages"
                    @sub_hash["FinancingType/LTV/CLTV/FICO"] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"] = {}
                  end

                  # All Eligible Mortgages - Other Than Relief Refinance Mortgages - LLPAs for Terms > 15 Years
                  if r >= 744 && r <= 750 && cc == 10
                    ltv_key = get_value value
                    @freddie_adjustment_hash["FreddieMac/Term/FICO/LTV"]["true"]["15-Inf"][ltv_key] = {}
                  end
                  if r >= 744 && r <= 750 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @freddie_adjustment_hash["FreddieMac/Term/FICO/LTV"]["true"]["15-Inf"][ltv_key][ltv_data] = {}
                    @freddie_adjustment_hash["FreddieMac/Term/FICO/LTV"]["true"]["15-Inf"][ltv_key][ltv_data] = value
                  end

                  # All Eligible Mortgages - Relief Refinance Mortgages - LLPAs for Terms > 15 Years
                  if r >= 752 && r <= 760 && cc == 10
                    ltv_key = get_value value
                    @freddie_adjustment_hash["FreddieMac/LoanPurpose/Term/FICO/LTV"]["true"]["Refinance"]["15-Inf"][ltv_key] = {}
                  end
                  if r >= 752 && r <= 760 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @freddie_adjustment_hash["FreddieMac/LoanPurpose/Term/FICO/LTV"]["true"]["Refinance"]["15-Inf"][ltv_key][ltv_data] = {}
                    @freddie_adjustment_hash["FreddieMac/LoanPurpose/Term/FICO/LTV"]["true"]["Refinance"]["15-Inf"][ltv_key][ltv_data] = value
                  end

                  # All Eligible Mortgages  Cash-Out Refinance  LLPAs
                  if r >= 762 && r <= 768 && cc == 10
                    ltv_key = get_value value
                    @cashout_hash["FreddieMac/RefinanceOption/FICO/LTV"]["true"]["Cash Out"][ltv_key] = {}
                  end
                  if r >= 762 && r <= 768 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @cashout_hash["FreddieMac/RefinanceOption/FICO/LTV"]["true"]["Cash Out"][ltv_key][ltv_data] = {}
                    @cashout_hash["FreddieMac/RefinanceOption/FICO/LTV"]["true"]["Cash Out"][ltv_key][ltv_data] = value
                  end

                  # # All Eligible Mortgages Product Feature  LLPAs
                  if r == 770 && cc == 10
                    @property_hash["FreddieMac/LoanType/LTV"] = {}
                    @property_hash["FreddieMac/LoanType/LTV"]["true"] = {}
                    @property_hash["FreddieMac/LoanType/LTV"]["true"]["ARM"] = {}
                  end
                  if r == 770 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @property_hash["FreddieMac/LoanType/LTV"]["true"]["ARM"][ltv_data] = {}
                    @property_hash["FreddieMac/LoanType/LTV"]["true"]["ARM"][ltv_data] = value
                  end
                  if r == 771 && cc == 10
                    @property_hash["FreddieMac/PropertyType/LTV"] = {}
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"] = {}
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["Manufactured Home"] = {}
                  end
                  if r == 771 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["Manufactured Home"][ltv_data] = {}
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["Manufactured Home"][ltv_data] = value
                  end
                  if r == 772 && cc == 10
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["Condo"] = {}
                  end
                  if r == 772 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["Condo"][ltv_data] = {}
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["Condo"][ltv_data] = value
                  end
                  if r == 773 && cc == 10
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["Investment Property"] = {}
                  end
                  if r == 773 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["Investment Property"][ltv_data] = {}
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["Investment Property"][ltv_data] = value
                  end
                  if r == 774 && cc == 10
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["2nd Home"] = {}
                  end
                  if r == 774 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["2nd Home"][ltv_data] = {}
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["2nd Home"][ltv_data] = value
                  end
                  if r == 775 && cc == 10
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["2 Unit"] = {}
                  end
                  if r == 775 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["2 Unit"][ltv_data] = {}
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["2 Unit"][ltv_data] = value
                  end
                  if r == 776 && cc == 10
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["3-4 Unit"] = {}
                  end
                  if r == 776 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["3-4 Unit"][ltv_data] = {}
                    @property_hash["FreddieMac/PropertyType/LTV"]["true"]["3-4 Unit"][ltv_data] = value
                  end
                  if r == 777 && cc == 10
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"] = {}
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"] = {}
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Purchase"] = {}
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Purchase"]["Fixed"] = {}
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Purchase"]["Fixed"]["Conforming"] = {}
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Purchase"]["Fixed"]["Conforming"]["Rate and Term"] = {}
                  end
                  if r == 777 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Purchase"]["Fixed"]["Conforming"]["Rate and Term"][ltv_data] = {}
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Purchase"]["Fixed"]["Conforming"]["Rate and Term"][ltv_data] = value
                  end
                  if r == 778 && cc == 10
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"] = {}
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"]["true"] = {}
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Fixed"] = {}
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Fixed"]["Conforming"] = {}
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Fixed"]["Conforming"]["Cash Out"] = {}
                  end
                  if r == 778 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Fixed"]["Conforming"]["Cash Out"][ltv_data] = {}
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Fixed"]["Conforming"]["Cash Out"][ltv_data] = value
                  end
                  if r == 779 && cc == 10
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Purchase"]["ARM"] = {}
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Purchase"]["ARM"]["Conforming"] = {}
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Purchase"]["ARM"]["Conforming"]["Rate and Term"] = {}
                  end
                  if r == 779 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Purchase"]["ARM"]["Conforming"]["Rate and Term"][ltv_data] = {}
                    @property_hash["FreddieMac/LoanPurpose/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["Purchase"]["ARM"]["Conforming"]["Rate and Term"][ltv_data] = value
                  end
                  if r == 780 && cc == 10
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["ARM"] = {}
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["ARM"]["Conforming"] = {}
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["ARM"]["Conforming"]["Cash Out"] = {}
                  end
                  if r == 780 && cc >= 21 && cc <= 42
                    ltv_data =  get_value @ltv_data[cc-2]
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["ARM"]["Conforming"]["Cash Out"][ltv_data] = {}
                    @property_hash["FreddieMac/LoanType/LoanSize/RefinanceOption/LTV"]["true"]["ARM"]["Conforming"]["Cash Out"][ltv_data] = value
                  end
                  # # subordinate adjustment
                  if r == 786 && cc == 7
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"]["0-Inf"] = {}
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"]["0-Inf"]["0-Inf"] = {}
                  end
                  if r == 786 && cc == 15
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"]["0-Inf"]["0-Inf"]["0-720"] = {}
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"]["0-Inf"]["0-Inf"]["720-Inf"] = {}
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"]["0-Inf"]["0-Inf"]["0-720"] = value
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"]["0-Inf"]["0-Inf"]["720-Inf"] = value
                  end
                  if r >= 787 && r <= 790 && cc == 7
                    primary_key = get_value value
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"][primary_key] = {}
                  end
                  if r >= 787 && r <= 790 && cc == 11
                    ltv_key = get_value value
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"][primary_key][ltv_key] = {}
                  end
                  if r >= 787 && r <= 790 && cc >= 15 && cc <= 18
                    sub_data = get_value @sub_data[cc-2]
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"][primary_key][ltv_key][sub_data] = {}
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"][primary_key][ltv_key][sub_data] = value
                  end
                  if r >= 791 && r <= 792 && cc == 7
                    primary_key = get_value value
                    ltv_key = get_value value
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"][primary_key] = {}
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"][primary_key][ltv_key] = {}
                  end
                  if r >= 791 && r <= 792 && cc == 15
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"][primary_key][ltv_key]["0-720"] = {}
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"][primary_key][ltv_key]["720-Inf"] = {}
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"][primary_key][ltv_key]["0-720"] = value
                    @sub_hash["FinancingType/FreddieMacProduct/LTV/CLTV/FICO"]["Subordinate Financing"]["Home Possible"][primary_key][ltv_key]["720-Inf"] = value
                  end
                  # Mortgages with Subordinate Financing7- Relief Refinance Mortgages
                  if r >= 796 && r <= 802 && cc == 7
                    if value.downcase.include?('all')
                      primary_key = "0-Inf"
                    else
                      primary_key = get_value value
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key] = {}
                  end
                  if r >= 796 && r <= 802 && cc == 11
                    ltv_key = get_value value
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key] = {}
                  end
                  if r >= 796 && r <= 802 && cc >= 15 && cc <= 18
                    sub_data = get_value @sub_data[cc-2]
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key][sub_data] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key][sub_data] = value
                  end
                  # Add Adj9
                  if r == 808 && cc == 37
                    @sub_hash["RefinanceOption"] = {}
                    @sub_hash["RefinanceOption"]["Rate and Term"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @sub_hash["RefinanceOption"]["Rate and Term"] = new_val
                  end
                  if r == 809 && cc == 37
                    @sub_hash["MiscAdjuster/FICO"] = {}
                    @sub_hash["MiscAdjuster/FICO"]["Escrow Waiver"] = {}
                    @sub_hash["MiscAdjuster/FICO"]["Escrow Waiver"]["0-700"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @sub_hash["MiscAdjuster/FICO"]["Escrow Waiver"]["0-700"] = new_val
                  end
                  if r == 810 && cc == 37
                    @sub_hash["MiscAdjuster/State/FICO"] = {}
                    @sub_hash["MiscAdjuster/State/FICO"]["Escrow Waiver"] = {}
                    @sub_hash["MiscAdjuster/State/FICO"]["Escrow Waiver"]["CA"] = {}
                    @sub_hash["MiscAdjuster/State/FICO"]["Escrow Waiver"]["CA"]["0-700"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @sub_hash["MiscAdjuster/State/FICO"]["Escrow Waiver"]["CA"]["0-700"] = new_val
                  end
                  if r == 811 && cc == 37
                    @sub_hash["LockDay"] = {}
                    @sub_hash["LockDay"]["90"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @sub_hash["LockDay"]["90"] = new_val
                  end
                  if r == 812 && cc == 37
                    @sub_hash["LoanType/LTV"] = {}
                    @sub_hash["LoanType/LTV"]["ARM"] = {}
                    @sub_hash["LoanType/LTV"]["ARM"]["90-Inf"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @sub_hash["LoanType/LTV"]["ARM"]["90-Inf"] = new_val
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@freddie_adjustment_hash,@cashout_hash,@sub_hash,@property_hash,@sub_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_cardinal_financial_wholesale10742_path(@sheet_obj)
  end

  def fha_va_usda_products
    @xlsx.sheets.each do |sheet|
      if (sheet == "AK")
        sheet_data = @xlsx.sheet(sheet)
         @programs_ids = []
         @relief_cashout_adjustment = {}
        # FHA Va Usda programs
        (844..1006).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each_with_index do |max_column, index|
              index = index +1
              cc = 1 + max_column*10 + index# (2 / 13 / 24 / 35)
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  @sheet_name = @program.sub_sheet.name
                  # Program Property
                  p_name = @title + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..8).each_with_index do |index, c_i|
                      rrr = rr + max_row +1
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          if @program.lock_period.length <= 3
                            @program.lock_period << 15*(c_i/2)
                            @program.save
                          end
                          @block_hash[key][15*(c_i/2)] = value unless @block_hash[key].nil?
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
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # FHA Va Usda Adjustments
        (1032..1054).each do |r|
          row = sheet_data.row(r)
          if row.compact.count >= 1
            (2..43).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "FHA, VA, and USDA Loan Level Price Adjustments"
                    @relief_cashout_adjustment["FHA/FICO"] = {}
                    @relief_cashout_adjustment["FHA/FICO"]["true"] = {}
                    @relief_cashout_adjustment["USDA/FICO"] = {}
                    @relief_cashout_adjustment["USDA/FICO"]["true"] = {}
                    @relief_cashout_adjustment["VA/FICO"] = {}
                    @relief_cashout_adjustment["VA/FICO"]["true"] = {}
                  end
                  # FHA, VA, and USDA Loan Level Price Adjustments
                  if r >= 1036 && r <= 1045 && cc == 8
                    if value == "*No Credit or Mortgage History Only"
                      primary_key = "0-579"
                    else
                      primary_key = get_value value
                    end
                    @relief_cashout_adjustment["FHA/FICO"]["true"][primary_key] = {}
                    @relief_cashout_adjustment["USDA/FICO"]["true"][primary_key] = {}
                    @relief_cashout_adjustment["VA/FICO"]["true"][primary_key] = {}
                    cc1 = cc + 13
                    cc2 = cc + 19
                    cc = cc + 7
                    new_val = sheet_data.cell(r,cc)
                    new_val1 = sheet_data.cell(r,cc1)
                    new_val2 = sheet_data.cell(r,cc2)
                    @relief_cashout_adjustment["FHA/FICO"]["true"][primary_key] = new_val
                    @relief_cashout_adjustment["USDA/FICO"]["true"][primary_key] = new_val1
                    @relief_cashout_adjustment["VA/FICO"]["true"][primary_key] = new_val2
                  end
                  if r == 1048 && cc == 8
                    @relief_cashout_adjustment["VA/PropertyType"] = {}
                    @relief_cashout_adjustment["VA/PropertyType"]["true"] = {}
                    @relief_cashout_adjustment["VA/PropertyType"]["true"]["Non-Owner Occupied"] = {}
                    cc = cc + 7
                    new_val = sheet_data.cell(r,cc)
                    @relief_cashout_adjustment["VA/PropertyType"]["true"]["Non-Owner Occupied"] = new_val
                  end
                  if r == 1049 && cc == 8
                    @relief_cashout_adjustment["PropertyType"] = {}
                    @relief_cashout_adjustment["PropertyType"]["Manufactured Home"] = {}
                    cc = cc + 7
                    new_val = sheet_data.cell(r,cc)
                    @relief_cashout_adjustment["PropertyType"]["Manufactured Home"] = new_val
                  end
                  if r == 1050 && cc == 8
                    @relief_cashout_adjustment["PropertyType"]["2 Unit"] = {}
                    cc = cc + 7
                    new_val = sheet_data.cell(r,cc)
                    @relief_cashout_adjustment["PropertyType"]["2 Unit"] = new_val
                  end
                  if r == 1051 && cc == 8
                    @relief_cashout_adjustment["PropertyType"]["3-4 Unit"] = {}
                    cc = cc + 7
                    new_val = sheet_data.cell(r,cc)
                    @relief_cashout_adjustment["PropertyType"]["3-4 Unit"] = new_val
                  end
                  if r == 1052 && cc == 8
                    @relief_cashout_adjustment["VA/RefinanceOption/LTV"] = {}
                    @relief_cashout_adjustment["VA/RefinanceOption/LTV"]["true"] = {}
                    @relief_cashout_adjustment["VA/RefinanceOption/LTV"]["true"]["Cash Out"] = {}
                    @relief_cashout_adjustment["VA/RefinanceOption/LTV"]["true"]["Cash Out"]["95-Inf"] = {}
                    cc = cc + 7
                    new_val = sheet_data.cell(r,cc)
                    @relief_cashout_adjustment["VA/RefinanceOption/LTV"]["true"]["Cash Out"]["95-Inf"] = new_val
                  end
                  if r == 1053 && cc == 8
                    @relief_cashout_adjustment["FHA"] = {}
                    @relief_cashout_adjustment["FHA"]["true"] = {}
                    cc = cc + 7
                    new_val = sheet_data.cell(r,cc)
                    @relief_cashout_adjustment["FHA"]["true"] = new_val
                  end
                  if r == 1054 && cc == 8
                    @relief_cashout_adjustment["LockDay"] = {}
                    @relief_cashout_adjustment["LockDay"][90] = {}
                    cc = cc + 7
                    new_val = sheet_data.cell(r,cc)
                    @relief_cashout_adjustment["LockDay"][90] = new_val
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@relief_cashout_adjustment]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_cardinal_financial_wholesale10742_path(@sheet_obj)
  end

  def non_conforming_jumbo_core
    @xlsx.sheets.each do |sheet|
      if (sheet == "AK")
        sheet_data = @xlsx.sheet(sheet)
         @programs_ids = []
         @jumbo_hash = {}
         primary_key = ''
         ltv_key = ''
         # Non Conforming programs
        (1126..1145).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each_with_index do |max_column, index|
              index = index +1
              cc = 1 + max_column*10 + index# (2 / 13 / 24 / 35)
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  @sheet_name = @program.sub_sheet.name
                  # Program Property
                  p_name = @title + @sheet_name
                  @program.update_fields p_name
                  program_property @title
                  @program.adjustments.destroy_all
                end
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..8).each_with_index do |index, c_i|
                    rrr = rr + max_row +1
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      else
                        @block_hash[key][15*(c_i/2)] = value unless @block_hash[key].nil?
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # Non Conforming Adjustments
        (1154..1189).each do |r|
          row = sheet_data.row(r)
          @jumbo_data = sheet_data.row(1157)
          if row.compact.count >= 1
            (2..43).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Non-Conforming Jumbo CORE Loan Level Price Adjustments"
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Jumbo"] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Non-Conforming"] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Jumbo"]["0-1000000"] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Jumbo"]["1000000-Inf"] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Non-Conforming"]["0-1000000"] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Non-Conforming"]["1000000-Inf"] = {}
                  end
                  if value == "Other Specific Adjustments"
                    @jumbo_hash["PropertyType/LTV"] = {}
                    @jumbo_hash["RefinanceOption/LTV"] = {}
                  end
                  # Non-Conforming Jumbo CORE Loan Level Price Adjustments
                  if r >= 1158 && r <= 1164 && cc == 8
                    primary_key = get_value value
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Jumbo"]["0-1000000"][primary_key] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Non-Conforming"]["0-1000000"][primary_key] = {}
                  end
                  if r >= 1158 && r <= 1164 && cc >= 15 && cc <= 39
                    ltv_key = get_value @jumbo_data[cc-2]
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Jumbo"]["0-1000000"][primary_key][ltv_key] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Jumbo"]["0-1000000"][primary_key][ltv_key] = value
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Non-Conforming"]["0-1000000"][primary_key][ltv_key] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Non-Conforming"]["0-1000000"][primary_key][ltv_key] = value
                  end
                  if r >= 1167 && r <= 1173 && cc == 8
                    primary_key = get_value value
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Jumbo"]["1000000-Inf"][primary_key] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Non-Conforming"]["1000000-Inf"][primary_key] = {}
                  end
                  if r >= 1167 && r <= 1173 && cc >= 15 && cc <= 39
                    ltv_key = get_value @jumbo_data[cc-2]
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Jumbo"]["1000000-Inf"][primary_key][ltv_key] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Jumbo"]["1000000-Inf"][primary_key][ltv_key] = value
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Non-Conforming"]["1000000-Inf"][primary_key][ltv_key] = {}
                    @jumbo_hash["LoanSize/LoanAmount/FICO/LTV"]["Non-Conforming"]["1000000-Inf"][primary_key][ltv_key] = value
                  end
                  # Other Specific Adjustments
                  if r == 1176 && cc == 8
                    @jumbo_hash["PropertyType/LTV"]["Condo"] = {}
                  end
                  if r == 1176 && cc >= 15 && cc <= 39
                    ltv_key = get_value @jumbo_data[cc-2]
                    @jumbo_hash["PropertyType/LTV"]["Condo"][ltv_key] = {}
                    @jumbo_hash["PropertyType/LTV"]["Condo"][ltv_key] = value
                  end
                  if r == 1177 && cc == 8
                    @jumbo_hash["PropertyType/LTV"]["2nd Home"] = {}
                  end
                  if r == 1177 && cc >= 15 && cc <= 39
                    ltv_key = get_value @jumbo_data[cc-2]
                    @jumbo_hash["PropertyType/LTV"]["2nd Home"][ltv_key] = {}
                    @jumbo_hash["PropertyType/LTV"]["2nd Home"][ltv_key] = value
                  end
                  if r == 1178 && cc == 8
                    @jumbo_hash["PropertyType/LTV"]["Investment Property"] = {}
                  end
                  if r == 1178 && cc >= 15 && cc <= 39
                    ltv_key = get_value @jumbo_data[cc-2]
                    @jumbo_hash["PropertyType/LTV"]["Investment Property"][ltv_key] = {}
                    @jumbo_hash["PropertyType/LTV"]["Investment Property"][ltv_key] = value
                  end
                  if r == 1179 && cc == 8
                    @jumbo_hash["RefinanceOption/LTV"]["Cash Out"] = {}
                  end
                  if r == 1179 && cc >= 15 && cc <= 39
                    ltv_key = get_value @jumbo_data[cc-2]
                    @jumbo_hash["RefinanceOption/LTV"]["Cash Out"][ltv_key] = {}
                    @jumbo_hash["RefinanceOption/LTV"]["Cash Out"][ltv_key] = value
                  end
                  if r == 1180 && cc == 8
                    @jumbo_hash["PropertyType/LTV"]["2 Unit"] = {}
                  end
                  if r == 1180 && cc >= 15 && cc <= 39
                    ltv_key = get_value @jumbo_data[cc-2]
                    @jumbo_hash["PropertyType/LTV"]["2 Unit"][ltv_key] = {}
                    @jumbo_hash["PropertyType/LTV"]["2 Unit"][ltv_key] = value
                  end
                  if r == 1181 && cc == 8
                    @jumbo_hash["PropertyType/LTV"]["3-4 Unit"] = {}
                  end
                  if r == 1181 && cc >= 15 && cc <= 39
                    ltv_key = get_value @jumbo_data[cc-2]
                    @jumbo_hash["PropertyType/LTV"]["3-4 Unit"][ltv_key] = {}
                    @jumbo_hash["PropertyType/LTV"]["3-4 Unit"][ltv_key] = value
                  end
                  if r == 1182 && cc == 8
                    @jumbo_hash["MiscAdjuster/State/LTV"] = {}
                    @jumbo_hash["MiscAdjuster/State/LTV"]["Escrow Waiver"] = {}
                    @jumbo_hash["MiscAdjuster/State/LTV"]["Escrow Waiver"]["CA"] = {}
                  end
                  if r == 1182 && cc >= 15 && cc <= 39
                    ltv_key = get_value @jumbo_data[cc-2]
                    @jumbo_hash["MiscAdjuster/State/LTV"]["Escrow Waiver"]["CA"][ltv_key] = {}
                    @jumbo_hash["MiscAdjuster/State/LTV"]["Escrow Waiver"]["CA"][ltv_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@jumbo_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_cardinal_financial_wholesale10742_path(@sheet_obj)
  end

  def non_conforming_jumbo_x
    @xlsx.sheets.each do |sheet|
      if (sheet == "AK")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @non_jumbo_hash = {}
        ltv_key = ''
        primary_key = ''
        (1223..1260).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each_with_index do |max_column, index|
              index = index +1
              cc = 1 + max_column*10 + index# (2 / 13 / 24 / 35)
              @title = sheet_data.cell(r,cc)
              if @title.present?
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @programs_ids << @program.id
                @sheet_name = @program.sub_sheet.name
                # Program Property
                p_name = @title + @sheet_name
                @program.update_fields p_name
                program_property @title
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..8).each_with_index do |index, c_i|
                    rrr = rr + max_row +1
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      else
                        @block_hash[key][15*(c_i/2)] = value unless @block_hash[key].nil?
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
            end
          end
        end
        # Jumbo Non Conforming Adjustments
        (1271..1294).each do |r|
          row = sheet_data.row(r)
          @non_jumbo = sheet_data.row(1274)
          if row.compact.count >= 1
            (2..43).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Non-Conforming Jumbo X Loan Level Price Adjustments"
                    @non_jumbo_hash["LoanSize/FICO/LTV"] = {}
                    @non_jumbo_hash["LoanSize/FICO/LTV"]["Jumbo"] = {}
                    @non_jumbo_hash["LoanSize/FICO/LTV"]["Non-Conforming"] = {}
                  end
                  # Non-Conforming Jumbo X Loan Level Price Adjustments
                  if r >= 1275 && r <= 1281 && cc == 8
                    primary_key = get_value value
                    @non_jumbo_hash["LoanSize/FICO/LTV"]["Non-Conforming"][primary_key] = {}
                    @non_jumbo_hash["LoanSize/FICO/LTV"]["Jumbo"][primary_key] = {}
                  end
                  if r >= 1275 && r <= 1281 && cc >= 13 && cc <= 41
                    ltv_key = get_value @non_jumbo[cc-2]
                    @non_jumbo_hash["LoanSize/FICO/LTV"]["Non-Conforming"][primary_key][ltv_key] = {}
                    @non_jumbo_hash["LoanSize/FICO/LTV"]["Non-Conforming"][primary_key][ltv_key] = value
                    @non_jumbo_hash["LoanSize/FICO/LTV"]["Jumbo"][primary_key][ltv_key] = {}
                    @non_jumbo_hash["LoanSize/FICO/LTV"]["Jumbo"][primary_key][ltv_key] = value
                  end
                  if r == 1284 && cc == 6
                    @non_jumbo_hash["RefinanceOption/LTV"] = {}
                    @non_jumbo_hash["RefinanceOption/LTV"]["Cash Out"] = {}
                  end
                  if r == 1284 && cc >= 13 && cc <= 41
                    ltv_key = get_value @non_jumbo[cc-2]
                    @non_jumbo_hash["RefinanceOption/LTV"]["Cash Out"][ltv_key] = {}
                    @non_jumbo_hash["RefinanceOption/LTV"]["Cash Out"][ltv_key] = value
                  end
                  if r == 1285 && cc == 6
                    @non_jumbo_hash["LoanPurpose/LTV"] = {}
                    @non_jumbo_hash["LoanPurpose/LTV"]["Purchase"] = {}
                  end
                  if r == 1285 && cc >= 13 && cc <= 41
                    ltv_key = get_value @non_jumbo[cc-2]
                    @non_jumbo_hash["LoanPurpose/LTV"]["Purchase"][ltv_key] = {}
                    @non_jumbo_hash["LoanPurpose/LTV"]["Purchase"][ltv_key] = value
                  end
                  if r == 1287 && cc == 6
                    @non_jumbo_hash["PropertyType/LTV"] = {}
                    @non_jumbo_hash["PropertyType/LTV"]["Non-Owner Occupied"] = {}
                  end
                  if r == 1287 && cc >= 13 && cc <= 41
                    ltv_key = get_value @non_jumbo[cc-2]
                    @non_jumbo_hash["PropertyType/LTV"]["Non-Owner Occupied"][ltv_key] = {}
                    @non_jumbo_hash["PropertyType/LTV"]["Non-Owner Occupied"][ltv_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@non_jumbo_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_cardinal_financial_wholesale10742_path(@sheet_obj)
  end

  # def sheet1
  #   redirect_to ob_cardinal_financial_wholesale10742_index_path
  # end

  # def check_sheet_empty
  #   action =  params[:action]
  #   begin
  #     @sheet_data = @xlsx.sheet(action)
  #   rescue
  #     @sheet_data = @xlsx.sheet(action.upcase)
  #   rescue
  #     @sheet_data = @xlsx.sheet(action.downcase)
  #   rescue
  #     @sheet_data = @xlsx.sheet(action.capitalize)
  #   end
  #   if @sheet_data.first_row.blank?
  #     @msg = "Sheet is empty."
  #     redirect_to ob_cardinal_financial_wholesale10742_index_path
  #   end
  # end

  def programs
    @programs = @sheet_obj.programs
  end

  def single_program
  end

  def get_value value1
    if value1.present?
      if value1.include?("<=") || value1.include?("<") || value1.include?("≤")
        value1 = "0-"+value1.split("<=").last.tr('A-Za-z%$><=≤ ','')
      elsif value1.include?(">") || value1.include?("+")
        value1 = value1.split(">").last.tr('A-Za-z+ ','')+"-Inf"
        value1 = value1.tr('–', '-')
      elsif value1.include?("≥")
        value1 = value1.split("≥").last.tr('A-Za-z– ','')+"-Inf"
        value1 = value1.tr('–', '-')
      else
        value1 = value1.tr('–','-')
        value1 = value1.tr(' ','')
      end
    end
  end

  private

    def read_sheet
			file = File.join(Rails.root + "other_sheets", 'OB_Cardinal_Financial_Wholesale10742.xls')
      @xlsx = Roo::Spreadsheet.open(file)
    end

    def get_sheet
      @sheet_obj = SubSheet.find(params[:id])
    end

    def get_program
      @program = Program.find(params[:id])
    end

    def get_sheets_names
      return ["Fannie Mae Products","Freddie Mac Products","FHA VA USDA Products","Non Conforming Jumbo Core","Non Conforming Jumbo X"]
    end

    def program_property title
      @arm_advanced = ''
      if title.downcase.exclude?("arm")
        term = title.downcase.split("fixed").first.tr('A-Za-z/ ','')
        if term.length == 4 && term.last(2).to_i < term.first(2).to_i
          term = term.last(2) + term.first(2)
        else
          term
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
      # Arm_advanced
      if title.downcase.include?("arm")
        title.split.each do |arm|
          if arm.tr('1-9A-Za-z(|.% ','') == "//"
            @arm_advanced = arm.tr('A-Za-z()|.% , ','')[0,5]
            if @arm_advanced.include?('/')
              @arm_advanced = @arm_advanced.tr('/','-')
            else
              @arm_advanced
            end
          end
        end
      end
      @program.update(term: term, arm_basic: arm_basic, arm_advanced: @arm_advanced)
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
