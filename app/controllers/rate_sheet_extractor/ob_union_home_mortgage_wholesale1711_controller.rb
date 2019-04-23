class RateSheetExtractor::ObUnionHomeMortgageWholesale1711Controller < RateSheetExtractor::ApplicationController
  before_action :read_sheet, only: [:index, :conventional, :conven_highbalance_30, :gov_highbalance_30, :government_30_15_yr, :arm_programs, :fnma_du_refi_plus, :fhlmc_open_access, :fnma_home_ready, :fhlmc_home_possible, :simple_access, :jumbo_fixed]
  before_action :get_sheet, only: [:programs, :conventional, :conven_highbalance_30, :gov_highbalance_30, :government_30_15_yr, :arm_programs, :fnma_du_refi_plus, :fhlmc_open_access, :fnma_home_ready, :fhlmc_home_possible, :simple_access, :jumbo_fixed]
  before_action :get_program, only: [:single_program, :program_property]

  def index
    begin
      @xlsx.sheets.each do |sheet|
        if (sheet == "Intro")
          # headers = ["Phone", "General Contacts", "Mortgagee Clause (Wholesale)"]
          @name = "Union Home Mortgage Wholesale"
          @bank = Bank.find_or_create_by(name: @name)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
      end
    rescue
      # the required headers are not all present
    end
  end

  def conventional
    @xlsx.sheets.each do |sheet|
      if (sheet == "Conventional")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @mortgage_hash = {}
        @sub_hash = {}
        @property_hash = {}
        @multiunit_hash = {}
        primary_key = ''
        secondary_key = ''
        new_key = ''
        ltv_key = ''
        # programs
        (10..77).each do |r|
          row = sheet_data.row(r)
          row = row.reject { |e| e.to_s.empty? }
          if (row.compact.count <= 1)
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = max_column + 5
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @block_hash = {}
                  key = ''
                  (1..13).each do |max_row|
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
                          @block_hash[key][15*c_i] = value if key.present?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash, loan_category: sheet)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # adjustments
        (79..144).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(80)
          @cltv_data = sheet_data.row(90)
          @sub_data = sheet_data.row(104)
          if row.compact.count >= 1
            (0..13).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == 'Cash-Out Refinance'
                    primary_key = "RefinanceOption/FICO/LTV"
                    new_key = "Cash out"
                    @adjustment_hash[primary_key] = {}
                    @adjustment_hash[primary_key][new_key] = {}
                  end
                  if value == "Applicable for all mortgages with terms greater than 15 years  "
                    primary_key = "Term/FICO/LTV"
                    new_key = "15-Inf"
                    @mortgage_hash[primary_key] = {}
                    @mortgage_hash[primary_key][new_key] = {}
                  end
                  if value == "Subordinate Financing LTV/CLTV/FICO Adjustments"
                    primary_key = "FinancingType/LTV/CLTV/FICO"
                    new_key = "Subordinate Financing"
                    @sub_hash[primary_key] = {}
                    @sub_hash[primary_key][new_key] = {}
                  end
                  # Cash-Out Refinance
                  if r >= 81 && r <= 87 && cc == 3
                    secondary_key = get_value value
                    @adjustment_hash[primary_key][new_key][secondary_key] = {}
                  end
                  if r >= 81 && r <= 87 && cc >= 4 && cc <= 7
                    ltv_key = get_value @ltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.split("%").last
                    end
                    @adjustment_hash[primary_key][new_key][secondary_key][ltv_key] = {}
                    @adjustment_hash[primary_key][new_key][secondary_key][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Applicable for all mortgages with all terms
                  if r == 91 && cc == 3
                    @adjustment_hash["PropertyType/Term/LTV"] = {}
                    @adjustment_hash["PropertyType/Term/LTV"]["Investment Property"] = {}
                    @adjustment_hash["PropertyType/Term/LTV"]["Investment Property"]["0-Inf"] = {}
                  end
                  if r == 91 && cc >= 4 && cc <= 11
                    ltv_key = get_value @cltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @adjustment_hash["PropertyType/Term/LTV"]["Investment Property"]["0-Inf"][ltv_key] = {}
                    @adjustment_hash["PropertyType/Term/LTV"]["Investment Property"]["0-Inf"][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Applicable for all mortgages with terms greater than 15 years
                  if r >= 95 && r <= 101 && cc == 3
                    secondary_key = get_value value
                    @mortgage_hash[primary_key][new_key][secondary_key] = {}
                  end
                  if r >= 95 && r <= 101 && cc >= 4 && cc <= 11
                    ltv_key = get_value @cltv_data[cc-1]
                    if ltv_key.include?('%')
                      ltv_key = ltv_key.split("%").last
                    end
                    @mortgage_hash[primary_key][new_key][secondary_key][ltv_key] = {}
                    @mortgage_hash[primary_key][new_key][secondary_key][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Subordinate Financing LTV/CLTV/FICO Adjustments
                  if r >= 105 && r <= 109 && cc == 3
                    secondary_key = get_value value
                    if secondary_key.include?("%")
                      secondary_key = secondary_key.split("%").first+secondary_key.split("%").last
                    end
                    @sub_hash[primary_key][new_key][secondary_key] = {}
                  end
                  if r >= 105 && r <= 109 && cc == 4
                    ltv_key = get_value value
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.split("%").first+ltv_key.split("%").last
                    end
                    @sub_hash[primary_key][new_key][secondary_key][ltv_key] = {}
                  end
                  if r >= 105 && r <= 109 && cc >= 5 && cc <= 6
                    sub_data = get_value @sub_data[cc-1]
                    @sub_hash[primary_key][new_key][secondary_key][ltv_key][sub_data] = {}
                    @sub_hash[primary_key][new_key][secondary_key][ltv_key][sub_data] = (value.class == Float ? value*100 : value)
                  end
                  # Subordinate Finance
                  if r == 112 && cc == 3
                    @sub_hash["FinancingType"] = {}
                    @sub_hash["FinancingType"]["Subordinate Financing"] = {}
                    @sub_hash["FinancingType"]["Subordinate Financing"] = value
                  end
                  # Property Type
                  if r == 105 && cc == 10
                    @multiunit_hash["PropertyType/LTV"] = {}
                    @multiunit_hash["PropertyType/LTV"]["2nd Home"] = {}
                    @multiunit_hash["PropertyType/LTV"]["2nd Home"]["85-Inf"] = {}
                    @multiunit_hash["PropertyType/LTV"]["2nd Home"]["85-Inf"] = (value*100)
                  end
                  if r == 112 && cc == 6
                    primary_key = "PropertyType/Term/LTV"
                    secondary_key = "Condo"
                    ltv_key = "15-Inf"
                    new_key = "75-Inf"
                    @property_hash[primary_key] = {}
                    @property_hash[primary_key][secondary_key] = {}
                    @property_hash[primary_key][secondary_key][ltv_key] = {}
                    cc = cc + 3
                    new_value = sheet_data.cell(r,cc)
                    @property_hash[primary_key][secondary_key][ltv_key][new_key] =  (new_value*100).to_s
                  end
                  if r == 112 && cc == 11
                    @multiunit_hash["PropertyType/LTV"]["2 Unit"] = {}
                    @multiunit_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @multiunit_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = (new_value*100).to_s
                  end
                  if r == 113 && cc == 11
                    @multiunit_hash["PropertyType/LTV"]["3-4 Unit"] = {}
                    @multiunit_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @multiunit_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = (new_value*100).to_s
                  end
                  if r == 113 && cc == 6
                    primary_key = "PropertyType"
                    new_key = "Manufactured Home"
                    @property_hash[primary_key] = {}
                    if @property_hash[primary_key][new_key] = {}
                      cc = cc + 3
                      new_value = sheet_data.cell(r,cc)
                      @property_hash[primary_key][new_key] = (new_value*100).to_s
                    end
                  end
                  if r == 118 && cc == 3
                    @multiunit_hash["MiscAdjuster"] = {}
                    @multiunit_hash["MiscAdjuster"]["Escrows Waived"] = {}
                    @multiunit_hash["MiscAdjuster"]["Escrows Waived"] = value*100
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@mortgage_hash,@sub_hash,@property_hash,@multiunit_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_union_home_mortgage_wholesale1711_path(@sheet_obj)
  end

  def conven_highbalance_30
    @xlsx.sheets.each do |sheet|
      if (sheet == "Conven HighBalance 30")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        # programs
        (11..22).each do |r|
          row = sheet_data.row(r)
          row = row.reject { |e| e.to_s.empty? }
          if (row.compact.count <= 1)
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = max_column + 5
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @block_hash = {}
                  key = ''
                  (1..10).each do |max_row|
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
                          @block_hash[key][15*c_i] = value if key.present?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash, loan_category: sheet)
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
    redirect_to programs_ob_union_home_mortgage_wholesale1711_path(@sheet_obj)
  end

  def gov_highbalance_30
    @xlsx.sheets.each do |sheet|
      if (sheet == "GOV HighBalance 30")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        # programs
        (10..19).each do |r|
          row = sheet_data.row(r)
          row = row.reject { |e| e.to_s.empty? }
          if (row.compact.count <= 1)
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = max_column + 5
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @block_hash = {}
                  key = ''
                  (1..8).each do |max_row|
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
                          @block_hash[key][15*c_i] = value if key.present?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash, loan_category: sheet)
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
    redirect_to programs_ob_union_home_mortgage_wholesale1711_path(@sheet_obj)
  end

  def government_30_15_yr
    @xlsx.sheets.each do |sheet|
      if (sheet == "Government 30_15 Yr")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @property_hash = {}
        @fico_hash ={}
        primary_key = ''
        second_key = ''
        new_key = true
        # programs
        (11..42).each do |r|
          row = sheet_data.row(r)
          row = row.reject { |e| e.to_s.empty? }
          if (row.compact.count <= 1)
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = max_column + 5
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @block_hash = {}
                  key = ''
                  (1..16).each do |max_row|
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
                          @block_hash[key][15*c_i] = value if key.present?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash, loan_category: sheet)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # Adjustments
        (30..77).each do |r|
          row = sheet_data.row(r)
          if row.compact.count >= 1
            (0..13).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Government Price Adjustments"
                    @property_hash["PropertyType"]={}
                    @fico_hash["FICO"] = {}
                  end
                  if r >= 31 && r <= 33 && cc == 11
                    primary_key = "VA" if value == "VA"
                    primary_key = "USDA" if value == "USDA"
                    primary_key = "FHA" if value == "FHA Streamline"
                    @adjustment_hash[primary_key] = {}
                    @adjustment_hash[primary_key][new_key] = {}
                    if @adjustment_hash[primary_key][new_key] = {}
                      cc = cc + 1
                      new_value = sheet_data.cell(r,cc)
                      @adjustment_hash[primary_key][new_key] = new_value*100
                    end
                  end
                  if r == 34 && cc == 11
                    @adjustment_hash["VA/RefinanceOption"] = {}
                    @adjustment_hash["VA/RefinanceOption"]["true"] = {}
                    cc = cc + 1
                    new_value = sheet_data.cell(r,cc)
                    @adjustment_hash["VA/RefinanceOption"]["true"]["IRRRL"] = new_value*100
                  end
                  if r >= 35 && r <= 38 && cc == 11
                    if value.include?("-")
                      second_key = value.tr('A-Z>= ','')
                    else
                      second_key = get_value value
                    end
                    new_value = sheet_data.cell(r,cc+1)
                    @fico_hash["FICO"][second_key]=new_value*100
                  end
                  if r == 39 && cc == 13
                    @fico_hash["VA/FICO"] = {}
                    @fico_hash["VA/FICO"]["true"] = {}
                    @fico_hash["VA/FICO"]["true"]["600-619"] = {}
                    cc = cc + 1
                    new_value = sheet_data.cell(r,cc)
                    @fico_hash["VA/FICO"]["true"]["600-619"] = new_value*100
                  end
                  if r >= 41 && r <= 42 && cc == 11
                    new_value = sheet_data.cell(r,cc+1)
                    @property_hash["PropertyType"][value] = new_value*100
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@fico_hash, @property_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_union_home_mortgage_wholesale1711_path(@sheet_obj)
  end

  def arm_programs
    @xlsx.sheets.each do |sheet|
      if (sheet == "ARM Programs")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @mortgage_hash = {}
        @sub_hash = {}
        @property_hash = {}
        primary_key = ''
        secondary_key = ''
        ltv_key = ''
        # programs
        (11..55).each do |r|
          row = sheet_data.row(r)
          row = row.reject { |e| e.to_s.empty? }
          if (row.compact.count <= 1)
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = max_column + 5
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @block_hash = {}
                  key = ''
                  (1..13).each do |max_row|
                    @data = []
                    (0..3).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        else
                          @block_hash[key][15*(c_i+1)] = value if key.present?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash, loan_category: sheet)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # adjustments
        (58..123).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(59)
          @cltv_data = sheet_data.row(68)
          @sub_data = sheet_data.row(82)
          if row.compact.count >= 1
            (0..13).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == 'Cash-Out Refinance'
                    @adjustment_hash["RefinanceOption/FICO/LTV"] = {}
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                  end
                  if value == "Applicable for all mortgages with terms greater than 15 years  "
                    @mortgage_hash["Term/FICO/LTV"] = {}
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"] = {}
                  end
                  if value == "Subordinate Financing LTV/CLTV/FICO Adjustments"
                    @sub_hash["FinancingType/LTV/CLTV/FICO"] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"] = {}
                  end
                  # Cash-Out Refinance
                  if r >= 60 && r <= 65 && cc == 2
                    secondary_key = get_value value
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 60 && r <= 65 && cc >= 3 && cc <= 6
                    ltv_key = get_value @ltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][ltv_key] = {}
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Applicable for all mortgages with all terms
                  if r == 69 && cc == 2
                    @adjustment_hash["PropertyType/Term/LTV"] = {}
                    @adjustment_hash["PropertyType/Term/LTV"]["Investment Property"] = {}
                    @adjustment_hash["PropertyType/Term/LTV"]["Investment Property"]["0-Inf"] = {}
                  end
                  if r == 69 && cc >= 3 && cc <= 10
                    ltv_key = get_value @cltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @adjustment_hash["PropertyType/Term/LTV"]["Investment Property"]["0-Inf"][ltv_key] = {}
                    @adjustment_hash["PropertyType/Term/LTV"]["Investment Property"]["0-Inf"][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Applicable for all mortgages with terms greater than 15 years
                  if r >= 73 && r <= 79 && cc == 2
                    secondary_key = get_value value
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"][secondary_key] = {}
                  end
                  if r >= 73 && r <= 79 && cc >= 3 && cc <= 10
                    ltv_key = get_value @cltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = {}
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Subordinate Financing LTV/CLTV/FICO Adjustments
                  if r >= 83 && r <= 87 && cc == 5
                    secondary_key = get_value value
                    if secondary_key.include?("%")
                      secondary_key = secondary_key.tr('% ','')
                    else
                      secondary_key
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key] = {}
                  end
                  if r >= 83 && r <= 87 && cc == 6
                    ltv_key = get_value value
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key] = {}
                  end
                  if r >= 83 && r <= 87 && cc >= 7 && cc <= 8
                    sub_data = get_value @sub_data[cc-1]
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key][sub_data] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key][sub_data] = (value.class == Float ? value*100 : value)
                  end
                  # Subordinate Finance
                  if r == 90 && cc == 2
                    @sub_hash["FinancingType"] = {}
                    @sub_hash["FinancingType"]["Subordinate Financing"] = {}
                    @sub_hash["FinancingType"]["Subordinate Financing"] = value
                  end
                  # Property Type
                  if r == 90 && cc == 5
                    @property_hash["PropertyType/Term/LTV"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_value*100
                  end
                  if r == 90 && cc == 9
                    @property_hash["PropertyType/LTV"] = {}
                    @property_hash["PropertyType/LTV"]["2 Unit"] = {}
                    @property_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = {}
                    cc = cc + 1
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = new_value*100
                  end
                  if r == 91 && cc == 5
                    @property_hash["PropertyType"] = {}
                    @property_hash["PropertyType"]["Manufactured Home"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType"]["Manufactured Home"] = new_value
                  end
                  if r == 91 && cc == 9
                    @property_hash["PropertyType/LTV"]["3-4 Unit"] = {}
                    @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = {}
                    cc = cc + 1
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = new_value*100
                  end
                  if r == 97 && cc == 3
                    @property_hash["MiscAdjuster"] = {}
                    @property_hash["MiscAdjuster"]["Escrows Waived"] = {}
                    @property_hash["MiscAdjuster"]["Escrows Waived"] = value*100
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@mortgage_hash,@sub_hash,@property_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_union_home_mortgage_wholesale1711_path(@sheet_obj)
  end

  def fnma_du_refi_plus
    @xlsx.sheets.each do |sheet|
      if (sheet == "FNMA DU-Refi Plus")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @mortgage_hash = {}
        @sub_hash = {}
        @property_hash = {}
        primary_key = ''
        secondary_key = ''
        ltv_key = ''
        # programs
        (10..24).each do |r|
          row = sheet_data.row(r)
          row = row.reject { |e| e.to_s.empty? }
          if (row.compact.count <= 1)
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = max_column + 4
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @block_hash = {}
                  key = ''
                  (1..13).each do |max_row|
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
                          @block_hash[key][15*c_i] = value if key.present?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash, loan_category: sheet)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # adjustments
        (27..98).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(35)
          @cltv_data = sheet_data.row(45)
          @sub_data = sheet_data.row(59)
          if row.compact.count >= 1
            (0..13).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == 'Cash-Out Refinance'
                    @adjustment_hash["RefinanceOption/FICO/LTV"] = {}
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                  end
                  if value == "Applicable for all mortgages with terms greater than 15 years  "
                    @mortgage_hash["Term/FICO/LTV"] = {}
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"] = {}
                  end
                  if value == "Subordinate Financing LTV/CLTV/FICO Adjustments"
                    @sub_hash["FinancingType/LTV/CLTV/FICO"] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"] = {}
                  end
                  # Cash-Out Refinance
                  if r >= 36 && r <= 42 && cc == 2
                    secondary_key = get_value value
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 36 && r <= 42 && cc >= 3 && cc <= 6
                    ltv_key = get_value @ltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][ltv_key] = {}
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Applicable for all mortgages with all terms
                  if r == 46 && cc == 2
                    @adjustment_hash["PropertyType/Term/LTV"] = {}
                    @adjustment_hash["PropertyType/Term/LTV"]["Investment Property"] = {}
                    @adjustment_hash["PropertyType/Term/LTV"]["Investment Property"]["0-Inf"] = {}
                  end
                  if r == 46 && cc >= 3 && cc <= 10
                    ltv_key = get_value @cltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @adjustment_hash["PropertyType/Term/LTV"]["Investment Property"]["0-Inf"][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Applicable for all mortgages with terms greater than 15 years
                  if r >= 50 && r <= 56 && cc == 2
                    secondary_key = get_value value
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"][secondary_key] = {}
                  end
                  if r >= 50 && r <= 56 && cc >= 3 && cc <= 10
                    ltv_key = get_value @cltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = {}
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Subordinate Financing LTV/CLTV/FICO Adjustments
                  if r >= 60 && r <= 64 && cc == 2
                    secondary_key = get_value value
                    if secondary_key.include?("%")
                      secondary_key = secondary_key.tr('% ','')
                    else
                      secondary_key
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key] = {}
                  end
                  if r >= 60 && r <= 64 && cc == 3
                    ltv_key = get_value value
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key] = {}
                  end
                  if r >= 60 && r <= 64 && cc >= 4 && cc <= 5
                    sub_data = get_value @sub_data[cc-1]
                    if sub_data.include?("%")
                      sub_data = sub_data.tr('% ','')
                    else
                      sub_data
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key][sub_data] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key][sub_data] = (value.class == Float ? value*100 : value)
                  end
                  # Subordinate Finance
                  if r == 67 && cc == 2
                    @sub_hash["FinancingType"] = {}
                    @sub_hash["FinancingType"]["Subordinate Financing"] = {}
                    @sub_hash["FinancingType"]["Subordinate Financing"] = value*100
                  end
                  # Property Type
                  if r == 67 && cc == 5
                    @property_hash["PropertyType/Term/LTV"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                    cc = cc + 3
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_value*100
                  end
                  if r == 67 && cc == 10
                    @property_hash["PropertyType/LTV"] = {}
                    @property_hash["PropertyType/LTV"]["2 Unit"] = {}
                    @property_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = new_value*100
                  end
                  if r == 68 && cc == 5
                    @property_hash["PropertyType"] = {}
                    @property_hash["PropertyType"]["Manufactured Home"] = {}
                    cc = cc + 3
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType"]["Manufactured Home"] = new_value*100
                  end
                  if r == 68 && cc == 10
                    @property_hash["PropertyType/LTV"]["3-4 Unit"] = {}
                    @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = new_value*100
                  end
                  if r == 72 && cc == 3
                    @property_hash["MiscAdjuster"] = {}
                    @property_hash["MiscAdjuster"]["Escrows Waived"] = {}
                    @property_hash["MiscAdjuster"]["Escrows Waived"] = value*100
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@mortgage_hash,@sub_hash,@property_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_union_home_mortgage_wholesale1711_path(@sheet_obj)
  end

  def fhlmc_open_access
    @xlsx.sheets.each do |sheet|
      if (sheet == "FHLMC Open Access")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @mortgage_hash = {}
        @sub_hash = {}
        @property_hash = {}
        primary_key = ''
        secondary_key = ''
        ltv_key = ''
        # programs
        (11..25).each do |r|
          row = sheet_data.row(r)
          row = row.reject { |e| e.to_s.empty? }
          if (row.compact.count <= 1)
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = max_column + 5
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @block_hash = {}
                  key = ''
                  (1..13).each do |max_row|
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
                          @block_hash[key][15*c_i] = value if key.present?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash, loan_category: sheet)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # Adjustments
        (27..91).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(28)
          @cltv_data = sheet_data.row(39)
          @sub_data = sheet_data.row(51)
          if row.compact.count >= 1
            (0..13).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == 'Cash-Out Refinance'
                    @adjustment_hash["RefinanceOption/FICO/LTV"] = {}
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                    @adjustment_hash["LTV"] = {}
                  end
                  if value == "Applicable for all mortgages with terms greater than 15 years  "
                    @mortgage_hash["Term/FICO/LTV"] = {}
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"] = {}
                    @mortgage_hash["PropertyType/LTV"] = {}
                    @mortgage_hash["PropertyType/LTV"]["Investment Property"] = {}
                  end
                  if value == "Subordinate Financing LTV/CLTV/FICO Adjustments"
                    @sub_hash["FinancingType/LTV/CLTV/FICO"] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"] = {}
                  end
                  # Cash-Out Refinance
                  if r >= 29 && r <= 35 && cc == 2
                    secondary_key = get_value value
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 29 && r <= 35 && cc >= 3 && cc <= 6
                    ltv_key = get_value @ltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr("% ", "")
                    else
                      ltv_key
                    end
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][ltv_key] = {}
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  if r >= 35 && r <= 36 && cc == 9
                    ltv_key = value.tr('% ','')
                    @adjustment_hash["LTV"][ltv_key] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @adjustment_hash["LTV"][ltv_key] = new_value
                  end
                  # Applicable for all mortgages with terms greater than 15 years
                  if r >= 40 && r <= 47 && cc == 2
                    secondary_key = get_value value
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"][secondary_key] = {}
                  end
                  if r >= 40 && r <= 47 && cc >= 3 && cc <= 10
                    ltv_key = get_value @cltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr("% ", "")
                    else
                      ltv_key
                    end
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = {}
                    @mortgage_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  if r == 48 && cc >=3 && cc <= 10
                    ltv_key = get_value @cltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr("% ", "")
                    else
                      ltv_key
                    end
                    @mortgage_hash["PropertyType/LTV"]["Investment Property"][ltv_key] = {}
                    @mortgage_hash["PropertyType/LTV"]["Investment Property"][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Subordinate Financing LTV/CLTV/FICO Adjustments
                  if r >= 52 && r <= 58 && cc == 6
                    secondary_key = get_value value
                    if secondary_key.include?("%")
                      secondary_key = secondary_key.tr("% ", "")
                    else
                      secondary_key
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key] = {}
                  end
                  if r >= 52 && r <= 58 && cc == 7
                    ltv_key = get_value value
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr("% ", "")
                    else
                      ltv_key
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key] = {}
                  end
                  if r >= 52 && r <= 58 && cc >= 8 && cc <= 9
                    sub_data = get_value @sub_data[cc-1]
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key][sub_data] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key][sub_data] = (value.class == Float ? value*100 : value)
                  end
                  # Property Type
                  if r == 61 && cc == 5
                    @property_hash["PropertyType/Term/LTV"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                    cc = cc + 3
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = new_value*100
                  end
                  if r == 61 && cc == 10
                    @property_hash["PropertyType/LTV"] = {}
                    @property_hash["PropertyType/LTV"]["2 Unit"] = {}
                    @property_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = new_value*100
                  end
                  if r == 62 && cc == 10
                    @property_hash["PropertyType/LTV"]["3-4 Unit"] = {}
                    @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = new_value
                  end
                  if r == 65 && cc == 3
                    @property_hash["MiscAdjuster"] = {}
                    @property_hash["MiscAdjuster"]["Escrows Waived"] = {}
                    @property_hash["MiscAdjuster"]["Escrows Waived"] = value*100
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@mortgage_hash,@sub_hash,@property_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_union_home_mortgage_wholesale1711_path(@sheet_obj)
  end

  def fnma_home_ready
    @xlsx.sheets.each do |sheet|
      if (sheet == "FNMA Home Ready")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @sub_hash = {}
        @property_hash = {}
        primary_key = ''
        secondary_key = ''
        ltv_key = ''
        # programs
        (11..28).each do |r|
          row = sheet_data.row(r)
          row = row.reject { |e| e.to_s.empty? }
          if (row.compact.count <= 1)
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = max_column + 4
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @block_hash = {}
                  key = ''
                  (1..16).each do |max_row|
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
                          @block_hash[key][15*c_i] = value if key.present?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash, loan_category: sheet)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # Adjustment
        (35..90).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(36)
          @cltv_data = sheet_data.row(50)
          if row.compact.count >= 1
            (0..13).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Applicable for all mortgages with with all terms"
                    @adjustment_hash["PropertyType/LTV"] = {}
                    @adjustment_hash["PropertyType/LTV"]["Investment Property"] = {}
                  end
                  if value == "Applicable for all mortgages with terms greater than 15 years  "
                    @adjustment_hash["Term/FICO/LTV"] = {}
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"] = {}
                  end
                  if value == "Subordinate Financing LTV/CLTV/FICO Adjustments"
                    @sub_hash["FinancingType/LTV/CLTV/FICO"] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"] = {}
                  end
                  # Applicable for all mortgages with with all terms
                  if r == 37 && cc >= 3 && cc <= 10
                    ltv_key = get_value @ltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @adjustment_hash["PropertyType/LTV"]["Investment Property"][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Applicable for all mortgages with terms greater than 15 years
                  if r >= 41 && r <= 47 && cc == 2
                    secondary_key = get_value value
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"][secondary_key] = {}
                  end
                  if r >= 41 && r <= 47 && cc >= 3 && cc <= 10
                    ltv_key = get_value @ltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = {}
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Subordinate Financing LTV/CLTV/FICO Adjustments
                  if r >= 51 && r <= 55 && cc == 5
                    secondary_key = get_value value
                    if secondary_key.include?("%")
                      secondary_key = secondary_key.tr('% ','')
                    else
                      secondary_key
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key] = {}
                  end
                  if r >= 51 && r <= 55 && cc == 6
                    ltv_key = get_value value
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key] = {}
                  end
                  if r >= 51 && r <= 55 && cc >= 7 && cc <= 8
                    cltv_key = get_value @cltv_data[cc-1]
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key][cltv_key] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key][cltv_key] = (value.class == Float ? value*100 : value)
                  end
                   # Property Type
                   if r == 59 && cc == 2
                     @sub_hash["FinancingType"] = {}
                     @sub_hash["FinancingType"]["Subordinate Financing"] = {}
                     @sub_hash["FinancingType"]["Subordinate Financing"] = value*100
                   end
                   if r == 59 && cc == 5
                    @property_hash["PropertyType/Term/LTV"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                    cc = cc + 3
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_value*100
                  end
                  if r == 59 && cc == 10
                    @property_hash["PropertyType/LTV"] = {}
                    @property_hash["PropertyType/LTV"]["2 Unit"] = {}
                    @property_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = new_value*100
                  end
                  if r == 60 && cc == 5
                    @property_hash["PropertyType"] = {}
                    @property_hash["PropertyType"]["Manufactured Home"] = {}
                    cc = cc + 3
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType"]["Manufactured Home"] = new_value*100
                  end
                  if r == 60 && cc == 10
                    @property_hash["PropertyType/LTV"]["3-4 Unit"] = {}
                    @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = new_value*100
                  end
                  if r == 64 && cc == 3
                    @property_hash["MiscAdjuster"] = {}
                    @property_hash["MiscAdjuster"]["Escrows Waived"] = {}
                    @property_hash["MiscAdjuster"]["Escrows Waived"] = value*100
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@sub_hash,@property_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_union_home_mortgage_wholesale1711_path(@sheet_obj)
  end

  def fhlmc_home_possible
    @xlsx.sheets.each do |sheet|
      if (sheet == "FHLMC Home Possible")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @sub_hash = {}
        @property_hash = {}
        primary_key = ''
        secondary_key = ''
        ltv_key = ''
        # programs
        (10..27).each do |r|
          row = sheet_data.row(r)
          row = row.reject { |e| e.to_s.empty? }
          if (row.compact.count <= 1)
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = max_column + 4
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @block_hash = {}
                  key = ''
                  (1..16).each do |max_row|
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
                          @block_hash[key][15*c_i] = value if key.present?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash, loan_category: sheet)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # Adjustment
        (35..86).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(36)
          @cltv_data = sheet_data.row(46)
          if row.compact.count >= 1
            (0..13).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Applicable for all mortgages with terms greater than 15 years  "
                    @adjustment_hash["Term/FICO/LTV"] = {}
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"] = {}
                  end
                  if value == "Subordinate Financing LTV/CLTV/FICO Adjustments"
                    @sub_hash["FinancingType/LTV/CLTV/FICO"] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"] = {}
                  end
                  # Applicable for all mortgages with terms greater than 15 years
                  if r >= 37 && r <= 43 && cc == 2
                    secondary_key = get_value value
                    if secondary_key.include?("%")
                      secondary_key = secondary_key.tr('% ','')
                    else
                      secondary_key
                    end
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"][secondary_key] = {}
                  end
                  if r >= 37 && r <= 43 && cc >= 3 && cc <= 10
                    ltv_key = get_value @ltv_data[cc-1]
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = {}
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = (value.class == Float ? value*100 : value)
                  end
                  # Subordinate Financing LTV/CLTV/FICO Adjustments
                  if r >= 47 && r <= 51 && cc == 5
                    secondary_key = get_value value
                    if secondary_key.include?("%")
                      secondary_key = secondary_key.tr('% ','')
                    else
                      secondary_key
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key] = {}
                  end
                  if r >= 47 && r <= 51 && cc == 6
                    ltv_key = get_value value
                    if ltv_key.include?("%")
                      ltv_key = ltv_key.tr('% ','')
                    else
                      ltv_key
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key] = {}
                  end
                  if r >= 47 && r <= 51 && cc >= 7 && cc <= 8
                    cltv_key = get_value @cltv_data[cc-1]
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key][cltv_key] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][secondary_key][ltv_key][cltv_key] = (value.class == Float ? value*100 : value)
                  end
                   # Property Type
                   if r == 55 && cc == 5
                    @property_hash["PropertyType/Term/LTV"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                    cc = cc + 3
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = new_value*100
                  end
                  if r == 55 && cc == 10
                    @property_hash["PropertyType/LTV"] = {}
                    @property_hash["PropertyType/LTV"]["2 Unit"] = {}
                    @property_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/LTV"]["2 Unit"]["0-85"] = new_value*100
                  end
                  if r == 56 && cc == 5
                    @property_hash["PropertyType"] = {}
                    @property_hash["PropertyType"]["Manufactured Home"] = {}
                    cc =cc + 3
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType"]["Manufactured Home"] = new_value*100
                  end
                  if r == 56 && cc == 10
                    @property_hash["PropertyType/LTV"]["3-4 Unit"] = {}
                    @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = {}
                    cc = cc + 2
                    new_value = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/LTV"]["3-4 Unit"]["0-75"] = new_value*100
                  end
                  if r == 60 && cc == 3
                    @property_hash["MiscAdjuster"] = {}
                    @property_hash["MiscAdjuster"]["Escrows Waived"] = {}
                    @property_hash["MiscAdjuster"]["Escrows Waived"] = value*100
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@sub_hash,@property_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_union_home_mortgage_wholesale1711_path(@sheet_obj)
  end

  def simple_access
    @xlsx.sheets.each do |sheet|
      if (sheet == "Simple Access")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @llpa_hash = {}
        @other_hash = {}
        ltv_key = ''
        secondary_key = ''
        first_key = ''
        @sheet_name = sheet
        # programs
        (9..83).each do |r|
          row = sheet_data.row(r)
          row = row.reject { |e| e.to_s.empty? }
          if (row.compact.count <= 1)
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = max_column + 5
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @block_hash = {}
                  key = ''
                  (1..23).each do |max_row|
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
                          @block_hash[key][15*(c_i-1)+5] = value if key.present?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash, loan_category: sheet)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # Adjustment
        (90..122).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(93)
          @cltv_data = sheet_data.row(96)
          if row.compact.count >= 1
            (0..15).each do |cc|
              value = sheet_data.cell(r,cc)
              begin
                if value.present?
                  if value == "FICO/LTV LLPAs (Price Adjustments)"
                    secondary_key = "FICO/LTV"
                    @adjustment_hash[secondary_key] = {}
                  end
                  if value == "OTHER LLPAs (Price Adjustments)(1)(2)"
                    @other_hash["PropertyType/LTV"] = {}
                  end
                  if r >= 97 && r <= 105 && cc == 3
                    if value.include?("+")
                      ltv_key = value.split("+").first+"-Inf"
                    else
                      ltv_key = get_value value
                    end
                    @adjustment_hash[secondary_key][ltv_key] = {}
                  end
                  if r >= 97 && r <= 105 && cc >= 4 && cc <= 8
                    third_key = get_value @cltv_data[cc-3]
                    @adjustment_hash[secondary_key][ltv_key][third_key] = (value.class == Float ? value*100 : value)
                  end
                  if r >= 94 && r <= 95 && cc == 10
                    if value.include?("1")
                      ltv_key = value.split("(1)").first
                    else
                      ltv_key = value
                    end
                    @other_hash["PropertyType/LTV"][ltv_key] = {}
                  end
                  if r >= 94 && r <= 95 && cc >= 11 && cc <= 15
                    first_key = get_value @ltv_data[cc-3]
                    @other_hash["PropertyType/LTV"][ltv_key][first_key] = {}
                    @other_hash["PropertyType/LTV"][ltv_key][first_key] = (value.class == Float ? value*100 : value)
                  end
                  if r == 96 && cc == 10
                    ltv_key = "2-4 Unit"
                    @other_hash["PropertyType/LTV"][ltv_key] = {}
                  end
                  if r == 96 && cc >= 11 && cc <= 15
                    first_key = get_value @ltv_data[cc-3]
                    @other_hash["PropertyType/LTV"][ltv_key][first_key] = {}
                    @other_hash["PropertyType/LTV"][ltv_key][first_key] = (value.class == Float ? value*100 : value)
                  end
                  if r == 97 && cc == 10
                    ltv_key = "Non-Owner Occupied"
                    @other_hash["PropertyType/LTV"][ltv_key] = {}
                  end
                  if r == 97 && cc >= 11 && cc <= 15
                    first_key = get_value @ltv_data[cc-3]
                    @other_hash["PropertyType/LTV"][ltv_key][first_key] = {}
                    @other_hash["PropertyType/LTV"][ltv_key][first_key] = (value.class == Float ? value*100 : value)
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@other_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_union_home_mortgage_wholesale1711_path(@sheet_obj)
  end

  def jumbo_fixed
    @xlsx.sheets.each do |sheet|
      if (sheet == "Jumbo Fixed")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @other_hash = {}
        secondary_key = ''
        ltv_key = ''
        # programs
        (9..32).each do |r|
          row = sheet_data.row(r)
          row = row.reject { |e| e.to_s.empty? }
          if (row.compact.count <= 1)
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = max_column + 7
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @programs_ids << @program.id
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @block_hash = {}
                  key = ''
                  (1..10).each do |max_row|
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
                          @block_hash[key][15*(c_i-1)+5] = value if key.present?
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash, loan_category: sheet)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # Adjustment
        (36..63).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(38)
          if row.compact.count >= 1
            (0..15).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Other Adjustments"
                    @other_hash["State/LTV"] = {}
                    @other_hash["MiscAdjuster/LTV"] = {}
                  end
                  # Other Adjustments
                  if r >= 39 && r <= 42 && cc == 10
                    secondary_key = value
                    @other_hash["State/LTV"][secondary_key] = {}
                  end
                  if r >= 39 && r <= 42 && cc >= 11 && cc <= 15
                    ltv_key = get_value @ltv_data[cc-3]
                    @other_hash["State/LTV"][secondary_key][ltv_key] = {}
                    @other_hash["State/LTV"][secondary_key][ltv_key] = value
                  end
                  if r == 45 && cc == 10
                    @other_hash["PropertyType/LTV"] = {}
                    @other_hash["PropertyType/LTV"]["2 Unit"] = {}
                  end
                  if r == 45 && cc >= 11 && cc <= 15
                    ltv_key = get_value @ltv_data[cc-3]
                    @other_hash["PropertyType/LTV"]["2 Unit"][ltv_key] = {}
                    @other_hash["PropertyType/LTV"]["2 Unit"][ltv_key] = value
                  end
                  if r == 46 && cc == 10
                    @other_hash["PropertyType/LTV"]["Condo"] = {}
                  end
                  if r == 46 && cc >= 11 && cc <= 15
                    ltv_key = get_value @ltv_data[cc-3]
                    @other_hash["PropertyType/LTV"]["Condo"][ltv_key] = {}
                    @other_hash["PropertyType/LTV"]["Condo"][ltv_key] = value
                  end
                  if r == 49 && cc == 10
                    @other_hash["PropertyType/LTV"]["1 Unit"] = {}
                  end
                  if r == 49 && cc >= 11 && cc <= 15
                    ltv_key = get_value @ltv_data[cc-3]
                    @other_hash["PropertyType/LTV"]["1 Unit"][ltv_key] = {}
                    @other_hash["PropertyType/LTV"]["1 Unit"][ltv_key] = value
                  end
                  if r == 52 && cc == 10
                    @other_hash["LoanPurpose/LTV"] = {}
                    @other_hash["LoanPurpose/LTV"]["Purchase"] = {}
                  end
                  if r == 52 && cc >= 11 && cc <= 15
                    ltv_key = get_value @ltv_data[cc-3]
                    @other_hash["LoanPurpose/LTV"]["Purchase"][ltv_key] = {}
                    @other_hash["LoanPurpose/LTV"]["Purchase"][ltv_key] = value
                  end
                  if r == 53 && cc == 10
                    @other_hash["RefinanceOption/LTV"] = {}
                    @other_hash["RefinanceOption/LTV"]["Cash Out"] = {}
                  end
                  if r == 53 && cc >= 11 && cc <= 15
                    ltv_key = get_value @ltv_data[cc-3]
                    @other_hash["RefinanceOption/LTV"]["Cash Out"][ltv_key] = {}
                    @other_hash["RefinanceOption/LTV"]["Cash Out"][ltv_key] = value
                  end
                  if r >=56 && r <= 57 && cc == 10
                    secondary_key = value
                    @other_hash["MiscAdjuster/LTV"][secondary_key] = {}
                  end
                  if r >= 56 && r <= 57 && cc >= 11 && cc <= 15
                    ltv_key = get_value @ltv_data[cc-3]
                    @other_hash["MiscAdjuster/LTV"][secondary_key][ltv_key] = {}
                    @other_hash["MiscAdjuster/LTV"][secondary_key][ltv_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@other_hash]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_union_home_mortgage_wholesale1711_path(@sheet_obj)
  end

  def programs
    @programs = @sheet_obj.programs
  end

  def single_program
  end

  def get_program
    @program = Program.find(params[:id])
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

  private

  def get_sheet
    @sheet_obj = Sheet.find(params[:id])
  end

  def get_value value1
    if value1.present?
      if value1.include?("<=") || value1.include?("<")
        value1 = "0-"+value1.split("<=").last.tr('A-Za-z%$><= ','')
        value1 = value1.tr('–','-')
      elsif value1.include?(">")
        value1 = value1.split(">").last.tr('^0-9 ', '')+"-Inf"
        value1 = value1.tr('–','-')
      else
        value1
        value1 = value1.tr('–','-')
      end
    end
  end

  def program_property title
    if title.include?("YEAR") || title.downcase.include?("yr") || title.downcase.include?("y")
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
    elsif title.include?("10/1") || title.include?("10 / 1")
      arm_basic = 10
    end
    @program.update(term: term,arm_basic: arm_basic)
  end

  def make_adjust(block_hash, sheet)
    block_hash.each do |hash|
      hash.each do |key|
        data = {}
        data[key[0]] = key[1]
        Adjustment.create(data: data,loan_category: sheet)
      end
    end
  end

  def read_sheet
		file = File.join(Rails.root + "other_sheets", 'OB_Union_Home_Mortgage_Wholesale1711.xls')
    @xlsx = Roo::Spreadsheet.open(file)
  end
end
