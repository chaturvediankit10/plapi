class RateSheetExtractor::ObNewRezWholesale5806Controller < RateSheetExtractor::ApplicationController
  method_names = [:government, :programs, :freddie_fixed_rate, :conforming_fixed_rate, :home_possible, :conforming_arms, :lp_open_acces_arms, :lp_open_access_105, :lp_open_access, :du_refi_plus_arms, :du_refi_plus_fixed_rate_105, :du_refi_plus_fixed_rate, :dream_big, :high_balance_extra, :freddie_arms, :jumbo_series_d,:jumbo_series_f, :jumbo_series_h, :jumbo_series_i, :jumbo_series_jqm, :homeready, :homeready_hb]
  before_action :read_sheet, only: method_names + [:index]
  before_action :get_sheet, only: method_names
  # before_action :check_sheet_empty , only: method_names
  before_action :get_program, only: [:single_program, :program_property]

  require 'roo'
  require 'roo-xls'

  def index
    # HardWorker.perform_async(1)
    @banks = Bank.all
    @sheetlist =[]

      @xlsx.sheets.each do |sheet|
        @sheetlist.push(sheet)
        if (sheet == "Cover Zone 1")
          @sheet_name = sheet
          headers = ["Phone", "General Contacts", "Mortgagee Clause (Wholesale)"]
          @xlsx.sheet(sheet).each_with_index do |row, index|
            current_row = index+1
            if row.include?("Mortgagee Clause (Wholesale)")
              address_index = row.find_index("Mortgagee Clause (Wholesale)")
              @address_a = []
              (1..3).each do |n|
                @address_a << @xlsx.sheet(sheet).row(current_row+n)[address_index]
                if n == 3
                  @zip = @xlsx.sheet(sheet).row(current_row+n)[address_index].split.last
                  @state_code = @xlsx.sheet(sheet).row(current_row+n)[address_index].split[2]
                end
              end
            end
            if (row.include?("Phone") && row.include?("General Contacts"))
              phone_index = row.find_index(headers[0])
              general_contacts_index = row.find_index(headers[1])
              c_row = @xlsx.sheet(sheet).row(current_row+1)
              @name = c_row[general_contacts_index]
              @phone = c_row[phone_index]
            end
          end

          @bank = Bank.find_or_create_by(name: @name)
          @bank.update(phone: @phone, address1: @address_a.join, state_code: @state_code, zip: @zip)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
      end
  end

  def cover_zone_1
    redirect_to error_page_ob_new_rez_wholesale5806_path
  end

  def heloc
    redirect_to error_page_ob_new_rez_wholesale5806_path
  end

  def smartseries
    redirect_to error_page_ob_new_rez_wholesale5806_path
  end

  def jumbo_series_c
    redirect_to error_page_ob_new_rez_wholesale5806_path
  end

  def government
    @programs_ids = []
    @allAdjustments = {}
    @xlsx.sheets.each do |sheet|
      if (sheet == "Government")
        @sheet_name = sheet
        @program_ids = []
        @sheet = sheet
        @credit_hash = {}
        @loan_hash = {}
        @hb_hash = {}
        @bpc_loan_hash = {}
        @govt_hash = {}
        @second_hash = {}
        @spe_hash = {}
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        new_key = ''
        new_val = ''
        c_val = ''
        (1..95).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet"))
            # r == 7 / 35 / 55
            rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3 + max_column*6 # (3 / 9 / 15)
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @program_ids << @program.id
                  @program.adjustments.destroy_all
                  p_name = @title + " " + sheet
                  # rate arm
                  if @title.include?("10yr") || @title.include?("10 Yr")
                    term = 10
                  elsif @title.include?("15yr") || @title.include?("15 Yr")
                    term = 15
                  elsif @title.include?("20yr") || @title.include?("20 Yr")
                    term = 20
                  elsif @title.include?("25yr") || @title.include?("25 Yr")
                    term = 25
                  elsif @title.include?("30yr") || @title.include?("30 Yr")
                    term = 30
                  end

                  if p_name.include?("Fixed")
                    loan_type = "Fixed"
                  elsif p_name.include?("ARM")
                    loan_type = "ARM"
                    arm_benchmark = "LIBOR"
                    arm_margin = 0
                  elsif p_name.include?("Floating")
                    loan_type = "Floating"
                  elsif p_name.include?("Variable")
                    loan_type = "Variable"
                  else
                    loan_type = "Fixed"
                  end

                  # rate arm
                  if @title.include?("3-1 ARM") || @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM") || @title.include?("5/1 ARM") || @title.include?("7/1 ARM") || @title.include?("10/1 ARM")
                    arm_basic = @title.scan(/\d+/)[0].to_i
                  end

                  freddie_mac = false
                  if p_name.downcase.include?("freddie mac")
                    freddie_mac = true
                  end

                  conforming = false
                  if p_name.downcase.include?("conforming") 
                    conforming = true
                  end

                  fannie_mae = false
                  if p_name.downcase.include?("Fannie Mae")
                    fannie_mae = true
                  end
                  # Arm Advanced
                  if @title.downcase.include?("arm")
                    arm_advanced = @title.split("ARM").last.tr('A-Za-z ()', '')
                  end
                  # High Balance
                  if p_name.include?("High Balance")
                    loan_size = "High-Balance"
                  else
                    loan_size = "Conforming"
                  end
                  # Fha, va, usda
                  if p_name.downcase.include?("fha")
                    fha = true
                  end
                  if p_name.downcase.include?("va")
                    va = true
                  end
                  if p_name.downcase.include?("usda")
                    usda = true
                  end
                  # LoanPurpose
                  if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                    loan_purpose = "Refinance"
                  else
                    loan_purpose = "Purchase"
                  end
                  # lp and du
                  if p_name.downcase.include?('du ')
                    du = true
                  end
                  if p_name.downcase.include?('lp ')
                    lp = true
                  end
                  @program.update(term: term,loan_type: loan_type,conforming: conforming,freddie_mac: freddie_mac, fha: fha, va: va, usda: usda, fannie_mae: fannie_mae, loan_size: loan_size, loan_category: @sheet_name, arm_basic: arm_basic, arm_advanced: arm_advanced, loan_purpose: loan_purpose, du: du, lp: lp, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
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
                          @block_hash[key][15*c_i] = value
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
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Adjustments
        (110..136).each do |r|
          row = sheet_data.row(r)
          # @key_data = sheet_data.row(40)
          if (row.compact.count >= 1)
            (0..18).each do |max_column|
              cc = max_column
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Loan Level Price Adjustments"
                    @credit_hash["FICO"] = {}
                    @loan_hash["LoanAmount/LoanPurpose"] = {}
                    @bpc_loan_hash["VA/LoanAmount/LoanPurpose"] = {}
                    @bpc_loan_hash["VA/LoanAmount/LoanPurpose"]["true"] = {}
                    @govt_hash["FHA/RefinanceOption/Streamline/VA"]={}
                    @spe_hash["LoanType"] = {}
                    @second_hash["LoanType/LockDay"]={}
                  end
                  if r >= 112 && r <= 120 && cc == 5
                    new_key = get_value value
                    new_val = sheet_data.cell(r,cc+4)
                    @credit_hash["FICO"][new_key] = new_val
                  end
                  if r >= 123 && r <= 127 && cc == 5
                    if value.downcase.include?("conforming")
                      new_key = "300000-Inf"
                    else
                      new_key = get_value value
                    end
                    new_val = sheet_data.cell(r,cc+4)
                    c_val = sheet_data.cell(r,cc+5)
                    @loan_hash["LoanAmount/LoanPurpose"][new_key] = {}
                    @loan_hash["LoanAmount/LoanPurpose"][new_key]["Purchase"] = new_val
                    @loan_hash["LoanAmount/LoanPurpose"][new_key]["Refinance"] = c_val
                  end
                  if r == 128 && cc == 5
                    new_val = sheet_data.cell(r,cc+4)
                    @hb_hash["High-Balance"] = {}
                    @hb_hash["High-Balance"] = new_val
                  end
                  if r >= 129 && r <= 133 && cc == 5
                    new_key = get_value value
                    new_val = sheet_data.cell(r,cc+4)
                    c_val = sheet_data.cell(r,cc+5)
                    @bpc_loan_hash["VA/LoanAmount/LoanPurpose"]["true"][new_key] = {}
                    @bpc_loan_hash["VA/LoanAmount/LoanPurpose"]["true"][new_key]["Purchase"] = new_val
                    @bpc_loan_hash["VA/LoanAmount/LoanPurpose"]["true"][new_key]["Refinance"] = c_val
                  end
                  if r == 136 && cc == 6
                    @govt_hash["FHA/RefinanceOption/Streamline/VA"]["true"]={}
                    @govt_hash["FHA/RefinanceOption/Streamline/VA"]["true"]["IRRRL"]={}
                    @govt_hash["FHA/RefinanceOption/Streamline/VA"]["true"]["IRRRL"]["true"]={}
                    @govt_hash["FHA/RefinanceOption/Streamline/VA"]["true"]["IRRRL"]["true"]["true"]=value
                  end
                  if r >= 112 && r <= 125 && cc == 12
                    if value == "30, 45 & 60 Day Lock Purchase Special"
                      new_val = sheet_data.cell(r,cc+6)
                      @second_hash["LoanType/LockDay"]["Purchase"]={}
                      @second_hash["LoanType/LockDay"]["Purchase"][30]=new_val
                      @second_hash["LoanType/LockDay"]["Purchase"][45]=new_val
                      @second_hash["LoanType/LockDay"]["Purchase"][60]=new_val
                    end
                    if value == "FHA Refinances"
                      new_val = sheet_data.cell(r,cc+6)
                      @second_hash["FHA/LoanPurpose"]={}
                      @second_hash["FHA/LoanPurpose"]["true"]={}
                      @second_hash["FHA/LoanPurpose"]["true"]["Refinance"]=new_val
                    end
                    if value == "FHA/VA ARM <660"
                      new_val = sheet_data.cell(r,cc+6)
                      @second_hash["FHA/LoanType/VA/FICO"]={}
                      @second_hash["FHA/LoanType/VA/FICO"]["true"]={}
                      @second_hash["FHA/LoanType/VA/FICO"]["true"]["ARM"]={}
                      @second_hash["FHA/LoanType/VA/FICO"]["true"]["ARM"]["true"]={}
                      @second_hash["FHA/LoanType/VA/FICO"]["true"]["ARM"]["true"]["0-660"]=new_val
                    end
                    if value == "90 Day Lock (FRM & Purch Only)"
                      new_val = sheet_data.cell(r,cc+6)
                      @second_hash["RateType/LoanPurpose/LockDay"]={}
                      @second_hash["RateType/LoanPurpose/LockDay"]["Fixed"]={}
                      @second_hash["RateType/LoanPurpose/LockDay"]["Fixed"]["Purchase"]={}
                      @second_hash["RateType/LoanPurpose/LockDay"]["Fixed"]["Purchase"]["90"]=new_val
                    end
                    if value == "VA Cashout >95 LTV"
                      new_val = sheet_data.cell(r,cc+6)
                      @second_hash["RefinanceOption/VA/LTV"]={}
                      @second_hash["RefinanceOption/VA/LTV"]["Cash Out"]={}
                      @second_hash["RefinanceOption/VA/LTV"]["Cash Out"]["true"]={}
                      @second_hash["RefinanceOption/VA/LTV"]["Cash Out"]["true"]["LTV"]={}
                      @second_hash["RefinanceOption/VA/LTV"]["Cash Out"]["true"]["LTV"]["0-95"]=new_val
                    end
                    if value == "VA - Refinance Credit Score ≥ 620"
                      new_val = sheet_data.cell(r,cc+6)
                      @second_hash["LoanType/VA/FICO"]={}
                      @second_hash["LoanType/VA/FICO"]["Refinance"]={}
                      @second_hash["LoanType/VA/FICO"]["Refinance"]["true"]={}
                      @second_hash["LoanType/VA/FICO"]["Refinance"]["true"]["0-620"]=new_val
                    end
                    if value == "VA - All Loan Purposes - Credit Score < 620"
                      new_val = sheet_data.cell(r,cc+6)
                      @second_hash["VA/FICO"]={}
                      @second_hash["VA/FICO"]["true"]={}
                      @second_hash["VA/FICO"]["true"]["0-620"]=new_val
                    end
                    if value == "VA - IRRRL - Investment Property"
                      new_val = sheet_data.cell(r,cc+6)
                      @second_hash["VA/LoanType/RefinanceOption"]={}
                      @second_hash["VA/LoanType/RefinanceOption"]["true"]={}
                      @second_hash["VA/LoanType/RefinanceOption"]["true"]["Refinance"]={}
                      @second_hash["VA/LoanType/RefinanceOption"]["true"]["Refinance"]["IRRRL"]=new_val
                    end
                    if value == "Manufactured Home (FHA Only)"
                      new_val = sheet_data.cell(r,cc+6)
                      @second_hash["FHA/PropertyType"]={}
                      @second_hash["FHA/PropertyType"]["true"]={}
                      @second_hash["FHA/PropertyType"]["true"]["Manufactured Home"]=new_val
                    end
                    if value == "High Balance - 15 Yr Term\n(Adjusting 15 Yr Conforming Pricing - FHA/VA ONLY"
                      new_val = sheet_data.cell(r,cc+6)
                      @second_hash["FHA/VA/LoanSize/Term"]={}
                      @second_hash["FHA/VA/LoanSize/Term"]["true"]={}
                      @second_hash["FHA/VA/LoanSize/Term"]["true"]["true"]={}
                      @second_hash["FHA/VA/LoanSize/Term"]["true"]["true"]["High-Balance"]={}
                      @second_hash["FHA/VA/LoanSize/Term"]["true"]["true"]["High-Balance"]["15"]={}
                      @second_hash["FHA/VA/LoanSize/Term"]["true"]["true"]["High-Balance"]["15"]=new_val
                    end
                    if value == "Margin on all Government ARMs"
                      new_val = sheet_data.cell(r,cc+6)
                      new_val = get_value new_val
                      @second_hash["Margin"]={}
                      @second_hash["Margin"]=new_val
                    end
                  end
                  if r >= 132 && r <= 133 && cc == 17
                    new_val = sheet_data.cell(r,cc+1)
                    @spe_hash["LoanType"]["fixed"] = new_val if value == "Fixed"
                    @spe_hash["LoanType"]["ARM"] = new_val if value == "ARM"
                  end

                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@spe_hash,@hb_hash,@credit_hash,@bpc_loan_hash,@govt_hash,@loan_hash,@second_hash]
        create_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end

    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  def freddie_fixed_rate
    @program_ids = []
    @allAdjustments = {}
    @xlsx.sheets.each do |sheet|
      if (sheet == "Freddie Fixed Rate")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @sheet = sheet
        main_key = ''
        (1..118).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet")) || (row.include?("Freddie Mac 10yr Super Conforming"))
            rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3 + max_column*6 # (3 / 9 / 15)
              begin
                #title
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                #term
                term = nil
                if @title.include?("10yr") || @title.include?("10 Yr")
                  term = 10
                elsif @title.include?("15yr") || @title.include?("15 Yr")
                  term = 15
                elsif @title.include?("20yr") || @title.include?("20 Yr")
                  term = 20
                elsif @title.include?("25yr") || @title.include?("25 Yr")
                  term = 25
                elsif @title.include?("30yr") || @title.include?("30 Yr")
                  term = 30
                end

                # interest type
                if p_name.include?("Fixed")
                  loan_type = "Fixed"
                elsif p_name.include?("ARM")
                  loan_type = "ARM"
                  arm_benchmark = "LIBOR"
                  arm_margin = 0
                elsif p_name.include?("Floating")
                  loan_type = "Floating"
                elsif p_name.include?("Variable")
                  loan_type = "Variable"
                else
                  loan_type = "Fixed"
                end

                # conforming
                if p_name.downcase.include?("super conforming")
                  loan_size = "Super Conforming"
                  conforming = true
                else
                  loan_size = "Conforming"
                end

                # freddie_mac
                if p_name.include?("Freddie Mac")
                  freddie_mac = true
                end

                # fannie_mae
                if p_name.downcase.include?("fannie mae")
                  fannie_mae = true
                end

                # loan_purpose
                if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                  loan_purpose = "Refinance"
                else
                  loan_purpose = "Purchase"
                end

                # lp and du
                if p_name.downcase.include?('du ')
                  du = true
                end
                if p_name.downcase.include?('lp ')
                  lp = true
                end

                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @program_ids << @program.id
                @program.update(term: term,loan_type: loan_type,conforming: conforming,freddie_mac: freddie_mac, loan_category: @sheet_name, fannie_mae: fannie_mae,loan_size: loan_size, loan_purpose: loan_purpose, du: du, lp: lp,arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''

                (0..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    else
                      # first_row[c_i]
                      @block_hash[key][15*c_i] = value
                    end
                    @data << value
                  end

                  if @data.compact.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil?
                  @block_hash.values.first.shift
                end
                @block_hash.delete(nil)
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # adjustments
        previous_title = nil
        @another_title = nil
        modified_keys  = get_table_keys
        data = get_table_keys
        (123..169).each do |r|
          row    = sheet_data.row(r)
          # r == 52 / 68 / 81 / 84 / 89 / 94
          rr = r #+ 1 # (r == 53) / (r == 69) / (r == 82) / (r == 90) / (r == 95)
          max_column_section = row.compact.count - 1
          (0..max_column_section).each do |max_column|
            cc = 3 + max_column * 9 # (2 / 11)
            @title = sheet_data.cell(r,cc)
            @block_hash = {}
            begin
              if(@title.eql?("All Fixed Conforming\n(does not apply to terms <=15yrs)"))
                @title = "LoanSize/LoanType/Term/FICO/LTV"
                @block_hash[@title] = {}
                @block_hash[@title]["Conforming"] = {}
                @block_hash[@title]["Conforming"]["Fixed"] = {}
                @block_hash[@title]["Conforming"]["Fixed"]["0-15"] = {}
                @block_hash["PropertyType"] = {} unless @block_hash.has_key?("PropertyType")
                @block_hash["MiscAdjuster"] = {} unless @block_hash.has_key?("MiscAdjuster")
                @block_hash["LockDay"] = {} unless @block_hash.has_key?("LockDay")

                key = ''
                another_key = ''
                keyOfHash   = ''
                # for Misc Adjusters
                first_key   = ''
                second_key  = ''
                third_key   = ''
                final_key   = ''
                f1_key      = ''
                f2_key      = ''
                loan_amount = ''

                (0..50).each do |max_row|
                  @data = []
                  (3..19).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = index
                    value = sheet_data.cell(rrr,ccc)

                    begin
                      # implementation of first key
                      if rrr.eql?(132)
                        # for Cash-Out
                        @title = sheet_data.cell(rrr,cc)
                        unless @block_hash.has_key?(@title)
                          @block_hash[@title] = {}
                          @block_hash[@title]["Cash Out"] = {}
                        end
                      elsif rrr.eql?(138) && index == 3
                        # for Lender Paid MI Adjustments
                        previous_title = @title = sheet_data.cell(rrr,ccc) unless previous_title == @title
                        unless @block_hash.has_key?(@title)
                          @block_hash[@title] = {}
                          first_key  = "LPMI/RefinanceOption/LTV"
                          second_key = "LPMI/PropertyType/LTV"
                          final_key  = "LPMI/Term/FICO/LTV"
                          @block_hash[@title][first_key] = {}
                          @block_hash[@title][first_key]["true"] = {}
                          @block_hash[@title][second_key] = {}
                          @block_hash[@title][second_key]["true"] = {}
                          @block_hash[@title][final_key] = {}
                          @block_hash[@title][final_key]["true"] = {}
                        end
                      elsif rrr.eql?(155) && index == 3
                        # for Number Of Units
                        @title = sheet_data.cell(rrr,ccc)
                        unless @block_hash.has_key?(@title)
                          @block_hash[@title] = {}
                        end
                      elsif rrr.eql?(156) && index == 13
                        # for Loan Size Adjustments
                        @another_title = sheet_data.cell(rrr,index)
                        unless @block_hash.has_key?(@another_title)
                          @block_hash[@another_title] = {}
                        end
                      elsif rrr.eql?(158) && index == 3
                        # for Subordinate Financing
                        @title = sheet_data.cell(rrr,ccc)
                        # @title = "FinancingType/LTV/CLTV/FICO"
                        unless @block_hash.has_key?(@title)
                          @block_hash[@title] = {}
                          @block_hash[@title]["Subordinate Financing"] = {}
                        end
                      elsif rrr.eql?(163) && index == 3
                        # for Misc Adjusters
                        @title = sheet_data.cell(rrr,ccc)
                        @block_hash[@title] = {} unless @block_hash.has_key?(@title)
                      elsif rrr.eql?(164) && index.eql?(13)
                        #for Super Conforming Adjustments
                        @another_title = sheet_data.cell(rrr,ccc)
                        @block_hash[@another_title] = {} unless @block_hash.has_key?(@another_title)
                      elsif rrr.eql?(167) && index.eql?(3)
                        #for Non Owner Occupied
                        @another_title = sheet_data.cell(rrr,ccc)
                        @block_hash[@another_title] = {} unless @block_hash.has_key?(@another_title)
                        @block_hash[@another_title]["Non Owner Occupied"] = {}
                      end

                      #implementation of second key inside first key
                      if rrr > 122 && rrr < 131 && index == 7 && value
                        key = get_value(value)
                        @block_hash[@title]["Conforming"]["Fixed"]["0-15"][key] = {} unless @block_hash[@title]["Conforming"]["Fixed"]["0-15"].has_key?(key)
                      elsif rrr > 131 && rrr < 136 && index == 7 && value
                        # for 1st and 2nd table
                        key = get_value(value)
                        @block_hash[@title]["Cash Out"][key] = {} unless @block_hash[@title]["Cash Out"].has_key?(key)
                      elsif (rrr > 137) && (rrr < 154)
                        # for Lender Paid MI Adjustments
                        if index == 5 && value
                          if ["Rate & Term Refi", "Cash Out"].include?(value)
                            f1_key = "Rate & Term"
                            @block_hash[@title][first_key]["true"][f1_key] = {}
                          elsif ["Manufactured Home", "2nd Home", "3-4 Unit", "Non Owner Occupied"].include?(value)
                            f2_key = value
                            @block_hash[@title][second_key]["true"][f2_key] = {}
                          else
                            @block_hash[@title][final_key]["true"]["0 - 20"] = {} if value.eql?("≤ 20 Yr Term")
                            @block_hash[@title][final_key]["true"]["20 - Inf"] = {} if value.eql?("> 20 Yr Term")
                            key = "0 - 20" if value.eql?("≤ 20 Yr Term")
                            key = "20 - Inf" if value.eql?("> 20 Yr Term")
                          end
                        elsif index == 6 && rrr < 154 && value
                          another_key = value.eql?("≤ 85") ? set_range(value) : value
                          @block_hash[@title][final_key]["true"][key][another_key] = {} if another_key
                        end
                      end

                      if [156,157].include?(rrr) && ccc == 6
                        # for Number Of Units
                        key = sheet_data.cell(rrr,ccc)
                        @block_hash[@title][key] = {}
                      end

                      if (159..162).to_a.include?(rrr) && ccc < 12
                        # for Subordinate Financing
                        if index.eql?(6)
                          key = sheet_data.cell(rrr,ccc)
                          key = get_value(key)
                          @block_hash[@title]["Subordinate Financing"][key] = {} unless @block_hash[@title].has_key?(key)
                        elsif index.eql?(7)
                          keyOfHash = sheet_data.cell(rrr,ccc)
                          keyOfHash = get_value(keyOfHash)
                          @block_hash[@title]["Subordinate Financing"][key][keyOfHash] = {}
                        end
                      end

                      if (rrr >= 156 && rrr <= 163) && index.eql?(15)
                        # for Loan Size Adjustments
                        loan_amount = get_value(sheet_data.cell(rrr, ccc))
                        @block_hash[@another_title][loan_amount] = {}
                      end

                      if (163..166).to_a.include?(rrr) && ccc < 10
                        # for Misc Adjusters
                        if index.eql?(6)
                          key = sheet_data.cell(rrr,ccc)
                          if key && key.eql?("Condo > 75 LTV (>15yr Term)")
                            first_key = key.split(" >")[0]
                            @block_hash[@title][first_key] = {}
                            second_key = sheet_data.cell(rrr,ccc).split(" ")[2] + ".01"
                            @block_hash[@title][first_key][second_key] = {}
                            third_key = sheet_data.cell(rrr,ccc).split(" ")[4].split("(>")[1].split("yr")[0] + ".01"
                          elsif key && key.eql?(">90 LTV")
                            first_key  = key.split(" ")[1]
                            @block_hash[@title][first_key] = {}
                            second_key = key.split(">")[1].split(" ").first
                          end
                        end
                      end

                      if [167,168,169].include?(rrr) && [7].include?(ccc)
                        #for Non Owner Occupied
                        hash_key = sheet_data.cell(rrr,ccc)
                        hash_key = hash_key.eql?("> 80") ? set_range(hash_key) : get_value(hash_key)
                        key = hash_key
                        @block_hash[@another_title]["Non Owner Occupied"][hash_key] = {} if hash_key.present?
                      end

                      if [164,165].include?(rrr) && @another_title
                        # for Super Conforming Adjustments
                        if index.eql?(17)
                          another_key = sheet_data.cell(rrr,ccc)
                          @block_hash[@another_title]["Purchase"] = {} unless @block_hash[@another_title].has_key?("Purchase")
                          @block_hash[@another_title]["Refinance"] = {} unless @block_hash[@another_title].has_key?("Refinance")
                        end
                      end

                      # implementation of third key inside second key with value
                      if rrr > 122 && rrr < 131 && index > 7 && value
                        # for 1st table
                        diff_of_row = rrr - 122
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = hash_key.eql?("≥ 760") ? set_range(hash_key) : get_value(hash_key)
                        if hash_key.present?
                          @block_hash[@title]["Conforming"]["Fixed"]["0-15"][key][hash_key] = value unless @block_hash[@title]["Conforming"]["Fixed"]["0-15"][key].has_key?(hash_key)
                        end
                      end

                      if rrr > 131 && rrr < 136 && index > 7 && value
                        # for 2nd table
                        diff_of_row = rrr - 122
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = hash_key.eql?("≥ 760") ? set_range(hash_key) : get_value(hash_key)
                        if hash_key.present?
                          @block_hash[@title]["Cash Out"][key][hash_key] = value unless @block_hash[@title]["Cash Out"][key].has_key?(hash_key)
                        end
                      end

                      if rrr > 137 && rrr <= 153 && index >= 7 && value
                        # for Lender Paid MI Adjustments
                        diff_of_row = rrr - 137
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = set_range(hash_key).nil? ? get_value(hash_key) : set_range(hash_key)
                        if (138..143).to_a.include?(rrr)
                          if [138, 143].include?(rrr)
                            @block_hash[@title][first_key]["true"][f1_key][hash_key] = value
                          elsif [139, 140, 141, 142].include?(rrr)
                            @block_hash[@title][second_key]["true"][f2_key][hash_key] = value
                          end
                        else
                          if rrr > 144
                            @block_hash[@title][final_key]["true"][key][another_key][hash_key] = value
                          end
                        end
                      end

                      if [156,157].include?(rrr) && [9,10,11].include?(ccc)
                        # for Number Of Units
                        diff_of_row = rrr - 155
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = (hash_key.eql?("≤ 80") || hash_key.eql?("> 85")) ? set_range(hash_key) : get_value(hash_key)
                        @block_hash[@title][key][hash_key] = value if hash_key.present?
                      end

                      if (159..162).to_a.include?(rrr) && ccc > 9 && ccc < 12 && value
                        # for Subordinate Financing
                        diff_of_row = rrr - 158
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = hash_key.eql?("≥ 720") ? set_range(hash_key) : get_value(hash_key)
                        @block_hash[@title]["Subordinate Financing"][key][keyOfHash][hash_key] = value if hash_key.present?
                      end

                      if (156..163).to_a.include?(rrr) && ccc > 15 && value
                        #for Loan Size Adjustments
                        diff_of_row  = rrr - 155
                        loan_purpose = sheet_data.cell(rrr-diff_of_row,ccc)
                        @block_hash[@another_title][loan_amount][loan_purpose] = value
                      end

                      if (163..166).to_a.include?(rrr) && ccc == 11
                        #for Misc Adjusters
                        if rrr.eql?(163)
                          @block_hash[@title][first_key][second_key][third_key] = value
                        else
                          first_key = sheet_data.cell(rrr,ccc - 5)
                          @block_hash["PropertyType"]["Manufactured Home"] = value if ["Manufactured Home (High Bal - Not Permitted)"].include?(first_key)
                          @block_hash["MiscAdjuster"][first_key] = value if ["CA Escrow Waiver (Full or Taxes Only)", "CA Escrow Waiver (Insurance Only)"].include?(first_key)
                        end
                      end

                      if [167,168,169].include?(rrr) && [11].include?(ccc)
                        #for Non Owner Occupied
                        @block_hash[@another_title]["Non Owner Occupied"][key] = value if key && value
                      end

                      if [164,165].to_a.include?(rrr)
                        # for Super Conforming Adjustments
                        if index.eql?(19)
                          has_key = sheet_data.cell(rrr,ccc)
                          if rrr.eql?(164)
                            @block_hash[@another_title]["Purchase"]["Rate and Term"] = value
                            @block_hash[@another_title]["Refinance"]["Rate and Term"] = value
                          else
                            @block_hash[@another_title]["Refinance"]["Cash Out"] = value
                          end
                        end
                      end

                      if [172,173].to_a.include?(rrr) && ccc.eql?(17)
                        if rrr.eql?(172)
                          @block_hash["LockDay"]["30"] = value
                          @block_hash["LockDay"]["45"] = value
                          @block_hash["LockDay"]["60"] = value
                        else
                          @block_hash["LockDay"]["90"] = value
                        end
                      end
                    rescue Exception => e
                      error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc,loan_category: @sheet_name, error_detail: e.message)
                      error_log.save
                    end
                  end

                  @allAdjustments[@title] = @block_hash[@title]
                  if @another_title
                    @allAdjustments[@another_title] = @block_hash[@another_title]
                    @allAdjustments["PropertyType"] = @block_hash["PropertyType"]
                    @allAdjustments["MiscAdjuster"] = @block_hash["MiscAdjuster"]
                    @allAdjustments["LockDay"] = @block_hash["LockDay"]
                  end
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
              error_log.save
            end
          end
        end
      end
    end

    # rename first level keys
    @allAdjustments.keys.each do |key|
      data = get_table_keys
      if data[key]
        @allAdjustments[data[key]] = @allAdjustments.delete(key)
      end
    end

    # create adjustment for each program
    make_adjust(@allAdjustments, @sheet)
    create_program_association_with_adjustment(@sheet)
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  def conforming_fixed_rate
    program_ids = []
    @allAdjustments = {}
    @xlsx.sheets.each do |sheet|
      if (sheet == "Conforming Fixed Rate")
        @sheet_name = sheet
        @sheet = sheet
        sheet_data = @xlsx.sheet(sheet)
        (1..118).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet")) || (row.include?("Fannie Mae 10yr High Balance"))
            # r == 7 / 35 / 55
            rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3 + max_column*6 # (3 / 9 / 15)
              begin
                #title
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                #term
                term = nil
                if @title.include?("10yr") || @title.include?("10 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("15yr") || @title.include?("15 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("20yr") || @title.include?("20 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("25yr") || @title.include?("25 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("30yr") || @title.include?("30 Yr")
                  term = @title.scan(/\d+/)[0]
                end

                # interest type
                if p_name.include?("Fixed")
                  loan_type = "Fixed"
                elsif p_name.include?("ARM")
                  loan_type = "ARM"
                  arm_benchmark = "LIBOR"
                  arm_margin = 0
                elsif p_name.include?("Floating")
                  loan_type = "Floating"
                elsif p_name.include?("Variable")
                  loan_type = "Variable"
                else
                  loan_type = "Fixed"
                end

                # conforming
                if p_name.downcase.include?("conforming")
                  conforming = true
                end

                if p_name.downcase.include?("freddie mac")
                  freddie_mac = true
                end

                # fannie_mae
                fannie_mae = false
                if p_name.downcase.include?("fannie mae") 
                  fannie_mae = true
                end

                # High Balance
                if p_name.include?("High Balance")
                  loan_size = "High-Balance"
                else
                  loan_size = "Conforming"
                end

                # loan_purpose
                if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                  loan_purpose = "Refinance"
                else
                  loan_purpose = "Purchase"
                end

                # lp and du
                if p_name.downcase.include?('du ')
                  du = true
                end
                if p_name.downcase.include?('lp ')
                  lp = true
                end

                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_ids << @program.id

                @program.update(term: term,loan_type: loan_type,conforming: conforming,freddie_mac: freddie_mac, fannie_mae: fannie_mae,loan_size: loan_size, loan_category: @sheet_name, loan_purpose: loan_purpose, du: du, lp: lp, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (0..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    else
                      @block_hash[key][15*c_i] = value
                    end
                    @data << value
                  end

                  if @data.compact.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil?
                  @block_hash.values.first.shift
                end
                @block_hash.delete(nil)
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # adjustments
        previous_title = nil
        @another_title = nil
        modified_keys  = get_table_keys
        data = get_table_keys
        (123..171).each do |r|
          row = sheet_data.row(r)
          # r == 52 / 68 / 81 / 84 / 89 / 94
          rr = r #+ 1 # (r == 53) / (r == 69) / (r == 82) / (r == 90) / (r == 95)
          max_column_section = 0#row.compact.count - 1
          (0..max_column_section).each do |max_column|
            cc = 3 + max_column * 9 # (2 / 11)
            @title = sheet_data.cell(r,cc)
            @block_hash = {}
            begin
              if(@title.eql?("All Fixed Conforming\n(does not apply to terms ≤ 15yrs)"))
                @title = "LoanSize/LoanType/Term/FICO/LTV"
                @block_hash[@title] = {}
                @block_hash[@title]["Conforming"] = {}
                @block_hash[@title]["Conforming"]["Fixed"] = {}
                @block_hash[@title]["Conforming"]["Fixed"]["0-15"] = {}
                @block_hash["PropertyType"] = {} unless @block_hash.has_key?("PropertyType")
                @block_hash["MiscAdjuster"] = {} unless @block_hash.has_key?("MiscAdjuster")
                @block_hash["LockDay"] = {} unless @block_hash.has_key?("LockDay")
                #  for high balance key
                @block_hash["LoanSize/LoanPurpose/RefinanceOption"] = {} unless @block_hash.has_key?("LoanSize/LoanPurpose/RefinanceOption")
                @block_hash["LoanSize/LoanPurpose/RefinanceOption"]["High-Balance"] = {} unless @block_hash["LoanSize/LoanPurpose/RefinanceOption"].has_key?("High Balance")
                @block_hash["LoanSize/RefinanceOption"] = {} unless @block_hash.has_key?("LoanSize/RefinanceOption")
                @block_hash["LoanSize/RefinanceOption"]["High-Balance"] = {} unless @block_hash["LoanSize/RefinanceOption"].has_key?("High Balance")

                key = ''
                another_key = ''
                keyOfHash   = ''
                # for Misc Adjusters
                first_key   = ''
                second_key  = ''
                third_key   = ''
                final_key   = ''
                f1_key      = ''
                f2_key      = ''
                loan_amount = ''
                (0..48).each do |max_row|
                  @data = []
                  (3..19).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = index

                    begin
                      value = sheet_data.cell(rrr,ccc)
                      # implementation of first key
                      if rrr.eql?(133)
                        # for Cash-Out
                        @title = sheet_data.cell(rrr,cc)
                        unless @block_hash.has_key?(@title)
                          @block_hash[@title] = {}
                          @block_hash[@title]["Cash Out"] = {}
                        end
                      elsif rrr.eql?(138) && index == 3
                        # for Lender Paid MI Adjustments
                        previous_title = @title = sheet_data.cell(rrr,ccc) unless previous_title == @title
                        unless @block_hash.has_key?(@title)
                          @block_hash[@title] = {}
                          first_key  = "LPMI/RefinanceOption/LTV"
                          second_key = "LPMI/PropertyType/LTV"
                          final_key  = "LPMI/Term/FICO/LTV"
                          @block_hash[@title][first_key] = {}
                          @block_hash[@title][first_key]["true"] = {}
                          @block_hash[@title][second_key] = {}
                          @block_hash[@title][second_key]["true"] = {}
                          @block_hash[@title][final_key] = {}
                          @block_hash[@title][final_key]["true"] = {}
                        end
                      elsif rrr.eql?(156) && index == 3
                        # for Subordinate Financing
                        @title = sheet_data.cell(rrr,ccc)
                        unless @block_hash.has_key?(@title)
                          @block_hash[@title] = {}
                          @block_hash[@title]["Subordinate Financing"] = {}
                        end
                      elsif rrr.eql?(156) && index == 13
                        # for Loan Size Adjustments
                        @another_title = sheet_data.cell(rrr,index)
                        unless @block_hash.has_key?(@another_title)
                          @block_hash[@another_title] = {}
                        end
                      elsif rrr.eql?(162) && index == 3
                        # for Misc Adjusters
                        @title = sheet_data.cell(rrr,ccc)
                        @block_hash[@title] = {} unless @block_hash.has_key?(@title)
                      elsif rrr.eql?(167) && index.eql?(3)
                        # for Non Owner Occupied
                        @another_title = sheet_data.cell(rrr,ccc)
                        @block_hash[@another_title] = {} unless @block_hash.has_key?(@another_title)
                        @block_hash[@another_title]["Non Owner Occupied"] = {}
                      end

                      #implementation of second key inside first key
                      if rrr > 122 && rrr < 131 && index == 7 && value
                        key = get_value(value)
                        @block_hash[@title]["Conforming"]["Fixed"]["0-15"][key] = {} unless @block_hash[@title]["Conforming"]["Fixed"]["0-15"].has_key?(key)
                      elsif rrr > 132 && rrr < 136 && index == 7 && value
                        # for 1st and 2nd table
                        key = get_value(value)
                        @block_hash[@title]["Cash Out"][key] = {} unless @block_hash[@title]["Cash Out"].has_key?(key)
                      elsif (rrr > 137) && (rrr < 154)
                        # for Lender Paid MI Adjustments
                        if index == 5 && value
                          if ["Rate & Term Refi", "Cash Out"].include?(value)
                            f1_key = "Rate & Term Refi".eql?(value) ? "Rate & Term" : "Cash Out"
                            @block_hash[@title][first_key]["true"][f1_key] = {}
                          elsif ["Manufactured Home", "2nd Home", "3-4 Unit", "Non Owner Occupied"].include?(value)
                            f2_key = value
                            @block_hash[@title][second_key]["true"][f2_key] = {}
                          else
                            @block_hash[@title][final_key]["true"]["0 - 20"] = {} if value.eql?("≤ 20 Yr Term")
                            @block_hash[@title][final_key]["true"]["20 - Inf"] = {} if value.eql?("> 20 Yr Term")
                            key = "0 - 20" if value.eql?("≤ 20 Yr Term")
                            key = "20 - Inf" if value.eql?("> 20 Yr Term")
                          end
                        elsif index == 6 && rrr < 154 && value
                          another_key = value.eql?("≤ 85") ? set_range(value) : value
                          @block_hash[@title][final_key]["true"][key][another_key] = {} if another_key
                        end
                      end

                      if (156..161).to_a.include?(rrr) && ccc < 12
                        # for Subordinate Financing
                        if index.eql?(6)
                          key = sheet_data.cell(rrr,ccc)
                          key = get_value(key)
                          @block_hash[@title]["Subordinate Financing"][key] = {} unless @block_hash[@title].has_key?(key)
                        elsif index.eql?(7)
                          keyOfHash = sheet_data.cell(rrr,ccc)
                          keyOfHash = get_value(keyOfHash)
                          @block_hash[@title]["Subordinate Financing"][key][keyOfHash] = {}
                        end
                      end

                      if (rrr >= 156 && rrr <= 163) && index.eql?(15)
                        # for Loan Size Adjustments
                        loan_amount = get_value(sheet_data.cell(rrr, ccc))
                        @block_hash[@another_title][loan_amount] = {}
                      end

                      if (162..166).to_a.include?(rrr)
                        # for Misc Adjusters
                        if index.eql?(6)
                          key = sheet_data.cell(rrr,ccc)
                          if key && key.eql?("Attached Condo > 75 LTV (>15yr Term)")
                            first_key = key.split(" >")[0].split(" ").last
                            @block_hash[@title][first_key] = {}
                            second_key = sheet_data.cell(rrr,ccc).split(" ")[3] + ".01"
                            @block_hash[@title][first_key][second_key] = {}
                            third_key = sheet_data.cell(rrr,ccc).split(" ")[5].split("(>")[1].split("yr")[0] + ".01"
                          elsif key && key.eql?(">90 LTV")
                            first_key  = key.split(" ")[1]
                            @block_hash[@title][first_key] = {}
                            second_key = key.split(">")[1].split(" ").first
                          end
                        end
                      end

                      if [167,168,169].include?(rrr) && [7].include?(ccc)
                        #for Non Owner Occupied
                        hash_key = sheet_data.cell(rrr,ccc)
                        unless hash_key.eql?("> 80")
                          hash_key = get_value(hash_key)
                          key = hash_key
                        else
                          hash_key = set_range(hash_key)
                          key = hash_key
                        end
                        @block_hash[@another_title]["Non Owner Occupied"][hash_key] = {} if hash_key.present?
                      end

                      # implementation of third key inside second key with value
                      if rrr > 122 && rrr < 131 && index > 7 && value
                        # for 1st table
                        diff_of_row = rrr - 122
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = hash_key.eql?("≥ 760") ? set_range(hash_key) : get_value(hash_key)
                        if hash_key.present?
                          @block_hash[@title]["Conforming"]["Fixed"]["0-15"][key][hash_key] = value unless @block_hash[@title]["Conforming"]["Fixed"]["0-15"][key].has_key?(hash_key)
                        end
                      end

                      if rrr > 132 && rrr < 136 && index > 7 && value
                        # for 2nd table
                        diff_of_row = rrr - 122
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = hash_key.eql?("≥ 760") ? set_range(hash_key) : get_value(hash_key)
                        if hash_key.present?
                          @block_hash[@title]["Cash Out"][key][hash_key] = value unless @block_hash[@title]["Cash Out"][key].has_key?(hash_key)
                        end
                      end

                      if rrr > 137 && rrr <= 153 && index >= 7 && value
                        # for Lender Paid MI Adjustments
                        diff_of_row = rrr - 137
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = set_range(hash_key).nil? ? get_value(hash_key) : set_range(hash_key)
                        if (138..143).to_a.include?(rrr)
                          if [138, 143].include?(rrr)
                            @block_hash[@title][first_key]["true"][f1_key][hash_key] = value
                          elsif [139, 140, 141, 142].include?(rrr)
                            @block_hash[@title][second_key]["true"][f2_key][hash_key] = value
                          end
                        else
                          if rrr > 144
                            @block_hash[@title][final_key]["true"][key][another_key][hash_key] = value
                          end
                        end
                      end

                      if (156..161).to_a.include?(rrr) && ccc > 9 && ccc < 12 && value
                        # for Subordinate Financing
                        diff_of_row = rrr - 155
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = hash_key.eql?("≥ 720") ? set_range(hash_key) : get_value(hash_key)
                        @block_hash[@title]["Subordinate Financing"][key][keyOfHash][hash_key] = value if hash_key.present?
                      end

                      if (156..163).to_a.include?(rrr) && ccc > 15 && value
                        #for Loan Size Adjustments
                        diff_of_row  = rrr - 155
                        loan_purpose = sheet_data.cell(rrr-diff_of_row,ccc)
                        @block_hash[@another_title][loan_amount][loan_purpose] = value
                      end

                      if (162..166).to_a.include?(rrr) && ccc == 11
                        #for Misc Adjusters
                        if rrr.eql?(164)
                          @block_hash[@title][first_key][second_key][third_key] = value
                        else
                          first_key = sheet_data.cell(rrr,ccc - 5)
                          @block_hash["PropertyType"][first_key] = value if ["2-4 Units", "Manufactured Home"].include?(first_key)
                          @block_hash["MiscAdjuster"][first_key] = value if ["CA Escrow Waiver (Full or Taxes Only)", "CA Escrow Waiver (Insurance Only)"].include?(first_key)
                        end
                      end

                      if [167,168,169].include?(rrr) && [11].include?(ccc)
                        @block_hash[@another_title]["Non Owner Occupied"][key] = value if key && value
                      end

                      if [171,172].include?(rrr)
                        # for High Balance
                        if rrr.eql?(171) && index.eql?(19)
                          @block_hash["LoanSize/LoanPurpose/RefinanceOption"]["High-Balance"]["Purchase"] = {}
                          @block_hash["LoanSize/LoanPurpose/RefinanceOption"]["High-Balance"]["Purchase"]["Rate and Term"] = value
                        else
                          @block_hash["LoanSize/RefinanceOption"]["High-Balance"]["Cash Out"] = value
                        end
                      end

                      if [169,170].to_a.include?(rrr) && ccc.eql?(17)
                        if rrr.eql?(169)
                          @block_hash["LockDay"]["30"] = value
                          @block_hash["LockDay"]["45"] = value
                          @block_hash["LockDay"]["60"] = value
                        else
                          @block_hash["LockDay"]["90"] = value
                        end
                      end
                    rescue Exception => e
                      error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
                      error_log.save
                    end
                  end

                  @allAdjustments[@title] = @block_hash[@title]
                  if @another_title
                    @allAdjustments[@another_title] = @block_hash[@another_title]
                    @allAdjustments["PropertyType"] = @block_hash["PropertyType"]
                    @allAdjustments["MiscAdjuster"] = @block_hash["MiscAdjuster"]
                    @allAdjustments["LockDay"] = @block_hash["LockDay"]
                    @allAdjustments["LoanSize/LoanPurpose/RefinanceOption"] = @block_hash["LoanSize/LoanPurpose/RefinanceOption"]
                    @allAdjustments["LoanSize/RefinanceOption"] = @block_hash["LoanSize/RefinanceOption"]
                  end
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
              error_log.save
            end
          end
        end
      end
    end

    # rename first level keys
    @allAdjustments.keys.each do |key|
      data = get_table_keys
      if data[key]
        @allAdjustments[data[key]] = @allAdjustments.delete(key)
      end
    end

    # create adjustment for each program
    make_adjust(@allAdjustments, @sheet)
    create_program_association_with_adjustment(@sheet)
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  def home_possible
    @program_ids = []
    @allAdjustments = {}
    @xlsx.sheets.each do |sheet|
      if (sheet == "Home Possible")
        @sheet_name = sheet
        @sheet = sheet
        sheet_data = @xlsx.sheet(sheet)

        (1..76).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet"))
            rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3 + max_column*6 # (3 / 9 / 15)
              begin
                #title
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                #term
                if @title.include?("10yr") || @title.include?("10 Yr")
                  term = 10
                elsif @title.include?("15yr") || @title.include?("15 Yr")
                  term = 15
                elsif @title.include?("20yr") || @title.include?("20 Yr")
                  term = 20
                elsif @title.include?("25yr") || @title.include?("25 Yr")
                  term = 25
                elsif @title.include?("30yr") || @title.include?("30 Yr")
                  term = 30
                end

                # rate type
                if p_name.include?("Fixed")
                  loan_type = "Fixed"
                elsif p_name.include?("ARM")
                  loan_type = "ARM"
                  arm_benchmark = "LIBOR"
                  arm_margin = 0
                elsif p_name.include?("Floating")
                  loan_type = "Floating"
                elsif p_name.include?("Variable")
                  loan_type = "Variable"
                else
                  loan_type = "Fixed"
                end

                # Arm Basic
                if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM") || @title.include?("5/1 ARM") || @title.include?("7/1 ARM") || @title.include?("10/1 ARM")
                  arm_basic = @title.scan(/\d+/)[0].to_i
                end
                # Arm Advanced
                if @title.downcase.include?("arm")
                  arm_advanced = @title.downcase.split("arm").last.tr('A-Za-z() ','')
                  if arm_advanced.include?('/')
                    arm_advanced = arm_advanced.tr('/','-')
                  else
                    arm_advanced
                  end
                end
                # freddie_mac
                freddie_mac = false
                if p_name.include?("Freddie Mac") || p_name.downcase.include?("fhlmc")
                  freddie_mac = true
                end

                # fannie_mae
                fannie_mae = false
                if p_name.include?("Fannie Mae") || p_name.include?("Freddie Mac Home Ready")
                  fannie_mae = true
                end
                # freddie_mac_product
                if p_name.downcase.include?("home possible")
                  freddie_mac_product = "Home Possible"
                end

                # loan_purpose
                if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                  loan_purpose = "Refinance"
                else
                  loan_purpose = "Purchase"
                end

                # loan_size
                if p_name.downcase.include?('high balance')
                  loan_size = "High Balance"
                else
                  loan_size = "Conforming"
                end

                # lp and du
                if p_name.downcase.include?('du ')
                  du = true
                end
                if p_name.downcase.include?('lp ')
                  lp = true
                end

                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @program_ids << @program.id
                @program.adjustments.destroy_all
                @program.update(term: term,loan_type: loan_type,freddie_mac: freddie_mac, fannie_mae: fannie_mae, loan_category: @sheet_name,arm_basic: arm_basic, freddie_mac_product: freddie_mac_product, arm_advanced: arm_advanced, loan_purpose: loan_purpose, du: du, lp: lp,loan_size: loan_size, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                @block_hash = {}
                key = ''
                (0..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    else
                      @block_hash[key][15*c_i] = value
                    end
                    @data << value
                  end

                  if @data.compact.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil?
                  @block_hash.values.first.shift
                end
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # adjustments
        previous_title = nil
        @another_title = nil
        modified_keys  = get_table_keys
        data = get_table_keys
        (81..133).each do |r|
          row    = sheet_data.row(r)
          # r == 52 / 68 / 81 / 84 / 89 / 94
          rr = r #+ 1 # (r == 53) / (r == 69) / (r == 82) / (r == 90) / (r == 95)
          max_column_section = 0#row.compact.count - 1
          (0..max_column_section).each do |max_column|
            cc = 3 + max_column * 9 # (2 / 11)
            @title = sheet_data.cell(r,cc)
            @block_hash = {}
            if(@title.eql?("All Conforming (does not apply to Fixed terms ≤ 15yrs)"))
              @block_hash["PropertyType"] = {} unless @block_hash.has_key?("PropertyType")
              @block_hash["LockDay"] = {} unless @block_hash.has_key?("LockDay")
              key = ''
              another_key = ''
              keyOfHash = ''
              # for Misc Adjusters
              first_key   = ''
              second_key  = ''
              third_key   = ''
              final_key   = ''
              f1_key      = ''
              f2_key      = ''
              loan_amount = ''
              (0..55).each do |max_row|
                @data = []
                (3..19).each_with_index do |index, c_i|
                  rrr = rr + max_row
                  ccc = index
                  begin
                    value = sheet_data.cell(rrr,ccc)
                    # implementation of first key
                    if rrr.eql?(81) && index == 3
                      # for All Conforming
                      @title = "LoanSize/LoanType/Term/FICO/LTV"
                      @block_hash[@title] = {}
                      @block_hash[@title]["Conforming"] = {}
                      @block_hash[@title]["Conforming"]["Fixed"] = {}
                      @block_hash[@title]["Conforming"]["Fixed"]["0-15"] = {}
                    elsif rrr.eql?(93) && index == 3
                      # for Lender Paid MI Adjustments
                      previous_title = @title = sheet_data.cell(rrr,ccc) unless previous_title == @title
                      unless @block_hash.has_key?(@title)
                        @block_hash[@title] = {}
                        first_key  = "LPMI/RefinanceOption/LTV"
                        second_key = "LPMI/PropertyType/LTV"
                        final_key  = "LPMI/Term/FICO/LTV"
                        @block_hash[@title][first_key] = {}
                        @block_hash[@title][first_key]["true"] = {}
                        @block_hash[@title][second_key] = {}
                        @block_hash[@title][second_key]["true"] = {}
                        @block_hash[@title][final_key] = {}
                        @block_hash[@title][final_key]["true"] = {}
                      end
                    elsif rrr.eql?(107) && index == 3
                      # for VLIP LPMI Adjustments
                      @block_hash["LPMI/PropertyType/FICO"] = {} unless @block_hash.has_key?("LPMI/PropertyType/FICO")
                      @block_hash["LPMI/Term/FICO/LTV"] = {} unless @block_hash.has_key?("LPMI/Term/FICO/LTV")
                    elsif rrr.eql?(115) && index == 3
                      # for Subordinate Financing
                      @title = sheet_data.cell(rrr,ccc)
                      unless @block_hash.has_key?(@title)
                        @block_hash[@title] = {}
                        @block_hash[@title]["Subordinate Financing"] = {}
                      end
                    elsif rrr.eql?(115) && index == 13
                      # for Loan Size Adjustments
                      @another_title = sheet_data.cell(rrr,index)
                      unless @block_hash.has_key?(@another_title)
                        @block_hash[@another_title] = {}
                      end
                    elsif rrr.eql?(120) && index == 3
                      # for Misc Adjusters
                      @title = sheet_data.cell(rrr,ccc)
                      @block_hash[@title] = {} unless @block_hash.has_key?(@title)
                    elsif rrr.eql?(123) && index.eql?(3)
                      # for Number Of Units
                      @title = sheet_data.cell(rrr,ccc)
                      unless @block_hash.has_key?(@title)
                        @block_hash[@title] = {}
                      end
                    elsif rrr.eql?(130) && index.eql?(13)
                      # for Adjustment Caps
                      @title = sheet_data.cell(rrr,ccc)
                      @block_hash[@title] = {} unless @block_hash.has_key?(@title)
                    end

                    #implementation of second key inside first key
                    if (81..88).to_a.include?(rrr) && index == 7 && value
                      # for All Conforming
                      key = get_value(value)
                      if key
                        @block_hash[@title]["Conforming"]["Fixed"]["0-15"][key] = {} unless @block_hash[@title]["Conforming"]["Fixed"]["0-15"].has_key?(key)
                      end
                    end

                    if (rrr > 92) && (rrr < 106)
                      # for Lender Paid MI Adjustments
                      if index == 5 && value
                        if ["Rate & Term Refi", "Cash Out"].include?(value)
                          f1_key = "Rate & Term Refi".eql?(value) ? "Rate & Term" : "Cash Out"
                          @block_hash[@title][first_key]["true"][f1_key] = {}
                        elsif ["Manufactured Home", "2nd Home", "3-4 Unit", "Non Owner Occupied"].include?(value)
                          f2_key = value
                          @block_hash[@title][second_key]["true"][f2_key] = {}
                        else
                          @block_hash[@title][final_key]["true"]["0 - 20"] = {} if value.eql?("≤ 20 Yr Term")
                          @block_hash[@title][final_key]["true"]["20 - Inf"] = {} if value.eql?("> 20 Yr Term")
                          key = "0 - 20" if value.eql?("≤ 20 Yr Term")
                          key = "20 - Inf" if value.eql?("> 20 Yr Term")
                        end
                      elsif index == 6 && rrr < 106 && value
                        another_key = value.eql?("≤ 85") ? set_range(value) : value
                        @block_hash[@title][final_key]["true"][key][another_key] = {} if another_key
                      end
                    elsif (107..112).to_a.include?(rrr) && index < 7 && value
                      if(rrr == 107) && (ccc == 4)
                        # for VLIP LPMI Adjustments
                          @title = "LPMI/PropertyType/FICO"
                          key = sheet_data.cell(rrr,ccc)
                          @block_hash[@title]["true"] = {}
                          @block_hash[@title]["true"][key] = {}
                      elsif (rrr == 109) && (ccc == 4)
                        @title = "LPMI/Term/FICO/LTV"
                        first_key  = sheet_data.cell(rrr,ccc)
                        second_key = sheet_data.cell(rrr,ccc + 1)
                        second_key.to_i
                        @block_hash[@title]["true"] = {}
                        @block_hash[@title]["true"][second_key.to_i.to_s] = {}
                      elsif (rrr > 108) && (ccc == 6)
                        key = get_value(value)
                        @block_hash[@title]["true"][second_key.to_i.to_s][key] = {} if second_key && key
                      end
                    end

                    if (115..118).to_a.include?(rrr) && ccc < 10
                      # for Subordinate Financing
                      if index.eql?(6)
                        key = sheet_data.cell(rrr,ccc)
                        key = get_value(key)
                        @block_hash[@title]["Subordinate Financing"][key] = {} unless @block_hash[@title].has_key?(key)
                      elsif index.eql?(7)
                        keyOfHash = sheet_data.cell(rrr,ccc)
                        keyOfHash = get_value(keyOfHash)
                        @block_hash[@title]["Subordinate Financing"][key][keyOfHash] = {}
                      end
                    end

                    if (120..121).to_a.include?(rrr)
                      # for Misc Adjusters
                      if index.eql?(6)
                        key = sheet_data.cell(rrr,ccc)
                        if key && key.eql?("Attached Condo > 75 LTV (>15yr Term)")
                          first_key = key.split(" >")[0].split(" ").last
                          @block_hash[@title][first_key] = {}
                          second_key = key.split(" ")[3] + ".01"
                          @block_hash[@title][first_key][second_key] = {}
                          third_key = key.split(" ")[5].split("(>")[1].split("yr")[0] + ".01"
                        end
                      end
                    end

                    if (rrr >= 116 && rrr <= 123) && index.eql?(15)
                      # for Loan Size Adjustments
                      loan_amount = get_value(sheet_data.cell(rrr, ccc))
                      @block_hash[@another_title][loan_amount] = {}
                    end

                    if [124,125].include?(rrr) && ccc == 6
                      # for Number Of Units
                      key = sheet_data.cell(rrr,ccc)
                      @block_hash[@title][key] = {}
                    end

                    # implementation of third key inside second key with value
                    if (81..88).to_a.include?(rrr) && index > 9 && value
                      #  for All Conforming
                      diff_of_row = rrr - 80
                      hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                      hash_key = hash_key.eql?("≥ 760") ? set_range(hash_key) : get_value(hash_key)
                      if hash_key.present?
                        @block_hash[@title]["Conforming"]["Fixed"]["0-15"][key][hash_key] = value unless @block_hash[@title]["Conforming"]["Fixed"]["0-15"][key].has_key?(hash_key)
                      end
                    end

                    if rrr > 92 && rrr <= 105 && index >= 7 && value
                      # for Lender Paid MI Adjustments
                      diff_of_row = rrr - 92
                      hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                      hash_key = set_range(hash_key).nil? ? get_value(hash_key) : set_range(hash_key)
                      if (93..95).to_a.include?(rrr)
                        if rrr.eql?(93)
                          @block_hash[@title][first_key]["true"][f1_key][hash_key] = value
                        elsif [94, 95].include?(rrr)
                          @block_hash[@title][second_key]["true"][f2_key][hash_key] = value
                        end
                      else
                        if rrr > 96
                          @block_hash[@title][final_key]["true"][key][another_key][hash_key] = value
                        end
                      end
                    end

                    if ((107..112).to_a.include?(rrr) && (ccc > 6))
                      # for VLIP LPMI Adjustments
                      diff_of_row = rrr - 92
                      hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                      hash_key = get_value(hash_key)
                      if(rrr == 107)
                        # for VLIP LPMI Adjustments
                        @block_hash[@title]["true"][key][hash_key] = value if value && hash_key
                      elsif (109..112).to_a.include?(rrr)
                         @block_hash[@title]["true"][second_key.to_i.to_s][hash_key] = value if value && hash_key
                      end
                    elsif (115..118).to_a.include?(rrr) && ccc > 9 && ccc < 12 && value
                      # for Subordinate Financing
                      diff_of_row = rrr - 114
                      hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                      hash_key = hash_key.eql?("≥ 720") ? set_range(hash_key) : get_value(hash_key)
                      @block_hash[@title]["Subordinate Financing"][key][keyOfHash][hash_key] = value if hash_key.present?
                    end

                    if [120,121].include?(rrr) && ccc == 11
                      #for Misc Adjusters
                      if rrr.eql?(120)
                        @block_hash[@title][first_key][second_key][third_key] = value
                      else
                        first_key = sheet_data.cell(rrr,ccc - 5)
                        @block_hash["PropertyType"][first_key] = value if ("Manufacured Home").eql?(first_key)
                      end
                    end

                    if (116..123).to_a.include?(rrr) && ccc > 15 && value
                      #for Loan Size Adjustments
                      diff_of_row  = rrr - 115
                      loan_purpose = sheet_data.cell(rrr-diff_of_row,ccc)
                      @block_hash[@another_title][loan_amount][loan_purpose] = value
                    end

                    if [124,125].include?(rrr) && [9,10,11].include?(ccc)
                      # for Number Of Units
                      diff_of_row = rrr - 123
                      hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                      hash_key = (hash_key.eql?("≤ 80") || hash_key.eql?("> 85")) ? set_range(hash_key) : get_value(hash_key)
                      @block_hash[@title][key][hash_key] = value if hash_key.present?
                    end

                    if rrr.eql?(127) && ccc.eql?(8)
                      @block_hash["LockDay"]["30"] = value
                      @block_hash["LockDay"]["45"] = value
                      @block_hash["LockDay"]["60"] = value
                    end
                  rescue Exception => e
                    error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: @sheet_name, error_detail: e.message)
                    error_log.save
                  end
                end

                @allAdjustments[@title] = @block_hash[@title]
                if @another_title
                  @allAdjustments[@another_title] = @block_hash[@another_title]
                  @allAdjustments["PropertyType"] = @block_hash["PropertyType"]
                  @allAdjustments["LockDay"] = @block_hash["LockDay"]
                end
              end
            end
          end
        end
      end
    end

    # rename first level keys
    @allAdjustments.keys.each do |key|
      data = get_table_keys
      if data[key]
        @allAdjustments[data[key]] = @allAdjustments.delete(key)
      end
    end
    # create adjustment for each program
    make_adjust(@allAdjustments, @sheet)
    create_program_association_with_adjustment(@sheet)
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  # def lp_open_acces_arms
  #   @programs_ids = []
  #   @xlsx.sheets.each do |sheet|
  #     if (sheet == "LP Open Acces ARMs")
  #      sheet_data = @xlsx.sheet(sheet)
  #       @adjustment_hash = {}
  #       @program_ids = []
  #       @fixed_data = []
  #       @sub_data = []
  #       @unit_data = []
  #       primary_key = ''
  #       secondry_key = ''
  #       misc_adj_key = ''
  #       term_key = ''
  #       ltv_key = ''
  #       cltv_key = ''
  #       misc_key = ''
  #       fixed_key = ''
  #       sub_data = ''
  #       key = ''
  #       @sheet = sheet
  #       (1..35).each do |r|
  #         row = sheet_data.row(r)
  #         if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet"))
  #           rr = r + 1
  #           max_column_section = row.compact.count - 1
  #           (0..max_column_section).each do |max_column|
  #             cc = 3 + max_column*6 # (3 / 9 / 15)
  #             begin
  #               # title
  #               @title = sheet_data.cell(r,cc)

  #               # term
  #               term = nil
  #               program_heading = @title.split
  #               if @title.include?("10yr") || @title.include?("10 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("15yr") || @title.include?("15 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("20yr") || @title.include?("20 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("25yr") || @title.include?("25 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("30yr") || @title.include?("30 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               end

  #               # interest type
  #               if @title.include?("Fixed")
  #                 loan_type = "Fixed"
  #               elsif @title.include?("ARM")
  #                 loan_type = "ARM"
  #               elsif @title.include?("Floating")
  #                 loan_type = "Floating"
  #               elsif @title.include?("Variable")
  #                 loan_type = "Variable"
  #               else
  #                 loan_type = nil
  #               end

  #               # rate arm
  #               if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM")
  #                 arm_basic = @title.scan(/\d+/)[0].to_i
  #               end

  #               # conforming
  #               conforming = false
  #               if @title.include?("Freddie Mac") || @title.include?("Fannie Mae") || @title.include?("Freddie Mac Home Possible") || @title.include?("Freddie Mac Home Ready")
  #                 conforming = true
  #               end

  #               # freddie_mac
  #               freddie_mac = false
  #               if @title.include?("Freddie Mac")
  #                 freddie_mac = true
  #               end

  #               # fannie_mae
  #               fannie_mae = false
  #               if @title.include?("Fannie Mae") || @title.include?("Freddie Mac Home Ready")
  #                 fannie_mae = true
  #               end

  #               @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
  #               @program_ids << @program.id
  #                # Loan Limit Type
  #               if @title.include?("Non-Conforming")
  #                 @program.loan_limit_type << "Non-Conforming"
  #               end
  #               if @title.include?("Conforming")
  #                 @program.loan_limit_type << "Conforming"
  #               end
  #               if @title.include?("Jumbo")
  #                 @program.loan_limit_type << "Jumbo"
  #               end
  #               if @title.include?("High Balance")
  #                 @program.loan_limit_type << "High Balance"
  #               end
  #               @program.save
  #               @program.update(term: term,loan_type: loan_type,conforming: conforming,freddie_mac: freddie_mac, fannie_mae: fannie_mae, arm_basic: arm_basic, loan_category: sheet)
  #               @program.adjustments.destroy_all
  #               @block_hash = {}
  #               key = ''
  #               # main_key = ''
  #               # if @program.term.present?
  #               #   main_key = "Term/LoanType/InterestRate/LockPeriod"
  #               # else
  #               #   main_key = "InterestRate/LockPeriod"
  #               # end
  #               # @block_hash[main_key] = {}
  #               (0..50).each do |max_row|
  #                 @data = []
  #                 (0..4).each_with_index do |index, c_i|
  #                   rrr = rr + max_row
  #                   ccc = cc + c_i
  #                   value = sheet_data.cell(rrr,ccc)
  #                   if (c_i == 0)
  #                     key = value
  #                     @block_hash[key] = {}
  #                   else
  #                     if @program.lock_period.length <= 3
  #                       @program.lock_period << 15*c_i
  #                       @program.save
  #                     end
  #                     @block_hash[key][15*c_i] = value
  #                   end
  #                   @data << value
  #                 end

  #                 if @data.compact.length == 0
  #                   break # terminate the loop
  #                 end
  #               end
  #               if @block_hash.values.first.keys.first.nil?
  #                 @block_hash.values.first.shift
  #               end
  #               @block_hash.delete(nil)
  #               @program.update(base_rate: @block_hash)
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #         end
  #       end
  #       # Adjustments
  #       (37..71).each do |r|
  #         row = sheet_data.row(r)
  #         @fixed_data = sheet_data.row(39)
  #         @sub_data = sheet_data.row(47)
  #         @unit_data = sheet_data.row(56)
  #         if row.compact.count >= 1
  #           (0..19).each do |max_column|
  #             cc = max_column
  #             value = sheet_data.cell(r,cc)
  #             begin
  #               if value.present?
  #                 if value == "Loan Level Price Adjustments: See Adjustment Caps" || value == "Adjustments Applied after Cap"
  #                   primary_key = value
  #                   @adjustment_hash[primary_key] = {}
  #                 end
  #                 if value == "All LP Open Access ARMs" || value == "Subordinate Financing" || value == "Number Of Units" || value == "Loan Size Adjustments"
  #                   secondry_key = value
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end

  #                 # All LP Open Access ARMs
  #                 if r >= 40 && r<= 45 && cc == 8# && cc <= 19 && cc != 15
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 40 && r<= 45 && cc > 8 && cc != 15 && cc <= 19
  #                   fixed_key = get_value @fixed_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][fixed_key] = {}
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][fixed_key] = value
  #                 end

  #                 # Subordinate Financing Adjustments
  #                 if r >= 48 && r <= 54 && cc == 5
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 48 && r <= 54 && cc == 6
  #                   cltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key] = {}
  #                 end
  #                 if r >= 48 && r<= 54 && cc >= 9 && cc <= 10
  #                   sub_data = get_value @sub_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key][sub_data] = {}
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key][sub_data] = value
  #                 end

  #                 # Number Of Units Adjustments
  #                 if r >= 57 && r <= 58 && cc == 3
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 57 && r <= 58 && cc > 3 && cc <= 7
  #                   sub_data = get_value @unit_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][sub_data] = {}
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][sub_data] = value
  #                 end

  #                 # Adjustments Applied after Cap
  #                 if r >= 61 && r <= 67 && cc == 6
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 61 && r <= 67 && cc == 10
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = value
  #                 end

  #                 # Other Adjustments
  #                 if r >= 69 && r <= 71 && cc == 3
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 69 && r <= 71 && cc == 10
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = value
  #                 end
  #               end
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #           (12..19).each do |max_column|
  #             cc = max_column
  #             value = sheet_data.cell(r,cc)
  #             begin
  #               if value.present?
  #                 if  value == "Misc Adjusters" || value == "Adjustment Caps"
  #                   key = value
  #                   @adjustment_hash[key] = {}
  #                 end

  #                 # Misc Adjustments
  #                 if r >= 47 && r <= 57 && cc == 15
  #                   if value.include?("Condo")
  #                     misc_key = "Condo=>75.01=>15.01"
  #                   else
  #                     misc_key = value
  #                   end
  #                   @adjustment_hash[key][misc_key] = {}
  #                 end
  #                 if r >= 47 && r <= 57 && cc == 19
  #                   @adjustment_hash[key][misc_key] = value
  #                 end

  #                 # Adjustment Caps
  #                 if r >= 62 && r <= 65 && cc == 16
  #                   misc_key = value
  #                   @adjustment_hash[key][misc_key] = {}
  #                 end
  #                 if r >= 62 && r <= 65 && cc == 17
  #                   term_key = get_value value
  #                   @adjustment_hash[key][misc_key][term_key] = {}
  #                 end
  #                 if r >= 62 && r <= 65 && cc == 18
  #                   ltv_key = get_value value
  #                   @adjustment_hash[key][misc_key][term_key][ltv_key] = {}
  #                 end
  #                 if r >= 62 && r <= 65 && cc == 19
  #                   @adjustment_hash[key][misc_key][term_key][ltv_key] = value
  #                 end
  #                 if r >= 67 && r <= 68 && cc == 12
  #                   misc_key = value
  #                   @adjustment_hash[key][misc_key] = {}
  #                 end
  #                 if r >= 67 && r <= 68 && cc == 16
  #                   @adjustment_hash[key][misc_key] = value
  #                 end
  #               end
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #         end
  #       end
  #       make_adjust(@adjustment_hash, @sheet)
  #       create_program_association_with_adjustment(@sheet)
  #     end
  #   end
  #   redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  # end

  # def lp_open_access_105
  #   @programs_ids = []
  #   @xlsx.sheets.each do |sheet|
  #     if (sheet == "LP Open Access_105")
  #       sheet_data = @xlsx.sheet(sheet)
  #       @adjustment_hash = {}
  #       @program_ids = []
  #       @fixed_data = []
  #       @sub_data = []
  #       primary_key = ''
  #       secondry_key = ''
  #       ltv_key = ''
  #       cltv_key = ''
  #       term_key = ''
  #       caps_key = ''
  #       max_key = ''
  #       fixed_key = ''
  #       @sheet = sheet
  #       (1..61).each do |r|
  #         row = sheet_data.row(r)
  #         if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet")) || (row.include?("LP Open Access 10yr Fixed >125 LTV"))
  #           rr = r + 1
  #           max_column_section = row.compact.count - 1
  #           (0..max_column_section).each do |max_column|
  #             cc = 3 + max_column*6
  #             begin
  #               # title
  #               @title = sheet_data.cell(r,cc)

  #               # term
  #               term = nil
  #               program_heading = @title.split
  #               if @title.include?("10yr") || @title.include?("10 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("15yr") || @title.include?("15 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("20yr") || @title.include?("20 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("25yr") || @title.include?("25 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("30yr") || @title.include?("30 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               end

  #               # interest type
  #               if @title.include?("Fixed")
  #                 loan_type = "Fixed"
  #               elsif @title.include?("ARM")
  #                 loan_type = "ARM"
  #               elsif @title.include?("Floating")
  #                 loan_type = "Floating"
  #               elsif @title.include?("Variable")
  #                 loan_type = "Variable"
  #               else
  #                 loan_type = nil
  #               end

  #               # interest sub type
  #               if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM")
  #                 arm_basic = @title.scan(/\d+/)[0].to_i
  #               end

  #               # conforming
  #               conforming = false
  #               if @title.include?("Freddie Mac") || @title.include?("Fannie Mae") || @title.include?("Freddie Mac Home Possible") || @title.include?("Freddie Mac Home Ready")
  #                 conforming = true
  #               end

  #               # freddie_mac
  #               freddie_mac = false
  #               if @title.include?("Freddie Mac")
  #                 freddie_mac = true
  #               end

  #               # fannie_mae
  #               fannie_mae = false
  #               if @title.include?("Fannie Mae") || @title.include?("Freddie Mac Home Ready")
  #                 fannie_mae = true
  #               end

  #               @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
  #               @program_ids << @program.id
  #               # Loan Limit Type
  #               if @title.include?("Non-Conforming")
  #                 @program.loan_limit_type << "Non-Conforming"
  #               end
  #               if @title.include?("Conforming")
  #                 @program.loan_limit_type << "Conforming"
  #               end
  #               if @title.include?("Jumbo")
  #                 @program.loan_limit_type << "Jumbo"
  #               end
  #               if @title.include?("High Balance")
  #                 @program.loan_limit_type << "High Balance"
  #               end
  #               @program.save
  #               @program.update(term: term,loan_type: loan_type,conforming: conforming,freddie_mac: freddie_mac, fannie_mae: fannie_mae, arm_basic: arm_basic, loan_category: sheet)
  #               @program.adjustments.destroy_all
  #               @block_hash = {}
  #               key = ''
  #               # main_key = ''
  #               # if @program.term.present?
  #               #   main_key = "Term/LoanType/InterestRate/LockPeriod"
  #               # else
  #               #   main_key = "InterestRate/LockPeriod"
  #               # end
  #               # @block_hash[main_key] = {}
  #               (0..50).each do |max_row|
  #                 @data = []
  #                 (0..4).each_with_index do |index, c_i|
  #                   rrr = rr + max_row
  #                   ccc = cc + c_i
  #                   value = sheet_data.cell(rrr,ccc)
  #                   if (c_i == 0)
  #                     key = value
  #                     @block_hash[key] = {}
  #                   else
  #                     if @program.lock_period.length <= 3
  #                       @program.lock_period << 15*c_i
  #                       @program.save
  #                     end
  #                     @block_hash[key][15*c_i] = value
  #                   end
  #                   @data << value
  #                 end

  #                 if @data.compact.length == 0
  #                   break # terminate the loop
  #                 end
  #               end
  #               if @block_hash.values.first.keys.first.nil?
  #                 @block_hash.values.first.shift
  #               end
  #               @block_hash.delete(nil)
  #               @program.update(base_rate: @block_hash)
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #         end
  #       end
  #       # Adjustment
  #       (63..86).each do |r|
  #         row = sheet_data.row(r)
  #         @fixed_data = sheet_data.row(65)
  #         @sub_data = sheet_data.row(68)
  #         if row.compact.count >= 1
  #           (0..19).each do |max_column|
  #             cc = max_column
  #             value = sheet_data.cell(r,cc)
  #             begin
  #               if value.present?
  #                 if value == "Loan Level Price Adjustments: See Adjustment Caps" || value == "Adjustments Applied after Cap"
  #                   primary_key = value
  #                   @adjustment_hash[primary_key] = {}
  #                 end
  #                 if value == "All Fixed Conforming > 15yr Terms (All Occupancies)"
  #                   secondry_key = "LoanSize/LoanType/Term/FICO/LTV"
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end
  #                 if value == "Subordinate Financing"
  #                   secondry_key = "FinancingType/LTV/CLTV/FICO"
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end
  #                 if value == "Number Of Units"
  #                   secondry_key = "PropertyType/LTV"
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end
  #                 if value == 'Loan Size Adjustments'
  #                   secondry_key = "Loan Size Adjustments"
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end

  #                 # All Fixed Conforming Adjustments
  #                 if r == 66 && cc == 6
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r == 66 && cc > 6 && cc <= 19 && cc != 15
  #                   fixed_key = get_value @fixed_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][fixed_key] = {}
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][fixed_key] = value
  #                 end

  #                 # Subordinate Financing
  #                 if r == 69 && cc == 5
  #                   ltv_key = value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r == 69 && cc == 6
  #                   cltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key] = {}
  #                 end
  #                 if r == 69 && cc >= 9 && cc <= 10
  #                   fixed_key = get_value @sub_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key][fixed_key] = {}
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key][fixed_key] = value
  #                 end

  #                 # Number Of Units
  #                 if r >= 72 && r <= 73 && cc == 3
  #                   ltv_key = value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 72 && r <= 73 && cc == 5
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = value
  #                 end

  #                 # Adjustments Applied after Cap
  #                 if r >= 76 && r <= 82 && cc == 6
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 76 && r <= 82 && cc == 10
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = value
  #                 end

  #                 # Other Adjustments
  #                 if r >= 84 && r <= 86 && cc == 3
  #                   ltv_key = value
  #                   @adjustment_hash[primary_key][ltv_key] = {}
  #                 end
  #                 if r >= 84 && r <= 86 && cc == 10
  #                   @adjustment_hash[primary_key][ltv_key] = value
  #                 end
  #               end
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #           (12..19).each do |max_column|
  #             cc = max_column
  #             begin
  #               value = sheet_data.cell(r,cc)
  #               if value.present?
  #                 if  value == "Misc Adjusters" || value == "Adjustment Caps"
  #                   @key = value
  #                   @adjustment_hash[primary_key][@key] = {}
  #                 end

  #                 # Misc Adjustments
  #                 if r >= 68 && r <= 72 && cc == 15
  #                   if value.include?("Condo")
  #                     cltv_key = "Condo=>105=>15.01"
  #                   else
  #                     cltv_key = value
  #                   end
  #                   @adjustment_hash[primary_key][@key][cltv_key] = {}
  #                 end
  #                 if r >= 68 && r <= 72 && cc == 19
  #                   @adjustment_hash[primary_key][@key][cltv_key] = value
  #                 end

  #                 # Adjustment Caps
  #                 if r > 76 && r <= 79 && cc == 16
  #                   caps_key = value
  #                   @adjustment_hash[primary_key][@key][caps_key] = {}
  #                 end
  #                 if r > 76 && r <= 79 && cc == 17
  #                   term_key = get_value value
  #                   @adjustment_hash[primary_key][@key][caps_key][term_key] = {}
  #                 end
  #                 if r > 76 && r <= 79 && cc == 18
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][@key][caps_key][term_key][ltv_key] = {}
  #                 end
  #                 if r > 76 && r <= 79 && cc == 19
  #                   @adjustment_hash[primary_key][@key][caps_key][term_key][ltv_key] = value
  #                 end

  #                 # Other Adjustments
  #                 if r == 82 && cc == 12
  #                   max_key = value
  #                   @adjustment_hash[primary_key][max_key] = {}
  #                 end
  #                 if r == 82 && cc == 16
  #                   @adjustment_hash[primary_key][max_key] = value
  #                 end
  #               end
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #         end
  #       end
  #       make_adjust(@adjustment_hash, @program_ids)
  #       create_program_association_with_adjustment(@sheet)
  #     end
  #   end
  #   redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  # end

  def jumbo_series_d
    @adjustment_hash = {}
    @property_hash = {}
    @state = {}
    primary_key = ''
    ltv_key = ''
    secondry_key = ''
    @programs_ids =[]
    @xlsx.sheets.each do |sheet|
      if (sheet == "Jumbo Series_D")
        @sheet_name = sheet
        @sheet = sheet
        sheet_data = @xlsx.sheet(sheet)
        (1..22).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet"))
            rr = r + 1 # (r == 8)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 2 + max_column*6 # (2 / 8 / 14)
              begin
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                program_heading = @title.split
                term =  program_heading[3]
                loan_type = program_heading[5]
                if p_name.downcase.include?("jumbo")
                  loan_size = "Jumbo"
                else
                  loan_size = "Conforming"
                end
                # loan_purpose
                if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                  loan_purpose = "Refinance"
                else
                  loan_purpose = "Purchase"
                end

                # lp and du
                if p_name.downcase.include?('du ')
                  du = true
                end
                if p_name.downcase.include?('lp ')
                  lp = true
                end

                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @programs_ids  << @program.id
                @program.update(term: term,loan_type: loan_type, loan_category: @sheet_name,loan_size: loan_size, loan_purpose: loan_purpose, du: du, lp: lp)
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (0..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {} if key.present?
                    else
                      begin
                        @block_hash[key][15*c_i] = value if key.present? &&value.present?
                      rescue Exception => e
                      end
                    end
                    @data << value
                  end
                  if @data.compact.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil?
                  @block_hash.values.first.shift
                end
                @block_hash.delete(nil)
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        #For Adjustments
        (41..71).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(44)
          if row.count >= 1
            (0..17).each do |cc|
              value = sheet_data.cell(r,cc)
              begin
                if value.present?
                  if value == "FICO/LTV Adjustments - Loan Amount ≤ $1MM"
                    @adjustment_hash["LoanAmount/FICO/LTV"] = {}
                    @adjustment_hash["LoanAmount/FICO/LTV"]["0-1000000"] = {}
                    @adjustment_hash["LoanAmount/FICO/LTV"]["1000000-#{(Float::INFINITY).to_s.downcase}"] = {}
                  end
                  if value == "Feature Adjustments"
                    @property_hash["PropertyType/LTV"] = {}
                  end
                  if value == "State Adjustments"
                    @state["State"] = {}
                  end
                  # FICO/LTV Adjustments - Loan Amount ≤ $1MM
                  if r >= 45 && r <= 51 && cc == 3
                    if value.include?(">")
                      primary_key = value.tr('>= ','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      primary_key = value
                    end
                    @adjustment_hash["LoanAmount/FICO/LTV"]["0-1000000"][primary_key] = {}
                  end
                  if r >= 45 && r <= 51 && cc >= 4 && cc <= 9
                    if @ltv_data[cc-1].include?("<")
                      ltv_key = "0-"+@ltv_data[cc-1].tr('<= ','')
                    else
                      ltv_key = @ltv_data[cc-1]
                    end
                    @adjustment_hash["LoanAmount/FICO/LTV"]["0-1000000"][primary_key][ltv_key] = {}
                    @adjustment_hash["LoanAmount/FICO/LTV"]["0-1000000"][primary_key][ltv_key] = value
                  end
                  # State Adjustments
                  if r >= 45 && r <= 61 && cc == 11
                    secondry_key = value
                    @state["State"][secondry_key] = {}
                    cc = cc + 1
                    new_val = sheet_data.cell(r,cc)
                    @state["State"][secondry_key] = new_val
                  end
                  if r >= 45 && r <= 61 && cc == 13
                    secondry_key = value
                    @state["State"][secondry_key] = {}
                    cc = cc + 2
                    new_val = sheet_data.cell(r,cc)
                    @state["State"][secondry_key] = new_val
                  end
                  if r >= 45 && r <= 61 && cc == 16
                    secondry_key = value
                    @state["State"][secondry_key] = {}
                    cc = cc + 1
                    new_val = sheet_data.cell(r,cc)
                    @state["State"][secondry_key] = new_val
                  end
                  # FICO/LTV Adjustments - Loan Amount > $1MM
                  if r >= 55 && r <= 61 && cc == 3
                    if value.include?(">")
                      primary_key = value.tr('>= ','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      primary_key = value
                    end
                    @adjustment_hash["LoanAmount/FICO/LTV"]["1000000-#{(Float::INFINITY).to_s.downcase}"][primary_key] = {}
                  end
                  if r >= 55 && r <= 61 && cc >= 4 && cc <= 9
                    if @ltv_data[cc-1].include?("<")
                      ltv_key = "0-"+@ltv_data[cc-1].tr('<= ','')
                    else
                      ltv_key = @ltv_data[cc-1]
                    end
                    @adjustment_hash["LoanAmount/FICO/LTV"]["1000000-#{(Float::INFINITY).to_s.downcase}"][primary_key][ltv_key] = {}
                    @adjustment_hash["LoanAmount/FICO/LTV"]["1000000-#{(Float::INFINITY).to_s.downcase}"][primary_key][ltv_key] = value
                  end
                  # Max Price
                  if r == 64 && cc == 11
                    @adjustment_hash["LoanType/Term"] = {}
                    @adjustment_hash["LoanType/Term"]["Fixed"] = {}
                    @adjustment_hash["LoanType/Term"]["Fixed"]["20"] = {}
                    @adjustment_hash["LoanType/Term"]["Fixed"]["30"] = {}
                    cc = cc + 4
                    new_val = sheet_data.cell(r,cc)
                    @adjustment_hash["LoanType/Term"]["Fixed"]["20"] = new_val
                    @adjustment_hash["LoanType/Term"]["Fixed"]["30"] = new_val
                  end
                  if r == 65 && cc == 11
                    @adjustment_hash["LoanType/Term"]["Fixed"]["15"] = {}
                    cc = cc + 4
                    new_val = sheet_data.cell(r,cc)
                    @adjustment_hash["LoanType/Term"]["Fixed"]["15"] = new_val
                  end
                  # Feature Adjustments
                  if r >= 65 && r <= 67 && cc == 2
                    if value == "Investment"
                      primary_key = "Investment Property"
                    else
                      primary_key = value
                    end
                    @property_hash["PropertyType/LTV"][primary_key] = {}
                  end
                  if r >= 65 && r <= 67 && cc >= 4 && cc <= 9
                    if @ltv_data[cc-1].include?("<")
                      ltv_key = "0-"+@ltv_data[cc-1].tr('<= ','')
                    else
                      ltv_key = @ltv_data[cc-1]
                    end
                    @property_hash["PropertyType/LTV"][primary_key][ltv_key] = {}
                    @property_hash["PropertyType/LTV"][primary_key][ltv_key] = value
                  end
                  if r == 68 && cc == 2
                    @property_hash["RefinanceOption/LTV"] = {}
                    @property_hash["RefinanceOption/LTV"]["Cash Out"] = {}
                  end
                  if r == 68 && cc >= 4 && cc <= 9
                    if @ltv_data[cc-1].include?("<")
                      ltv_key = "0-"+@ltv_data[cc-1].tr('<= ','')
                    else
                      ltv_key = @ltv_data[cc-1]
                    end
                    @property_hash["RefinanceOption/LTV"]["Cash Out"][ltv_key] = {}
                    @property_hash["RefinanceOption/LTV"]["Cash Out"][ltv_key] = value
                  end
                  if r >= 69 && r <= 70 && cc == 2
                    primary_key = value
                    @property_hash["PropertyType/LTV"][primary_key] = {}
                  end
                  if r >= 69 && r <= 70 && cc >= 4 && cc <= 9
                    if @ltv_data[cc-1].include?("<")
                      ltv_key = "0-"+@ltv_data[cc-1].tr('<= ','')
                    else
                      ltv_key = @ltv_data[cc-1]
                    end
                    @property_hash["PropertyType/LTV"][primary_key][ltv_key] = {}
                    @property_hash["PropertyType/LTV"][primary_key][ltv_key] = value
                  end
                  if r == 70 && cc == 2
                    @property_hash["MiscAdjuster/LTV"] = {}
                    @property_hash["MiscAdjuster/LTV"]["Escrow Waiver - except CA"] = {}
                  end
                  if r == 70 && cc >= 4 && cc <= 9
                    if @ltv_data[cc-1].include?("<")
                      ltv_key = "0-"+@ltv_data[cc-1].tr('<= ','')
                    else
                      ltv_key = @ltv_data[cc-1]
                    end
                    @property_hash["MiscAdjuster/LTV"]["Escrow Waiver - except CA"][ltv_key] = {}
                    @property_hash["MiscAdjuster/LTV"]["Escrow Waiver - except CA"][ltv_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@property_hash,@state]
        create_adjust(adjustment,sheet)
      end
    end
    # create adjustment for each program
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  # def lp_open_access
  #   @programs_ids = []
  #   @xlsx.sheets.each do |sheet|
  #     if (sheet == "LP Open Access")
    # sheet_data = @xlsx.sheet(sheet)
  #       @adjustment_hash = {}
  #       @program_ids = []
  #       @fixed_data = []
  #       @sub_data = []
  #       @unit_data = []
  #       primary_key = ''
  #       secondry_key = ''
  #       ltv_key = ''
  #       cltv_key = ''
  #       unit_key = ''
  #       caps_key = ''
  #       term_key = ''
  #       max_key = ''
  #       fixed_key = ''
  #       sub_data = ''
  #       @sheet = sheet
  #       (1..61).each do |r|
  #         row = sheet_data.row(r)
  #         if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet")) || (row.include?("LP Open Access Super Conforming 10 Yr Fixed"))
  #           rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
  #           max_column_section = row.compact.count - 1
  #           (0..max_column_section).each do |max_column|
  #             cc = 3 + max_column*6 # (3 / 9 / 15)
  #             begin
  #               # title
  #               @title = sheet_data.cell(r,cc)

  #               # term
  #               term = nil
  #               program_heading = @title.split
  #               if @title.include?("10yr") || @title.include?("10 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("15yr") || @title.include?("15 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("20yr") || @title.include?("20 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("25yr") || @title.include?("25 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("30yr") || @title.include?("30 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               end

  #               # rate type
  #               if @title.include?("Fixed")
  #                 loan_type = "Fixed"
  #               elsif @title.include?("ARM")
  #                 loan_type = "ARM"
  #               elsif @title.include?("Floating")
  #                 loan_type = "Floating"
  #               elsif @title.include?("Variable")
  #                 loan_type = "Variable"
  #               else
  #                 loan_type = nil
  #               end

  #               # rate arm
  #               arm_basic = false
  #               if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM")
  #                 arm_basic = @title.scan(/\d+/)[0].to_i
  #               end

  #               # conforming
  #               conforming = false
  #               if @title.include?("Freddie Mac") || @title.include?("Fannie Mae") || @title.include?("Freddie Mac Home Possible") || @title.include?("Freddie Mac Home Ready")
  #                 conforming = true
  #               end

  #               # freddie_mac
  #               freddie_mac = false
  #               if @title.include?("Freddie Mac")
  #                 freddie_mac = true
  #               end

  #               # fannie_mae
  #               fannie_mae =false
  #               if @title.include?("Fannie Mae") || @title.include?("Freddie Mac Home Ready")
  #                 fannie_mae = true
  #               end

  #               @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
  #               @program_ids << @program.id
  #               # Loan Limit Type
  #               if @title.include?("Non-Conforming")
  #                 @program.loan_limit_type << "Non-Conforming"
  #               end
  #               if @title.include?("Conforming")
  #                 @program.loan_limit_type << "Conforming"
  #               end
  #               if @title.include?("Jumbo")
  #                 @program.loan_limit_type << "Jumbo"
  #               end
  #               if @title.include?("High Balance")
  #                 @program.loan_limit_type << "High Balance"
  #               end
  #               @program.save
  #               @program.update(term: term,loan_type: loan_type,conforming: conforming,freddie_mac: freddie_mac, fannie_mae: fannie_mae, arm_basic: arm_basic, loan_category: sheet)
  #               @program.adjustments.destroy_all
  #               @block_hash = {}
  #               key = ''
  #               # main_key = ''
  #               # if @program.term.present?
  #               #   main_key = "Term/LoanType/InterestRate/LockPeriod"
  #               # else
  #               #   main_key = "InterestRate/LockPeriod"
  #               # end
  #               # @block_hash[main_key] = {}
  #               (0..50).each do |max_row|
  #                 @data = []
  #                 (0..4).each_with_index do |index, c_i|
  #                   rrr = rr + max_row
  #                   ccc = cc + c_i
  #                   value = sheet_data.cell(rrr,ccc)
  #                   if (c_i == 0)
  #                     key = value
  #                     @block_hash[key] = {}
  #                   else
  #                     if @program.lock_period.length <= 3
  #                       @program.lock_period << 15*c_i
  #                       @program.save
  #                     end
  #                     @block_hash[key][15*c_i] = value
  #                   end
  #                   @data << value
  #                 end

  #                 if @data.compact.length == 0
  #                   break # terminate the loop
  #                 end
  #               end
  #               if @block_hash.values.first.keys.first.nil?
  #                 @block_hash.values.first.shift
  #               end
  #               @block_hash.delete(nil)
  #               @program.update(base_rate: @block_hash)
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #         end
  #       end

  #       # Adjustment
  #       (63..97).each do |r|
  #         row = sheet_data.row(r)
  #         @fixed_data = sheet_data.row(65)
  #         @sub_data = sheet_data.row(73)
  #         @unit_data = sheet_data.row(82)
  #         if row.compact.count >= 1
  #           (0..19).each do |max_column|
  #             cc = max_column
  #             begin
  #               value = sheet_data.cell(r,cc)

  #               if value.present?
  #                 if value == "Loan Level Price Adjustments: See Adjustment Caps" || value == "Adjustments Applied after Cap"
  #                   primary_key = value
  #                   @adjustment_hash[primary_key] = {}
  #                 end
  #                 if value == "All Fixed Conforming > 15yr Terms (All Occupancies)"
  #                   secondry_key = "LoanSize/LoanType/Term/FICO/LTV"
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end
  #                 if value == "Subordinate Financing"
  #                   secondry_key = "FinancingType/LTV/CLTV/FICO"
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end
  #                 if value == "Number Of Units"
  #                   secondry_key = "PropertyType/LTV"
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end
  #                 if value == 'Loan Size Adjustments'
  #                   secondry_key = "Loan Size Adjustments"
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end

  #                 # All fixed Adjustment
  #                 if r >= 66 && r <= 71 && cc == 8
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 66 && r <= 71 && cc > 8 && cc <= 19 && cc != 15
  #                   fixed_key = @fixed_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][fixed_key] = {}
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][fixed_key] = value
  #                 end

  #                 # Subordinate Adjustment
  #                 if r >= 74 && r <= 80 && cc == 5
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 74 && r <= 80 && cc == 6
  #                   cltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key] = {}
  #                 end
  #                 if r >= 74 && r <= 80 && cc >= 9 && cc <= 10
  #                   fixed_key = get_value @sub_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key][fixed_key] = {}
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key][fixed_key] = value
  #                 end

  #                 # Number of unit Adjustment
  #                 if r >= 83 && r <= 84 && cc == 3
  #                   unit_key = value
  #                   @adjustment_hash[primary_key][secondry_key][unit_key] = {}
  #                 end
  #                 if r >= 83 && r <= 84 && cc > 3 && cc <= 7
  #                   fixed_key = get_value @unit_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][unit_key][fixed_key] = {}
  #                   @adjustment_hash[primary_key][secondry_key][unit_key][fixed_key] = value
  #                 end

  #                 # Loan Size Adjustments
  #                 if r >= 87 && r <= 93 && cc == 6
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 87 && r <= 93 && cc == 10
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = value
  #                 end

  #                 # Other Adjustment
  #                 if r >= 95 && r <= 97 && cc == 3
  #                   ltv_key = value
  #                   @adjustment_hash[primary_key][ltv_key] = {}
  #                 end
  #                 if r >= 95 && r <= 97 && cc == 10
  #                   @adjustment_hash[primary_key][ltv_key] = value
  #                 end
  #               end
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #           (12..19).each do |max_column|
  #             cc = max_column
  #             begin
  #               value = sheet_data.cell(r,cc)
  #               if value.present?
  #                 if  value == "Misc Adjusters" || value == "Adjustment Caps"
  #                   @key = value
  #                   @adjustment_hash[primary_key][@key] = {}
  #                 end

  #                 # Misc Adjustment
  #                 if r >= 73 && r <= 80 && cc == 15
  #                   if value.include?("Condo")
  #                     cltv_key = "Condo=>75.01=>15.01"
  #                   else
  #                     cltv_key = value
  #                   end
  #                   @adjustment_hash[primary_key][@key][cltv_key] = {}
  #                 end
  #                 if r >= 73 && r <= 80 && cc == 19
  #                   @adjustment_hash[primary_key][@key][cltv_key] = value
  #                 end

  #                 # Adjustment Caps
  #                 if r > 86 && r <= 90 && cc == 16
  #                   caps_key = value
  #                   @adjustment_hash[primary_key][@key][caps_key] = {}
  #                 end
  #                 if r > 86 && r <= 90 && cc == 17
  #                   term_key = get_value value
  #                   @adjustment_hash[primary_key][@key][caps_key][term_key] = {}
  #                 end
  #                 if r > 86 && r <= 90 && cc == 18
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][@key][caps_key][term_key][ltv_key] = {}
  #                 end
  #                 if r > 86 && r <= 90 && cc == 19
  #                   @adjustment_hash[primary_key][@key][caps_key][term_key][ltv_key] = value
  #                 end


  #                 if r == 93 && cc == 12
  #                   max_key = value
  #                   @adjustment_hash[primary_key][max_key] = {}
  #                 end
  #                 if r == 93 && cc == 16
  #                   @adjustment_hash[primary_key][max_key] = value
  #                 end
  #               end
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #         end
  #       end
  #       make_adjust(@adjustment_hash, @program_ids)
  #       create_program_association_with_adjustment(@sheet)
  #     end
  #   end
  #   redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  # end

  def jumbo_series_f
    @xlsx.sheets.each do |sheet|
      if (sheet == "Jumbo Series_F")
        @sheet_name = sheet
        @adjustment_hash = {}
        @refinance_hash = {}
        @loan_amount = {}
        @state = {}
        @property_hash = {}
        primary_key = ''
        secondry_key = ''
        ltv_key = ''
        cltv_key = ''
        @sheet = sheet
        sheet_data = @xlsx.sheet(sheet)
        (2..36).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet"))
            # r == 7 / 35 / 55
            rr = r + 1 # (r == 8)/ (r == 23)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 6 + max_column*6 # (6 / 12 / 18)
              begin
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                # term
                if @title.include?("10yr") || @title.include?("10 Yr")
                  term = 10
                elsif @title.include?("15yr") || @title.include?("15 Yr")
                  term = 15
                elsif @title.include?("20yr") || @title.include?("20 Yr")
                  term = 20
                elsif @title.include?("25yr") || @title.include?("25 Yr")
                  term = 25
                elsif @title.include?("30yr") || @title.include?("30 Yr") 
                  term = 30
                end

                if @title.include?("20/25/30 Yr")
                  term = 2030
                elsif @title.include?("10/15 Yr")
                  term = 1015
                end

                # rate type
                if p_name.downcase.include?("fixed")
                  loan_type = "Fixed"
                elsif p_name.downcase.include?("arm")
                  loan_type = "ARM"
                  arm_benchmark = "LIBOR"
                  arm_margin = 0
                elsif p_name.include?("Floating")
                  loan_type = "Floating"
                elsif p_name.include?("Variable")
                  loan_type = "Variable"
                else
                  loan_type = "Fixed"
                end

                # rate arm
                if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM") || @title.include?("5/1 LIBOR ARM") || @title.include?("7/1 LIBOR ARM") || @title.include?("10/1 LIBOR ARM")
                  arm_basic = @title.scan(/\d+/)[0].to_i
                end

                # Arm Advanced
                if @title.downcase.include?("arm")
                  arm_advanced = @title.downcase.split("arm").last.tr('A-Za-z ','')
                  if arm_advanced.include?('/')
                    arm_advanced = arm_advanced.tr('/','-')
                  else
                    arm_advanced
                  end
                end

                # Loan Size
                if p_name.downcase.include?("jumbo")
                  loan_size = "Jumbo"
                else
                  loan_size = "Conforming"
                end

                # loan_purpose
                if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                  loan_purpose = "Refinance"
                else
                  loan_purpose = "Purchase"
                end

                # lp and du
                if p_name.downcase.include?('du ')
                  du = true
                end
                if p_name.downcase.include?('lp ')
                  lp = true
                end

                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @program.update(term: term,loan_type: loan_type,arm_basic: arm_basic, loan_category: @sheet_name,arm_advanced: arm_advanced, loan_size: loan_size, loan_purpose: loan_purpose, du: du, lp: lp, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                @block_hash = {}
                key = ''
                (0..50).each do |max_row|
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

                  if @data.compact.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil?
                  @block_hash.values.first.shift
                end
                @program.update(base_rate: @block_hash, loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        # Adjustments
        (55..94).each do |r|
          row = sheet_data.row(r)
          @cltv_data = sheet_data.row(60)
          @cltv_data2 = sheet_data.row(59)
          @max_price_data = sheet_data.row(94)
          if row.compact.count >= 1
            (3..25).each do |cc|
              value = sheet_data.cell(r,cc)
              begin
                if value.present?
                  if value == "Purchase Transactions"
                    @adjustment_hash["LoanPurpose/FICO/LTV"] = {}
                    @adjustment_hash["LoanPurpose/FICO/LTV"]["Purchase"] = {}
                    @state["State"] = {}
                  end
                  if value == "R/T Refinance Transactions"
                    @refinance_hash["RefinanceOption/FICO/LTV"] = {}
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Rate and Term"] = {}
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                  end
                  if value == "Loan Amount Adjustments"
                    @loan_amount["LoanAmount/LTV"] = {}
                  end
                  if value == "Feature Adjustments"
                    @property_hash["PropertyType/LTV"] = {}
                  end
                  # Loan Amount Adjustments
                  if r >= 60 && r <= 63 && cc == 15
                    if value.include?("≤")
                      ltv_key = "0-"+value.tr('A-Z≤ $ ','')+",000,000"
                    else
                      ltv_key = (value.tr('A-Z$ ','').split("-").first.to_f*1000000).to_s+"-"+(value.tr('A-Z$ ','').split("-").last.to_f*1000000).to_s
                    end
                    @loan_amount["LoanAmount/LTV"][ltv_key] = {}
                  end
                  if r >= 60 && r <= 63 && cc > 15 && cc <= 25
                    if @cltv_data2[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data2[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data2[cc-2]
                    end
                    @loan_amount["LoanAmount/LTV"][ltv_key][secondry_key] = {}
                    @loan_amount["LoanAmount/LTV"][ltv_key][secondry_key] = value
                  end
                  # Purchase Transactions Adjustment
                  if r >= 61 && r <= 65 && cc == 3
                    if value.include?("≥")
                      primary_key = value.tr('≥ ','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      primary_key = get_value value
                    end
                    @adjustment_hash["LoanPurpose/FICO/LTV"]["Purchase"][primary_key] = {}
                  end
                  if r >= 61 && r <= 65 && cc >3 && cc <= 13
                    if @cltv_data[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data[cc-2]
                    end
                    @adjustment_hash["LoanPurpose/FICO/LTV"]["Purchase"][primary_key][secondry_key] = {}
                    @adjustment_hash["LoanPurpose/FICO/LTV"]["Purchase"][primary_key][secondry_key] = value
                  end
                  # Feature Adjustments
                  if r >= 68 && r <= 73 && cc == 15
                    primary_key = value
                    @property_hash["PropertyType/LTV"][primary_key] = {}
                  end
                  if r >= 68 && r <= 73 && cc > 15 && cc <= 25
                    if @cltv_data2[cc-2].present? && @cltv_data2[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data2[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data2[cc-2]
                    end
                    @property_hash["PropertyType/LTV"][primary_key][secondry_key] = {}
                    @property_hash["PropertyType/LTV"][primary_key][secondry_key] = value
                  end
                  # R/T Refinance Transactions Adjustment
                  if r >= 69 && r <= 73 && cc == 3
                    if value.include?("≥")
                      primary_key = value.tr('≥ ','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      primary_key = get_value value
                    end
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Rate and Term"][primary_key] = {}
                  end
                  if r >= 69 && r <= 73 && cc >3 && cc <= 13
                    if @cltv_data[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data[cc-2]
                    end
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Rate and Term"][primary_key][secondry_key] = {}
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Rate and Term"][primary_key][secondry_key] = value
                  end
                  # # C/O Refinance Transactions Adjustment
                  if r >= 77 && r <= 81 && cc == 3
                    if value.include?("≥")
                      primary_key = value.tr('≥ ','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      primary_key = get_value value
                    end
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
                  end
                  if r >= 77 && r <= 81 && cc >3 && cc <= 13
                    if @cltv_data[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data[cc-2]
                    end
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][secondry_key] = {}
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][secondry_key] = value
                  end
                  # State Adjustments
                  if r == 86 && cc == 3
                    @state["State"]["FL"] = {}
                    @state["State"]["NV"] = {}
                  end
                  if r ==86 && cc >3 && cc <= 13
                    if @cltv_data[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data[cc-2]
                    end
                    @state["State"]["FL"][secondry_key] = {}
                    @state["State"]["NV"][secondry_key] = {}
                    @state["State"]["FL"][secondry_key] = value
                    @state["State"]["NV"][secondry_key] = value
                  end
                  if r == 87 && cc == 3
                    @state["State"]["CA"] = {}
                  end
                  if r ==87 && cc > 3 && cc <= 13
                    if @cltv_data[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data[cc-2]
                    end
                    @state["State"]["CA"][secondry_key] = {}
                    @state["State"]["CA"][secondry_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@refinance_hash,@loan_amount,@state,@property_hash]
        create_adjust(adjustment,sheet)
      end
    end
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  # def du_refi_plus_arms
  #   @programs_ids = []
  #   @xlsx.sheets.each do |sheet|
  #     if (sheet == "Du Refi Plus ARMs")
    # sheet_data = @xlsx.sheet(sheet)
  #       @adjustment_hash = {}
  #       @program_ids = []
  #       @fixed_data = []
  #       @sub_data = []
  #       primary_key = ''
  #       secondry_key = ''
  #       fixed_key = ''
  #       ltv_key = ''
  #       cltv_key = ''
  #       sub_data = ''
  #       misc_key = ''
  #       adj_key = ''
  #       term_key = ''
  #       @sheet = sheet
  #       (1..35).each do |r|
  #         row = sheet_data.row(r)
  #         if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet"))
  #           rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
  #           max_column_section = row.compact.count - 1
  #           (0..max_column_section).each do |max_column|
  #             cc = 3 + max_column*6 # (3 / 9 / 15)
  #             begin
  #               # title
  #               @title = sheet_data.cell(r,cc)

  #               # term
  #               term = nil
  #               program_heading = @title.split
  #               if @title.include?("10yr") || @title.include?("10 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("15yr") || @title.include?("15 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("20yr") || @title.include?("20 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("25yr") || @title.include?("25 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("30yr") || @title.include?("30 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               end

  #               # rate type
  #               if @title.include?("Fixed")
  #                 loan_type = "Fixed"
  #               elsif @title.include?("ARM")
  #                 loan_type = "ARM"
  #               elsif @title.include?("Floating")
  #                 loan_type = "Floating"
  #               elsif @title.include?("Variable")
  #                 loan_type = "Variable"
  #               else
  #                 loan_type = nil
  #               end

  #               # rate arm
  #               arm_basic = false
  #               if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM")
  #                 arm_basic = @title.scan(/\d+/)[0].to_i
  #               end

  #               # conforming
  #               conforming = false
  #               if @title.include?("Freddie Mac") || @title.include?("Fannie Mae") || @title.include?("Freddie Mac Home Possible") || @title.include?("Freddie Mac Home Ready")
  #                 conforming = true
  #               end

  #               # freddie_mac
  #               freddie_mac = false
  #               if @title.include?("Freddie Mac")
  #                 freddie_mac = true
  #               end

  #               # fannie_mae
  #               fannie_mae = false
  #               if @title.include?("Fannie Mae") || @title.include?("Freddie Mac Home Ready")
  #                 fannie_mae = true
  #               end

  #               # High Balance
  #               if @title.include?("High Balance")
  #                 jumbo_high_balance = true
  #               end

  #               @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
  #               @program_ids << @program.id
  #               # Loan Limit Type
  #               if @title.include?("Non-Conforming")
  #                 @program.loan_limit_type << "Non-Conforming"
  #               end
  #               if @title.include?("Conforming")
  #                 @program.loan_limit_type << "Conforming"
  #               end
  #               if @title.include?("Jumbo")
  #                 @program.loan_limit_type << "Jumbo"
  #               end
  #               if @title.include?("High Balance")
  #                 @program.loan_limit_type << "High Balance"
  #               end
  #               @program.save
  #               @program.update(term: term,loan_type: loan_type,conforming: conforming,freddie_mac: freddie_mac, fannie_mae: fannie_mae, arm_basic: arm_basic, loan_category: sheet, jumbo_high_balance: jumbo_high_balance)
  #               @program.adjustments.destroy_all
  #               @block_hash = {}
  #               key = ''
  #               # main_key = ''
  #               # if @program.term.present?
  #               #   main_key = "Term/LoanType/InterestRate/LockPeriod"
  #               # else
  #               #   main_key = "InterestRate/LockPeriod"
  #               # end
  #               # @block_hash[main_key] = {}
  #               (0..50).each do |max_row|
  #                 @data = []
  #                 (0..4).each_with_index do |index, c_i|
  #                   rrr = rr + max_row
  #                   ccc = cc + c_i
  #                   value = sheet_data.cell(rrr,ccc)
  #                   if (c_i == 0)
  #                     key = value
  #                     @block_hash[key] = {}
  #                   else
  #                     if @program.lock_period.length <= 3
  #                       @program.lock_period << 15*c_i
  #                       @program.save
  #                     end
  #                     @block_hash[key][15*c_i] = value
  #                   end
  #                   @data << value
  #                 end

  #                 if @data.compact.length == 0
  #                   break # terminate the loop
  #                 end
  #               end
  #               if @block_hash.values.first.keys.first.nil?
  #                 @block_hash.values.first.shift
  #               end
  #               @block_hash.delete(nil)
  #               @program.update(base_rate: @block_hash)
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #         end
  #       end
  #       # Adjustments
  #       (37..70).each do |r|
  #         row = sheet_data.row(r)
  #         @fixed_data = sheet_data.row(39)
  #         @sub_data = sheet_data.row(49)
  #         if row.compact.count >= 1
  #           (3..19).each do |max_column|
  #             cc = max_column
  #             value = sheet_data.cell(r,cc)
  #             begin
  #               if value.present?
  #                 if value == "Loan Level Price Adjustments: See Adjustment Caps" || value == "Adjustments Applied after Cap"
  #                   primary_key = value
  #                   @adjustment_hash[primary_key] = {}
  #                 end
  #                 if value == "All DU Refi Plus Conforming ARMs (All Occupancies)" || value == "Subordinate Financing" || value == "Loan Size Adjustments"
  #                   secondry_key = value
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end

  #                 # All du refi plus Adjustment
  #                 if r >= 40 && r <= 47 && cc == 8
  #                   fixed_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][fixed_key] = {}
  #                 end
  #                 if r >= 40 && r <= 47 && cc >8 && cc <= 19
  #                   fixed_data = get_value @fixed_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][fixed_key][fixed_data] = value
  #                 end

  #                 # Subordinate Financing Adjustment
  #                 if r >= 50 && r <= 54 && cc == 5
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 50 && r <= 54 && cc == 6
  #                   cltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key] = {}
  #                 end
  #                 if r >= 50 && r <= 54 && cc > 6 && cc <= 10
  #                   sub_data = get_value @sub_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key][sub_data] = value
  #                 end

  #                 # Other Adjustment
  #                 if r >= 56 && r <= 57 && cc == 3
  #                   ltv_key = value
  #                   @adjustment_hash[primary_key][ltv_key] = {}
  #                 end
  #                 if r >= 56 && r <= 57 && cc == 8
  #                   @adjustment_hash[primary_key][ltv_key] = value
  #                 end

  #                 # Adjustments Applied after Cap
  #                 if r >= 60 && r <= 66 && cc == 6
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 60 && r <= 66 && cc > 6 && cc <= 10
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = value
  #                 end

  #                 # Other Adjustment
  #                 if r >= 69 && r <= 70 && cc == 3
  #                   ltv_key = value
  #                   @adjustment_hash[primary_key][ltv_key] = {}
  #                 end
  #                 if r >= 69 && r <= 70 && cc == 10
  #                   @adjustment_hash[primary_key][ltv_key] = value
  #                 end
  #               end
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #           (12..19).each do |max_column|
  #             cc = max_column
  #             value = sheet_data.cell(r,cc)
  #             begin
  #               if value.present?
  #                 if value == "Misc Adjusters" || value == "Adjustment Caps"
  #                   misc_key = value
  #                   @adjustment_hash[misc_key] = {}
  #                 end

  #                 # Misc Adjustments
  #                 if r >= 49 && r <= 58 && cc == 15
  #                   if value.include?("Condo")
  #                     adj_key = "Condo/75"
  #                   else
  #                     adj_key = value
  #                   end
  #                   @adjustment_hash[misc_key][adj_key] = {}
  #                 end
  #                 if r >= 49 && r <= 58 && cc == 19
  #                   @adjustment_hash[misc_key][adj_key] = value
  #                 end

  #                 # Adjustment Caps
  #                 if r >= 62 && r <= 64 && cc == 16
  #                   adj_key = value
  #                   @adjustment_hash[misc_key][adj_key] = {}
  #                 end
  #                 if r >= 62 && r <= 64 && cc == 17
  #                   term_key = get_value value
  #                   @adjustment_hash[misc_key][adj_key][term_key] = {}
  #                 end
  #                 if r >= 62 && r <= 64 && cc == 18
  #                   ltv_key = get_value value
  #                   @adjustment_hash[misc_key][adj_key][term_key][ltv_key] = {}
  #                 end
  #                 if r >= 62 && r <= 64 && cc == 19
  #                   @adjustment_hash[misc_key][adj_key][term_key][ltv_key] = value
  #                 end
  #               end
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #         end
  #       end
  #       make_adjust(@adjustment_hash, @sheet)
  #       create_program_association_with_adjustment(@sheet)
  #     end
  #   end
  #   redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  # end

  def jumbo_series_h
    @program_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "Jumbo Series_H")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @sheet = sheet
        (2..86).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("Jumbo Series H Product and Pricing"))
            # r == 7 / 35 / 55
            rr = r + 1 # (r == 8)/ (r == 28)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4 + max_column*6 # (4 / 10 / 16/ 22)
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  p_name = @title + " " + sheet
                  program_heading = @title.split
                  # term
                  term = nil
                  program_heading = @title.split
                  if @title.include?("10yr") || @title.include?("10 Yr")
                    term = 10
                  elsif @title.include?("15yr") || @title.include?("15 Yr")
                    term = 15
                  elsif @title.include?("20yr") || @title.include?("20 Yr")
                    term = 20
                  elsif @title.include?("25yr") || @title.include?("25 Yr")
                    term = 25
                  elsif @title.include?("30yr") || @title.include?("30 Yr")
                    term = 30
                  end

                  # rate type
                  if p_name.downcase.include?("fixed")
                    loan_type = "Fixed"
                  elsif p_name.downcase.include?("arm")
                    loan_type = "ARM"
                    arm_benchmark = "LIBOR"
                    arm_margin = 0
                  elsif p_name.include?("Floating")
                    loan_type = "Floating"
                  elsif p_name.include?("Variable")
                    loan_type = "Variable"
                  else
                    loan_type = "Fixed"
                  end

                  # rate arm
                  if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM") || @title.include?("5/1 Yr ARM") || @title.include?("7/1 Yr ARM") || @title.include?("10/1 Yr ARM")
                    arm_basic = @title.scan(/\d+/)[0].to_i
                  end

                  # Arm Advanced
                  if @title.downcase.include?("arm")
                    arm_advanced = @title.downcase.split("arm").last.tr('A-Za-z- ','')
                    if arm_advanced.include?('/')
                      arm_advanced = arm_advanced.tr('/','-')
                    else
                      arm_advanced
                    end
                  end

                  # freddie_mac
                  freddie_mac = false
                  if p_name.include?("Freddie Mac")
                    freddie_mac = true
                  end

                  # fannie_mae
                  fannie_mae = false
                  if p_name.include?("Fannie Mae") || p_name.include?("Freddie Mac Home Ready")
                    fannie_mae = true
                  end

                  # High Balance
                  if p_name.downcase.include?("jumbo")
                    loan_size = "Jumbo"
                  else
                    loan_size = "Conforming"
                  end

                  # Purchase & Refinance
                  # loan_purpose
                  if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                    loan_purpose = "Refinance"
                  else
                    loan_purpose = "Purchase"
                  end
                  # lp and du
                  if p_name.downcase.include?('du ')
                    du = true
                  end
                  if p_name.downcase.include?('lp ')
                    lp = true
                  end
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @program_ids << @program.id
                  @program.update(term: term,loan_type: loan_type,loan_purpose: loan_purpose ,arm_basic: arm_basic, loan_category: @sheet_name,arm_advanced: arm_advanced,loan_size: loan_size, du: du, lp: lp, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                  @program.adjustments.destroy_all

                  @block_hash = {}
                  key = ''
                  (0..50).each do |max_row|
                    @data = []
                    (0..4).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      else
                        if @program.lock_period.length <= 3
                          @program.lock_period << 15*c_i
                          @program.save
                        end
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end

                    if @data.compact.length == 0
                      break # terminate the loop
                    end
                  end
                  if @block_hash.values.first.keys.first.nil?
                    @block_hash.values.first.shift
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        #For Adjustments
        @xlsx.sheet(sheet).each_with_index do |sheet_row, index|
          index = index+ 1
          if sheet_row.include?("Jumbo Series H - Adjustments")
            (index..@xlsx.sheet(sheet).last_row).each do |adj_row|
              # First Adjustment
              if @xlsx.sheet(sheet).row(adj_row).include?("State Adjustments")
                key_array = ""
                rr = adj_row
                cc = 12
                @state_hash = {}
                loan_amount_hash = nil
                main_key = "State"
                @state_hash[main_key] = {}
                @right_adj = {}
                key = ''
                (1..11).each do |max_row|
                  column_count = 1
                  rrr = rr + max_row
                  row = @xlsx.sheet(sheet).row(rrr)
                  if row.include?("State")
                    key_array = row.compact[5..12]
                  end
                  (12..20).each do |max_column|
                    ccc = max_column
                    begin
                      value = @xlsx.sheet(sheet).cell(rrr,ccc)
                      if !(row.include?("State"))
                        if (ccc == 12)
                          key = value
                          loan_amount_hash = {
                            "Fixed" => {
                              13 => "30",
                              14 => "20",
                              16 => "15",
                              17 => "10"
                            },
                            "ARM" => {
                              18 => "10/1",
                              19 => "7/1",
                              20 => "5/1"
                            }
                          }
                          @state_hash[main_key][key] = {}
                          @state_hash[main_key][key]["LoanType/Term"] = {}
                          @state_hash[main_key][key]["LoanType/Term"]["Fixed"] = {}
                          @state_hash[main_key][key]["LoanType/Term"]["ARM"] = {}
                        else
                          if ccc != 15 && value != nil
                            row_diff = rrr-71
                            arr = sheet_data.cell((rrr - row_diff),ccc)
                            if arr.include?('Fixed')
                              @state_hash[main_key][key]["LoanType/Term"]["Fixed"][loan_amount_hash["Fixed"][ccc]] = value
                            elsif arr.include?('ARM')
                              @state_hash[main_key][key]["LoanType/Term"]["ARM"][loan_amount_hash["ARM"][ccc]] = value
                            end
                            column_count = column_count + 1
                          end
                          column_count = column_count + 1
                        end
                      end
                    rescue Exception => e
                      error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: @sheet_name, error_detail: e.message)
                      error_log.save
                    end
                  end
                end

                # make_adjust(@state_hash, @program_ids)
              end

              # Second Adjustment
              if @xlsx.sheet(sheet).row(adj_row).include?("Credit Score")
                begin
                  key_array = []
                  rr = adj_row
                  cc = 12
                  @credit_score = {}
                  main_key = "FICO/CLTV"
                  @credit_score[main_key] = {}
                  (1..7).each do |max_row|
                    column_count = 0
                    rrr = rr + max_row
                    row = @xlsx.sheet(sheet).row(rrr)
                    if row.include?("CLTV -->")
                      row.compact[5..9].each do |row_val|
                        val = row_val.split
                        if val.include?("≤") && !val.include?("CLTV")
                          key_array << set_range(row_val) || get_value(row_val)
                        elsif !val.include?("CLTV")
                          key_array << row_val
                        end
                      end
                    end
                  end

                  (0..5).each do |max_column|
                    ccc = cc + max_column
                    begin
                      value = @xlsx.sheet(sheet).cell(rrr,ccc)
                      if !row.include?("CLTV -->")
                        if ccc == 12
                          key = value
                          key = set_range(value) || get_value(value) if value.include?('+')
                          @credit_score[main_key][key] = {}
                        else
                          @credit_score[main_key][key][key_array[column_count]] = value if value != nil
                          column_count = column_count + 1 if value != nil
                        end
                      end
                    rescue Exception => e
                      error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: ccc, loan_category: @sheet_name, error_detail: e.message)
                      error_log.save
                    end
                  end
                end
                # make_adjust(@credit_score, @program_ids)
              end

              # Third Adjustment
              if @xlsx.sheet(sheet).row(adj_row).include?("Other Adjustments")
                rr = adj_row
                cc = 13

                (1..2).each do |max_row|
                  rrr = rr + max_row
                  begin
                  row = @xlsx.sheet(sheet).row(rrr)

                  if row.include?("Loan Amount >=$1MM")
                    @loan_amount = {}
                    main_key = "LoanAmount"
                    @loan_amount[main_key] = {}
                    key = 1000000 if @xlsx.sheet(sheet).cell(rrr,cc).split[2].include?(">")
                    value = @xlsx.sheet(sheet).cell(rrr,cc+4)

                    @loan_amount[main_key][key] = {}
                    @loan_amount[main_key][key] = value
                    # make_adjust(@loan_amount, @program_ids)
                  end

                  if row.include?("Second Home")
                    @second_home = {}
                    main_key = "PropertyType"
                    @second_home[main_key] = {}

                    key = "2nd Home" if @xlsx.sheet(sheet).cell(rrr,cc).include?("Second Home")
                    value = @xlsx.sheet(sheet).cell(rrr,cc+4)

                    @second_home[main_key][key] = {}
                    @second_home[main_key][key] = value
                    # make_adjust(@second_home, @program_ids)
                  end
                  rescue Exception => e
                    error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
                    error_log.save
                  end
                end
              end

              # Fourth Adjustment
              if @xlsx.sheet(sheet).row(adj_row).include?("Cash Out Refi")
                if adj_row == 95
                  rr = adj_row
                  cc = 15
                  begin
                    @data_hash = {}
                    main_key = "LoanPurpose/RefinanceOption/LTV"
                    key = "Purpose"
                    key1 = "Cash Out"
                    @data_hash[main_key] = {}
                    @data_hash[main_key][key] = {}
                    @data_hash[main_key][key][key1] = {}

                    (0..2).each do |max_row|
                      rrr = rr + max_row
                      row = @xlsx.sheet(sheet).row(rrr)
                      cell_value = @xlsx.sheet(sheet).cell(rrr,cc)
                      if cell_value.include?('LTV')
                        cell_value = cell_value.gsub('LTV', '')
                        key2 = set_range(cell_value)
                      else
                        key2 = get_value(cell_value)
                      end
                      value = @xlsx.sheet(sheet).cell(rrr,cc+2)

                      @data_hash[main_key][key][key1][key2] = {}
                      @data_hash[main_key][key][key1][key2] = value

                    end
                    # make_adjust(@data_hash, @program_ids)
                  rescue Exception => e
                    error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
                    error_log.save
                  end
                end
              end
            end
          end
        end
        adjustment = [@state_hash,@credit_score,@second_home,@data_hash,@loan_amount]
        create_adjust(adjustment,sheet)
        create_program_association_with_adjustment(@sheet)
      end
    end
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  # def du_refi_plus_fixed_rate_105
  #   @program_ids = []
  #   @xlsx.sheets.each do |sheet|
  #     if (sheet == "Du Refi Plus Fixed Rate_105")
    # sheet_data = @xlsx.sheet(sheet)
  #       @sheet = sheet
  #       (1..61).each do |r|
  #         row = sheet_data.row(r)
  #         if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet")) || (row.include?("DU Refi Plus 10yr Fixed >125 LTV"))
  #           rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
  #           max_column_section = row.compact.count - 1
  #           (0..max_column_section).each do |max_column|
  #             cc = 3 + max_column*6 # (3 / 9 / 15)
  #             begin
  #               # title
  #               @title = sheet_data.cell(r,cc)

  #               # term
  #               term = nil
  #               program_heading = @title.split
  #               if @title.include?("10yr") || @title.include?("10 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("15yr") || @title.include?("15 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("20yr") || @title.include?("20 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("25yr") || @title.include?("25 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("30yr") || @title.include?("30 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               end

  #               # rate type
  #               if @title.include?("Fixed")
  #                 loan_type = "Fixed"
  #               elsif @title.include?("ARM")
  #                 loan_type = "ARM"
  #               elsif @title.include?("Floating")
  #                 loan_type = "Floating"
  #               elsif @title.include?("Variable")
  #                 loan_type = "Variable"
  #               else
  #                 loan_type = nil
  #               end

  #               # rate arm
  #               if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM")
  #                 arm_basic = @title.scan(/\d+/)[0].to_i
  #               end

  #               # conforming
  #               conforming = false
  #               if @title.include?("Freddie Mac") || @title.include?("Fannie Mae") || @title.include?("Freddie Mac Home Possible") || @title.include?("Freddie Mac Home Ready")
  #                 conforming = true
  #               end

  #               # freddie_mac
  #               freddie_mac = false
  #               if @title.include?("Freddie Mac")
  #                 freddie_mac = true
  #               end

  #               # fannie_mae
  #               fannie_mae = false
  #               if @title.include?("Fannie Mae") || @title.include?("Freddie Mac Home Ready")
  #                 fannie_mae = true
  #               end

  #               @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
  #               @program_ids << @program.id
  #               # Loan Limit Type
  #               if @title.include?("Non-Conforming")
  #                 @program.loan_limit_type << "Non-Conforming"
  #               end
  #               if @title.include?("Conforming")
  #                 @program.loan_limit_type << "Conforming"
  #               end
  #               if @title.include?("Jumbo")
  #                 @program.loan_limit_type << "Jumbo"
  #               end
  #               if @title.include?("High Balance")
  #                 @program.loan_limit_type << "High Balance"
  #               end
  #               @program.save
  #               @program.update(term: term,loan_type: loan_type,conforming: conforming,freddie_mac: freddie_mac, fannie_mae: fannie_mae, arm_basic: arm_basic, loan_category: sheet)
  #               @program.adjustments.destroy_all
  #               @block_hash = {}
  #               key = ''
  #               main_key = ''
  #               if @program.term.present?
  #                 main_key = "Term/LoanType/InterestRate/LockPeriod"
  #               else
  #                 main_key = "InterestRate/LockPeriod"
  #               end
  #               @block_hash[main_key] = {}
  #               (0..50).each do |max_row|
  #                 @data = []
  #                 (0..4).each_with_index do |index, c_i|
  #                   rrr = rr + max_row
  #                   ccc = cc + c_i
  #                   value = sheet_data.cell(rrr,ccc)
  #                   if (c_i == 0)
  #                     key = value
  #                     @block_hash[main_key][key] = {}
  #                   else
  #                     if @program.lock_period.length <= 3
  #                       @program.lock_period << 15*c_i
  #                       @program.save
  #                     end
  #                     @block_hash[main_key][key][15*c_i] = value
  #                   end
  #                   @data << value
  #                 end

  #                 if @data.compact.length == 0
  #                   break # terminate the loop
  #                 end
  #               end
  #               if @block_hash.values.first.keys.first.nil?
  #                 @block_hash.values.first.shift
  #               end
  #               @program.update(base_rate: @block_hash)
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #         end
  #       end

  #       #For Adjustments
  #       @xlsx.sheet(sheet).each_with_index do |sheet_row, index|
  #         index = index+ 1
  #         if sheet_row.include?("Loan Level Price Adjustments: See Adjustment Caps")
  #           (index..@xlsx.sheet(sheet).last_row).each do |adj_row|
  #             # First Adjustment
  #             if adj_row == 65
  #               key = ''
  #               key_array = []
  #               rr = adj_row
  #               cc = 3
  #               @occupancy_hash = {}
  #               main_key = "All Occupancies"
  #               @occupancy_hash[main_key] = {}

  #               (0..2).each do |max_row|
  #                 column_count = 0
  #                 rrr = rr + max_row
  #                 row = @xlsx.sheet(sheet).row(rrr)

  #                 if rrr == rr
  #                   row.compact.each do |row_val|
  #                     val = row_val.split
  #                     if val.include?("<")
  #                       key_array << 0
  #                     else
  #                       key_array << row_val.split("-")[0].to_i.round if row_val.include?("-")
  #                       key_array << row_val.split[1].to_i.round if row_val.include?(">")
  #                     end
  #                   end
  #                 end

  #                 (0..16).each do |max_column|
  #                   ccc = cc + max_column
  #                   begin
  #                     value = @xlsx.sheet(sheet).cell(rrr,ccc)
  #                     if row.include?("All Occupancies > 15 Yr Terms")
  #                       if value != nil && value.to_s.include?(">") && value != "All Occupancies > 15 Yr Terms" && !value.is_a?(Numeric)
  #                         key = value.gsub(/[^0-9A-Za-z]/, '')
  #                         @occupancy_hash[main_key][key] = {}
  #                       elsif (value != nil) && !value.is_a?(String)
  #                         @occupancy_hash[main_key][key][key_array[column_count]] = value
  #                         column_count = column_count + 1
  #                       end
  #                     end
  #                   rescue Exception => e
  #                     error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
  #                     error_log.save
  #                   end
  #                 end
  #               end
  #               make_adjust(@occupancy_hash, @program_ids)
  #             end

  #             # Second Adjustment(Adjustment Caps)
  #             if adj_row == 86
  #               key_array = ""
  #               rr = adj_row
  #               cc = 16
  #               @adjustment_cap = {}
  #               main_key = "Adjustment Caps"
  #               @adjustment_cap[main_key] = {}
  #               key = ''

  #               (0..4).each do |max_row|
  #                 column_count = 1
  #                 rrr = rr + max_row
  #                 row = @xlsx.sheet(sheet).row(rrr)
  #                 if rrr == 86
  #                   key_array = row.compact
  #                 end

  #                 (0..3).each do |max_column|
  #                   ccc = cc + max_column
  #                   begin
  #                     value = @xlsx.sheet(sheet).cell(rrr,ccc)
  #                     if ccc == 16
  #                       key = value if value != nil
  #                       @adjustment_cap[main_key][key] = {} if value != nil
  #                     else
  #                       if !key_array.include?(value)
  #                         @adjustment_cap[main_key][key][key_array[column_count]] = value if value != nil
  #                         column_count = column_count + 1 if value != nil
  #                       end
  #                     end
  #                   rescue Exception => e
  #                     error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #                     error_log.save
  #                   end
  #                 end
  #               end
  #               make_adjust(@adjustment_cap, @program_ids)
  #             end

  #             # Third Adjustment
  #             if @xlsx.sheet(sheet).row(adj_row).include?("Max YSP")
  #               rr = adj_row
  #               cc = 4
  #               begin
  #                 @max_ysp_hash = {}
  #                 main_key = "Max YSP"
  #                 @max_ysp_hash[main_key] = {}
  #                 row = @xlsx.sheet(sheet).row(rr)
  #                 @max_ysp_hash[main_key] = row.compact[5]
  #                 make_adjust(@max_ysp_hash, @program_ids)
  #               rescue Exception => e
  #                 error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
  #                 error_log.save
  #               end
  #             end

  #             # Fourth Adjustment (Adjustments Applied after Cap)
  #             if @xlsx.sheet(sheet).row(adj_row).include?("Loan Size Adjustments")
  #               rr = adj_row
  #               cc = 6
  #               @loan_size = {}
  #               main_key = "Loan Size / Loan Type"
  #               @loan_size[main_key] = {}

  #               (0..6).each do |max_row|
  #                 @data = []
  #                 rrr = rr + max_row
  #                 ccc = cc
  #                 begin
  #                   key = @xlsx.sheet(sheet).cell(rrr,ccc)
  #                   if key.present?

  #                     if (key.include?("<"))
  #                       key = 0
  #                     elsif (key.include?("-"))
  #                       key = key.split("-").first.tr("^0-9", '')
  #                     else
  #                       key
  #                     end
  #                     value = @xlsx.sheet(sheet).cell(rrr,ccc+4)
  #                     raise "value is nil at row = #{rrr} and column = #{ccc}" unless value || key
  #                     @loan_size[main_key][key] = value
  #                   end
  #                 rescue Exception => e
  #                   error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
  #                   error_log.save
  #                 end
  #               end
  #               make_adjust(@loan_size, @program_ids)
  #             end

  #             # Fifth Adjustment(Misc Adjusters)
  #             if @xlsx.sheet(sheet).row(adj_row).include?("Adjustments Applied after Cap")
  #               rr = adj_row
  #               cc = 15
  #               @cando_hash = {}
  #               main_key = "PropertyType/LTV/Term"
  #               @cando_hash[main_key] = {}

  #               (0..6).each do |max_row|
  #                 @data = []
  #                 rrr = rr + max_row
  #                 ccc = cc
  #                 begin
  #                   key = @xlsx.sheet(sheet).cell(rrr,ccc)

  #                   if key.include?("Condo")
  #                     val = key.split
  #                     key1 = "Condo"
  #                     key2 = val[1].gsub(/[^0-9A-Za-z]/, '')
  #                     key3 = val[3].gsub(/[^0-9A-Za-z]/, '').split("yr")[0]
  #                     value = @xlsx.sheet(sheet).cell(rrr,ccc+4)
  #                     @cando_hash[main_key][key1] = {}
  #                     @cando_hash[main_key][key1][key2] = {}
  #                     @cando_hash[main_key][key1][key2][key3] = value
  #                   end

  #                   if key == "Manufactured Home"
  #                     key1 = "Manufactured Home"
  #                     key2 = 0
  #                     value = @xlsx.sheet(sheet).cell(rrr,ccc+4)
  #                     @cando_hash[main_key][key1] = {}
  #                     @cando_hash[main_key][key1][key2] = {}
  #                     @cando_hash[main_key][key1][key2] = value
  #                   end
  #                 rescue Exception => e
  #                   error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
  #                   error_log.save
  #                 end
  #               end
  #               make_adjust(@cando_hash, @program_ids)
  #             end

  #             # Sixth Adjustment(Misc Adjusters (2-4 Units))
  #             if @xlsx.sheet(sheet).row(adj_row).include?("Adjustments Applied after Cap")
  #                 rr = adj_row
  #                 cc = 15
  #               begin
  #                 @unit_hash = {}
  #                 main_key = "PropertyType/LTV"
  #                 @unit_hash[main_key] = {}

  #                 rrr = rr + 1
  #                 ccc = cc
  #                 key = @xlsx.sheet(sheet).cell(rrr,ccc)

  #                 if key.include?("Units")
  #                   key1 = "2-4 unit"
  #                   value = @xlsx.sheet(sheet).cell(rrr,ccc+4)
  #                   @unit_hash[main_key][key1] = {}
  #                   @unit_hash[main_key][key1] = value
  #                 end
  #                 make_adjust(@unit_hash, @program_ids)
  #               rescue Exception => e
  #                 error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
  #                 error_log.save
  #               end
  #             end


  #             # Seventh Adjustment(Misc Adjusters)
  #             if @xlsx.sheet(sheet).row(adj_row).include?("Adjustments Applied after Cap")
  #               rr = adj_row
  #               cc = 15
  #               begin
  #                 @data_hash = {}
  #                 main_key = "MiscAdjuster"
  #                 @data_hash[main_key] = {}

  #                 (0..2).each do |max_row|
  #                   rrr = rr + max_row
  #                   ccc = cc
  #                   key = @xlsx.sheet(sheet).cell(rrr,ccc)

  #                   if !key.include?("Units")
  #                     key1 = key.include?(">") ? key.split(" >")[0] : key
  #                     value = @xlsx.sheet(sheet).cell(rrr,ccc+4)
  #                     @data_hash[main_key][key1] = {}
  #                     @data_hash[main_key][key1] = value
  #                   end
  #                 end
  #                 make_adjust(@data_hash, @program_ids)
  #               rescue Exception => e
  #                 error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
  #                 error_log.save
  #               end
  #             end

  #             # LTV Adjustment(Misc Adjusters)
  #             if @xlsx.sheet(sheet).row(adj_row).include?("Adjustments Applied after Cap")
  #               rr = adj_row
  #               cc = 15
  #               @ltv_hash = {}
  #               main_key = "LTV"
  #               @ltv_hash[main_key] = {}

  #               (0..6).each do |max_row|
  #                 rrr = rr + max_row
  #                 ccc = cc
  #                 begin
  #                   key = @xlsx.sheet(sheet).cell(rrr,ccc)

  #                   if key.include?("LTV") && !key.include?("Condo")
  #                     key1 = key.split[1].to_i.round
  #                     key2 = key.include?("<") ? 0 : 30
  #                     value = @xlsx.sheet(sheet).cell(rrr,ccc+4)
  #                     @ltv_hash[main_key][key1] = {} if @ltv_hash[main_key] == {}
  #                     @ltv_hash[main_key][key1][key2] = {}
  #                     @ltv_hash[main_key][key1][key2] = value
  #                   end
  #                 rescue Exception => e
  #                   error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
  #                   error_log.save
  #                 end
  #               end
  #               make_adjust(@ltv_hash, @program_ids)
  #             end

  #             # CA Escrow Waiver Adjustment
  #             if @xlsx.sheet(sheet).row(adj_row).include?("Expanded Approval **")
  #               rr = adj_row
  #               cc = 3
  #               begin
  #                 @misc_adjuster = {}
  #                 main_key = "MiscAdjuster"
  #                 @misc_adjuster[main_key] = {}

  #                 (0..2).each do |max_row|
  #                   rrr = rr + max_row
  #                   ccc = cc
  #                   key = @xlsx.sheet(sheet).cell(rrr,ccc)

  #                   if key.include?("CA Escrow Waiver") || key.include?("Expanded Approval **")
  #                     value = @xlsx.sheet(sheet).cell(rrr,ccc+7)
  #                     @misc_adjuster[main_key][key] = {}
  #                     @misc_adjuster[main_key][key] = value
  #                   end
  #                 end
  #                 make_adjust(@misc_adjuster, @program_ids)
  #               rescue Exception => e
  #                 error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rrr, column: ccc, loan_category: sheet, error_detail: e.message)
  #                 error_log.save
  #               end
  #             end

  #             # Subordinate Financing Adjustment
  #             if @xlsx.sheet(sheet).row(adj_row).include?("Subordinate Financing")
  #               rr = adj_row
  #               cc = 6
  #               begin
  #                 @subordinate_hash = {}
  #                 main_key = "FinancingType/LTV/CLTV/FICO"
  #                 key1 = "Subordinate Financing"

  #                 sub_key1 = row.compact[2].include?("<") ? 0 : row.compact[2].split(" ")[1].to_i
  #                 sub_key2 = row.compact[3].include?(">") ? row.compact[3].split(" ")[1].to_i : row.compact[3].to_i

  #                 @subordinate_hash[main_key] = {}
  #                 @subordinate_hash[main_key][key1] = {}

  #                 (1..2).each do |max_row|
  #                   rrr = rr + max_row
  #                   ccc = cc
  #                   key = @xlsx.sheet(sheet).cell(rrr,ccc)

  #                   if key.include?(">") || key == "ALL"
  #                     key2 = (key.include?(">")) ? key.gsub(/[^0-9A-Za-z]/, '') : key
  #                     value = @xlsx.sheet(sheet).cell(rrr,ccc+3)
  #                     value1 = @xlsx.sheet(sheet).cell(rrr,ccc+4)

  #                     @subordinate_hash[main_key][key1][key2] ={}
  #                     @subordinate_hash[main_key][key1][key2][sub_key1] = value
  #                     @subordinate_hash[main_key][key1][key2][sub_key2] = value1
  #                   end
  #                 end
  #                 make_adjust(@subordinate_hash, @program_ids)
  #               rescue Exception => e
  #                 error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: sheet, error_detail: e.message)
  #                 error_log.save
  #               end
  #             end
  #           end
  #         end
  #       end
  #     end
  #   end
  #   create_program_association_with_adjustment(@sheet)
  #   redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  # end

  def jumbo_series_i
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "Jumbo Series_I")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @adjustment_hash = {}
        @program_ids = []
        @credit_data = []
        primary_key = ''
        key = ''
        cltv_key = ''
        key1 = ''
        cltv_key1 = ''
        credit_data = ''
        main_key = ''
        @sheet = sheet
        # programs
        (2..32).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet"))
            rr = r + 1 # (r == 8)/ (r == 21)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3 + max_column*6 # (3 / 9 / 15)
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  p_name = @title + " " + sheet
                  program_heading = @title.split
                  # term
                    term = nil
                    program_heading = @title.split
                    if @title.include?("10yr") || @title.include?("10 Yr")
                      term = @title.scan(/\d+/)[0]
                    elsif @title.include?("15yr") || @title.include?("15 Yr")
                      term = @title.scan(/\d+/)[0]
                    elsif @title.include?("20yr") || @title.include?("20 Yr")
                      term = @title.scan(/\d+/)[0]
                    elsif @title.include?("25yr") || @title.include?("25 Yr")
                      term = @title.scan(/\d+/)[0]
                    elsif @title.include?("30yr") || @title.include?("30 Yr")
                      term = @title.scan(/\d+/)[0]
                    end

                    # rate type
                    if p_name.include?("Fixed")
                      loan_type = "Fixed"
                    elsif p_name.include?("ARM")
                      loan_type = "ARM"
                      arm_benchmark = "LIBOR"
                      arm_margin = 0
                    elsif p_name.include?("Floating")
                      loan_type = "Floating"
                    elsif p_name.include?("Variable")
                      loan_type = "Variable"
                    else
                      loan_type = "Fixed"
                    end

                    # rate arm
                    arm_basic = nil
                    if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM") || @title.include?("7/1") || @title.include?("5/1")
                      arm_basic = @title.scan(/\d+/)[0].to_i
                    end

                    arm_advanced = nil
                    if @title.include?("5/2/5")
                      arm_advanced = "5-2-5"
                    end

                    loan_size = nil
                    if p_name.include?("Jumbo")
                      loan_size = "Jumbo"
                    else
                      loan_size = "Conforming"
                    end

                    # loan_purpose
                    if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                      loan_purpose = "Refinance"
                    else
                      loan_purpose = "Purchase"
                    end

                    # lp and du
                    if p_name.downcase.include?('du ')
                      du = true
                    end
                    if p_name.downcase.include?('lp ')
                      lp = true
                    end

                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @program_ids << @program.id
                  @program.update(term: term,loan_type: loan_type ,arm_basic: arm_basic, loan_category: @sheet_name, loan_size: loan_size, arm_advanced: arm_advanced, loan_purpose: loan_purpose, du: du, lp: lp, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (0..50).each do |max_row|
                    @data = []
                    (0..4).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      else
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end

                    if @data.compact.length == 0
                      break # terminate the loop
                    end
                  end
                  if @block_hash.values.first.keys.first.nil?
                    @block_hash.values.first.shift
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        key = ''
        another_key = ''
        keyOfHash = ''
        # for Misc Adjusters
        first_key   = ''
        second_key  = ''
        third_key   = ''
        final_key   = ''
        f1_key      = ''
        f2_key      = ''
        loan_amount = ''
        # Adjustments
        (40..73).each do |row|
          unless @adjustment_hash.has_key?("MiscAdjuster")
            #  for 66
            @adjustment_hash["MiscAdjuster"] = {}
          end

          unless @adjustment_hash.has_key?("LoanType/LoanPurpose/Term")
            #  for 66
            @adjustment_hash["LoanType/LoanPurpose/Term"] = {}
            @adjustment_hash["LoanType/LoanPurpose/Term"]["Fixed"] = {}
            @adjustment_hash["LoanType/LoanPurpose/Term"]["Fixed"]["Purchase"] = {}
          end

          unless @adjustment_hash.has_key?("LoanType/Term")
            #  for 66
            @adjustment_hash["LoanType/Term"] = {}
            @adjustment_hash["LoanType/Term"]["Fixed"] = {}
            @adjustment_hash["LoanType/Term"]["ARM"] = {}
          end

          unless @adjustment_hash.has_key?("LoanType/FICO/LTV")
            #  for Credit Score table
            @adjustment_hash["LoanType/FICO/LTV"] = {}
            @adjustment_hash["LoanType/FICO/LTV"]["Fixed"] = {}
            @adjustment_hash["LoanType/FICO/LTV"]["ARM"] = {}
          end

          unless @adjustment_hash.has_key?("LoanType/LoanAmount/LTV")
            # for Loan Amount table
            @adjustment_hash["LoanType/LoanAmount/LTV"] = {}
            @adjustment_hash["LoanType/LoanAmount/LTV"]["Fixed"] = {}
            @adjustment_hash["LoanType/LoanAmount/LTV"]["ARM"] = {}
          end

          unless @adjustment_hash.has_key?("LoanType/PropertyType/LTV")
            # for Purpose/Property Type table
            @adjustment_hash["LoanType/PropertyType/LTV"] = {}
            @adjustment_hash["LoanType/PropertyType/LTV"]["Fixed"] = {}
            @adjustment_hash["LoanType/PropertyType/LTV"]["ARM"] = {}
          end

          unless @adjustment_hash.has_key?("LoanType/RefinanceOption/Term/LTV")
            @adjustment_hash["LoanType/RefinanceOption/Term/LTV"] = {}
            @adjustment_hash["LoanType/RefinanceOption/Term/LTV"]["Fixed"] = {}
            @adjustment_hash["LoanType/RefinanceOption/Term/LTV"]["ARM"] = {}
          end

          unless @adjustment_hash.has_key?("LoanType/LoanPurpose/RefinanceOption/LTV")
            @adjustment_hash["LoanType/LoanPurpose/RefinanceOption/LTV"] = {}
            @adjustment_hash["LoanType/LoanPurpose/RefinanceOption/LTV"]["Fixed"] = {}
            @adjustment_hash["LoanType/LoanPurpose/RefinanceOption/LTV"]["ARM"] = {}
          end

          (3..19).each do |column|
            value = sheet_data.cell(row,column)
            begin
              # prepare first key inside hash
              if((row >= 41 && row <= 45) && column.eql?(3))
                first_key = set_range(value) || get_value(value)
                @adjustment_hash["LoanType/FICO/LTV"]["Fixed"][first_key] = {}
              end

              if((row >= 50 && row <= 53) && column.eql?(3))
                first_key = convert_range(value)
                @adjustment_hash["LoanType/LoanAmount/LTV"]["Fixed"][first_key] = {}
              end

              if((row >= 58 && row <= 62) && column.eql?(3))
                first_key = set_range(value) || get_value(value)
                @adjustment_hash["LoanType/PropertyType/LTV"]["Fixed"][first_key] = {} if [58, 61].include?(row)
                if(row == 59)
                  @adjustment_hash["LoanType/RefinanceOption/Term/LTV"]["Fixed"]["Purchase"] = {}
                  @adjustment_hash["LoanType/RefinanceOption/Term/LTV"]["Fixed"]["Purchase"]["15"] = {}
                end
                if(row == 60)
                  @adjustment_hash["LoanType/LoanPurpose/RefinanceOption/LTV"]["Fixed"]["Refinance"] = {}
                  @adjustment_hash["LoanType/LoanPurpose/RefinanceOption/LTV"]["Fixed"]["Refinance"]["Cost Out"] = {}
                end
              end

              if((row >= 41 && row <= 45) && column.eql?(12))
                first_key = set_range(value) || get_value(value)
                @adjustment_hash["LoanType/FICO/LTV"]["ARM"][first_key] = {}
              end

              if((row >= 50 && row <= 53) && column.eql?(12))
                first_key = convert_range(value)
                @adjustment_hash["LoanType/LoanAmount/LTV"]["ARM"][first_key] = {}
              end

              if((row >= 58 && row <= 62) && column.eql?(12))
                first_key = set_range(value) || get_value(value)
                @adjustment_hash["LoanType/PropertyType/LTV"]["ARM"][first_key] = {} if [58, 61].include?(row)
                if(row == 59)
                  @adjustment_hash["LoanType/RefinanceOption/Term/LTV"]["ARM"]["Purchase"] = {}
                  @adjustment_hash["LoanType/RefinanceOption/Term/LTV"]["ARM"]["Purchase"]["15"] = {}
                end
                if(row == 60)
                  @adjustment_hash["LoanType/LoanPurpose/RefinanceOption/LTV"]["ARM"]["Refinance"] = {}
                  @adjustment_hash["LoanType/LoanPurpose/RefinanceOption/LTV"]["ARM"]["Refinance"]["Cost Out"] = {}
                end
              end

              # prepare second key & value
              if((row >= 41 && row <= 45) && column != 9 && (column > 4 && column <= 10))
                second_key = set_range(sheet_data.cell(40,column)) || get_value(sheet_data.cell(40,column))
                @adjustment_hash["LoanType/FICO/LTV"]["Fixed"][first_key][second_key] = value
              end

              if((row >= 50 && row <= 53) && column != 9 && (column > 4 && column <= 10))
                second_key = set_range(sheet_data.cell(49,column)) || get_value(sheet_data.cell(49,column))
                @adjustment_hash["LoanType/LoanAmount/LTV"]["Fixed"][first_key][second_key] = value
              end

              if((row >= 58 && row <= 62) && column.eql?(3))
                first_key = set_range(value) || get_value(value)
                @adjustment_hash["LoanType/PropertyType/LTV"]["Fixed"][first_key] = {} if [58, 61].include?(row)
                if(row == 59)
                  @adjustment_hash["LoanType/RefinanceOption/Term/LTV"]["Fixed"]["Purchase"] = {}
                  @adjustment_hash["LoanType/RefinanceOption/Term/LTV"]["Fixed"]["Purchase"]["15"] = {}
                end
                if(row == 60)
                  @adjustment_hash["LoanType/LoanPurpose/RefinanceOption/LTV"]["Fixed"]["Refinance"] = {}
                  @adjustment_hash["LoanType/LoanPurpose/RefinanceOption/LTV"]["Fixed"]["Refinance"]["Cost Out"] = {}
                end
              end

              if((row >= 58 && row <= 61) && column != 9 && (column > 4 && column <= 10))
                second_key = set_range(sheet_data.cell(57,column)) || get_value(sheet_data.cell(57,column))
                if [58, 61].include?(row)
                  @adjustment_hash["LoanType/PropertyType/LTV"]["Fixed"][first_key][second_key] = value
                end
                if(row == 59)
                  @adjustment_hash["LoanType/RefinanceOption/Term/LTV"]["Fixed"]["Purchase"]["15"][second_key] = value
                end
                if(row == 60)
                  @adjustment_hash["LoanType/LoanPurpose/RefinanceOption/LTV"]["Fixed"]["Refinance"]["Cost Out"][second_key] = value
                end
              end

              # for arm
              if((row >= 41 && row <= 45) && column != 15 && (column > 13 && column <= 19))
                second_key = set_range(sheet_data.cell(40,column)) || get_value(sheet_data.cell(40,column))
                @adjustment_hash["LoanType/FICO/LTV"]["ARM"][first_key][second_key] = value
              end

              if((row >= 50 && row <= 53) && column != 15 && (column > 13 && column <= 19))
                second_key = set_range(sheet_data.cell(49,column)) || get_value(sheet_data.cell(49,column))
                @adjustment_hash["LoanType/LoanAmount/LTV"]["ARM"][first_key][second_key] = value
              end

              if((row >= 58 && row <= 61) && column != 15 && (column > 13 && column <= 19))
                second_key = set_range(sheet_data.cell(57,column)) || get_value(sheet_data.cell(57,column))
                if [58, 61].include?(row)
                  @adjustment_hash["LoanType/PropertyType/LTV"]["ARM"][first_key][second_key] = value
                end
                if(row == 59)
                  @adjustment_hash["LoanType/RefinanceOption/Term/LTV"]["ARM"]["Purchase"]["15"][second_key] = value
                end
                if(row == 60)
                  @adjustment_hash["LoanType/LoanPurpose/RefinanceOption/LTV"]["ARM"]["Refinance"]["Cost Out"][second_key] = value
                end
              end

              # for last few tables
              if(row == 66 && column == 7)
                first_key = sheet_data.cell(row,column - 4)
                @adjustment_hash["MiscAdjuster"][first_key] = value
              end

              if(row == 66 && column == 7)
                first_key = sheet_data.cell(row,column - 4)
                @adjustment_hash["MiscAdjuster"][first_key] = value
              end

              if(row == 66 && column == 17)
                @adjustment_hash["LoanType/LoanPurpose/Term"]["Fixed"]["Purchase"]["30"] = value
              end

              if(row == 72)
                @adjustment_hash["LoanType/Term"]["Fixed"]["30"] = value if column == 7
                @adjustment_hash["LoanType/Term"]["ARM"]["7"] = value if column == 17
                @adjustment_hash["LoanType/Term"]["ARM"]["10"] = value if column == 17
              end

              if(row == 73)
                @adjustment_hash["LoanType/Term"]["Fixed"]["15"] = value if column == 7
                @adjustment_hash["LoanType/Term"]["ARM"]["5"] = value if column == 17
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: column, loan_category: @sheet_name, error_detail: e.message)
              error_log.save
            end
          end
        end
        make_adjust(@adjustment_hash, @sheet)
        create_program_association_with_adjustment(@sheet)
      end
    end
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  # def du_refi_plus_fixed_rate
  #   @programs_ids = []
  #   @xlsx.sheets.each do |sheet|
  #     if (sheet == "Du Refi Plus Fixed Rate")
    # sheet_data = @xlsx.sheet(sheet)
  #       @adjustment_hash = {}
  #       @program_ids = []
  #       @fixed_data = []
  #       @sub_data = []
  #       sub_data = ''
  #       primary_key = ''
  #       secondry_key = ''
  #       fixed_key = ''
  #       ltv_key = ''
  #       cltv_key = ''
  #       misc_key = ''
  #       adj_key = ''
  #       term_key = ''
  #       @sheet = sheet
  #       (1..61).each do |r|
  #         row = sheet_data.row(r)
  #         if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet")) || (row.include?("DU Refi Plus 10yr Fixed High Balance"))
  #           rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
  #           max_column_section = row.compact.count - 1
  #           (0..max_column_section).each do |max_column|
  #             cc = 3 + max_column*6 # (3 / 9 / 15)
  #             begin
  #               # title
  #               @title = sheet_data.cell(r,cc)

  #               # term
  #               term = nil
  #               program_heading = @title.split
  #               if @title.include?("10yr") || @title.include?("10 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("15yr") || @title.include?("15 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("20yr") || @title.include?("20 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("25yr") || @title.include?("25 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               elsif @title.include?("30yr") || @title.include?("30 Yr")
  #                 term = @title.scan(/\d+/)[0]
  #               end

  #               # rate type
  #               if @title.include?("Fixed")
  #                 loan_type = "Fixed"
  #               elsif @title.include?("ARM")
  #                 loan_type = "ARM"
  #               elsif @title.include?("Floating")
  #                 loan_type = "Floating"
  #               elsif @title.include?("Variable")
  #                 loan_type = "Variable"
  #               else
  #                 loan_type = nil
  #               end

  #               # rate arm
  #               if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM")
  #                 arm_basic = @title.scan(/\d+/)[0].to_i
  #               end

  #               # conforming
  #               conforming = false
  #               if @title.include?("Freddie Mac") || @title.include?("Fannie Mae") || @title.include?("Freddie Mac Home Possible") || @title.include?("Freddie Mac Home Ready")
  #                 conforming = true
  #               end

  #               # High Balance
  #               jumbo_high_balance = false
  #               if @title.include?("High Balance")
  #                 jumbo_high_balance = true
  #               end

  #               @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
  #               @program_ids << @program.id
  #               # Loan Limit Type
  #               if @title.include?("Non-Conforming")
  #                 @program.loan_limit_type << "Non-Conforming"
  #               end
  #               if @title.include?("Conforming")
  #                 @program.loan_limit_type << "Conforming"
  #               end
  #               if @title.include?("Jumbo")
  #                 @program.loan_limit_type << "Jumbo"
  #               end
  #               if @title.include?("High Balance")
  #                 @program.loan_limit_type << "High Balance"
  #               end
  #               @program.save
  #               @program.update(term: term,loan_type: loan_type,conforming: conforming, arm_basic: arm_basic, loan_category: sheet, jumbo_high_balance: jumbo_high_balance)
  #               @program.adjustments.destroy_all
  #               @block_hash = {}
  #               key = ''
  #               main_key = ''
  #               if @program.term.present?
  #                 main_key = "Term/LoanType/InterestRate/LockPeriod"
  #               else
  #                 main_key = "InterestRate/LockPeriod"
  #               end
  #               @block_hash[main_key] = {}
  #               (0..50).each do |max_row|
  #                 @data = []
  #                 (0..4).each_with_index do |index, c_i|
  #                   rrr = rr + max_row
  #                   ccc = cc + c_i
  #                   value = sheet_data.cell(rrr,ccc)
  #                   if (c_i == 0)
  #                     key = value
  #                     @block_hash[main_key][key] = {}
  #                   else
  #                     if @program.lock_period.length <= 3
  #                       @program.lock_period << 15*c_i
  #                       @program.save
  #                     end
  #                     @block_hash[main_key][key][15*c_i] = value
  #                   end
  #                   @data << value
  #                 end

  #                 if @data.compact.length == 0
  #                   break # terminate the loop
  #                 end
  #               end
  #               if @block_hash.values.first.keys.first.nil?
  #                 @block_hash.values.first.shift
  #               end
  #               @program.update(base_rate: @block_hash)
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #         end
  #       end
  #       # Adjustments
  #       (63..94).each do |r|
  #         row = sheet_data.row(r)
  #         @fixed_data = sheet_data.row(65)
  #         @sub_data = sheet_data.row(75)
  #         if row.compact.count >= 1
  #           (3..19).each do |max_column|
  #             cc = max_column
  #             begin
  #               value = sheet_data.cell(r,cc)
  #               if value.present?
  #                 if value == "Loan Level Price Adjustments: See Adjustment Caps" || value == "Adjustments Applied after Cap"
  #                   primary_key = value
  #                   @adjustment_hash[primary_key] = {}
  #                 end
  #                 if (r == 65 && cc == 3)
  #                   secondry_key = "LoanSize/LoanType/Term/FICO/LTV"
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end
  #                 if value == "Subordinate Financing"
  #                   secondry_key = "FinancingType/LTV/CLTV/FICO"
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end
  #                 if value == "Loan Size Adjustments"
  #                   secondry_key = "Loan Size Adjustments"
  #                   @adjustment_hash[primary_key][secondry_key] = {}
  #                 end

  #                 # All Fixed Confoming Adjustment
  #                 if r >= 66 && r <= 73 && cc == 8
  #                   fixed_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][fixed_key] = {}
  #                 end
  #                 if r >= 66 && r <= 73 && cc >8 && cc <= 19
  #                   fixed_data = get_value @fixed_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][fixed_key][fixed_data] = value
  #                 end

  #                 # Subordinate Financing Adjustment
  #                 if r >= 76 && r <= 80 && cc == 5
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 76 && r <= 80 && cc == 6
  #                   cltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key] = {}
  #                 end
  #                 if r >= 76 && r <= 80 && cc > 6 && cc <= 10
  #                   sub_data = get_value @sub_data[cc-2]
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key][cltv_key][sub_data] = value
  #                 end

  #                 # Adjustments Applied after Cap
  #                 if r >= 83 && r <= 89 && cc == 6
  #                   ltv_key = get_value value
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = {}
  #                 end
  #                 if r >= 83 && r <= 89 && cc > 6 && cc <= 10
  #                   @adjustment_hash[primary_key][secondry_key][ltv_key] = value
  #                 end

  #                 # Other Adjustment
  #                 if r >= 92 && r <= 94 && cc == 3
  #                   ltv_key = value
  #                   @adjustment_hash[primary_key][ltv_key] = {}
  #                 end
  #                 if r >= 92 && r <= 94 && cc == 10
  #                   @adjustment_hash[primary_key][ltv_key] = value
  #                 end
  #               end
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #           (12..19).each do |max_column|
  #             cc = max_column
  #             value = sheet_data.cell(r,cc)
  #             begin
  #               if value.present?
  #                 if value == "Misc Adjusters" || value == "Adjustment Caps"
  #                   misc_key = value
  #                   @adjustment_hash[misc_key] = {}
  #                 end

  #                 # Misc Adjustments
  #                 if r >= 75 && r <= 83 && cc == 15
  #                   if value.include?("Condo")
  #                     adj_key = "Condo/75/15"
  #                   else
  #                     adj_key = value
  #                   end
  #                   @adjustment_hash[misc_key][adj_key] = {}
  #                 end
  #                 if r >= 75 && r <= 83 && cc == 19
  #                   @adjustment_hash[misc_key][adj_key] = value
  #                 end

  #                 # Other Adjustments
  #                 if r == 85 && cc == 13
  #                   adj_key = value
  #                   @adjustment_hash[adj_key] = {}
  #                 end
  #                 if r == 85 && cc == 17
  #                   @adjustment_hash[adj_key] = value
  #                 end

  #                 # Adjustment Caps
  #                 if r >= 89 && r <= 93 && cc == 16
  #                   adj_key = value
  #                   @adjustment_hash[misc_key][adj_key] = {}
  #                 end
  #                 if r >= 89 && r <= 93 && cc == 17
  #                   term_key = get_value value
  #                   @adjustment_hash[misc_key][adj_key][term_key] = {}
  #                 end
  #                 if r >= 89 && r <= 93 && cc == 18
  #                   ltv_key = get_value value
  #                   @adjustment_hash[misc_key][adj_key][term_key][ltv_key] = {}
  #                 end
  #                 if r >= 89 && r <= 93 && cc == 19
  #                   @adjustment_hash[misc_key][adj_key][term_key][ltv_key] = value
  #                 end
  #               end
  #             rescue Exception => e
  #               error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
  #               error_log.save
  #             end
  #           end
  #         end
  #       end
  #       make_adjust(@adjustment_hash, @program_ids)
  #       create_program_association_with_adjustment(@sheet)
  #     end
  #   end
  #   redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  # end

  def jumbo_series_jqm
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "Jumbo Series_JQM")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @program_ids = []
        @adjustment_hash = {}
        @refinance_hash = {}
        @loan_amount = {}
        @state = {}
        @property_hash = {}
        primary_key = ''
        secondry_key = ''
        ltv_key = ''
        cltv_key = ''
        @sheet = sheet
        (2..60).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet"))
            rr = r + 1 # (r == 8)/ (r == 21)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 6 + max_column*6 # (6 / 12 / 18)
              begin
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                if @title.present?
                  program_heading = @title.split
                  # term
                  term = nil
                  if @title.include?("10yr") || @title.include?("10 Yr")
                    term = 10
                  elsif @title.include?("15yr") || @title.include?("15 Yr")
                    term = 15
                  elsif @title.include?("20yr") || @title.include?("20 Yr")
                    term = 20
                  elsif @title.include?("25yr") || @title.include?("25 Yr")
                    term = 25
                  elsif @title.include?("30yr") || @title.include?("30 Yr")
                    term = 30
                  end
                  if @title.include?("20/25/30 Yr")
                    term = 2030
                  elsif @title.include?("10/15 Yr")
                    term = 1015
                  end
                  # rate type
                  if p_name.include?("Fixed")
                    loan_type = "Fixed"
                  elsif p_name.include?("ARM")
                    loan_type = "ARM"
                    arm_benchmark = "LIBOR"
                    arm_margin = 0
                  elsif p_name.include?("Floating")
                    loan_type = "Floating"
                  elsif p_name.include?("Variable")
                    loan_type = "Variable"
                  else
                    loan_type = "Fixed"
                  end

                  # Loan Size
                  if p_name.downcase.include?("jumbo")
                    loan_size = "Jumbo"
                  else
                    loan_size = "Conforming"
                  end
                  # Arm basic
                  if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM") || @title.include?("5/1 LIBOR ARM") || @title.include?("7/1 LIBOR ARM") || @title.include?("10/1 LIBOR ARM")
                    arm_basic = @title.scan(/\d+/)[0].to_i
                  end
                  # Arm Advanced
                  if @title.downcase.include?("arm")
                    arm_advanced = @title.downcase.split("arm").last.tr("A-Za-z- ","")
                    if arm_advanced.include?('/')
                      arm_advanced = arm_advanced.tr('/','-')
                    else
                      arm_advanced
                    end
                  end
                  # loan_purpose
                  if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                    loan_purpose = "Refinance"
                  else
                    loan_purpose = "Purchase"
                  end
                  # lp and du
                  if p_name.downcase.include?('du ')
                    du = true
                  end
                  if p_name.downcase.include?('lp ')
                    lp = true
                  end
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @program_ids << @program.id
                  @program.update(term: term,loan_type: loan_type,arm_basic: arm_basic, loan_category: @sheet_name,loan_size: loan_size,arm_advanced: arm_advanced, loan_purpose: loan_purpose, du: du, lp: lp, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (0..50).each do |max_row|
                    @data = []
                    (0..4).each_with_index do |index, c_i|
                      rrr = rr + max_row
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      else
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end

                    if @data.compact.length == 0
                      break #terminate the loop
                    end
                  end
                  if @block_hash.values.first.keys.first.nil?
                    @block_hash.values.first.shift
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Adjustments
        (64..99).each do |r|
          row = sheet_data.row(r)
          @cltv_data = sheet_data.row(67)
          @cltv_data2 = sheet_data.row(66)
          @max_price_data = sheet_data.row(94)
          if row.compact.count >= 1
            (3..25).each do |cc|
              value = sheet_data.cell(r,cc)
              begin
                if value.present?
                  if value == "Purchase Transactions"
                    @adjustment_hash["LoanPurpose/FICO/LTV"] = {}
                    @adjustment_hash["LoanPurpose/FICO/LTV"]["Purchase"] = {}
                    @state["State"] = {}
                  end
                  if value == "R/T Refinance Transactions"
                    @refinance_hash["RefinanceOption/FICO/LTV"] = {}
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Rate and Term"] = {}
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                  end
                  if value == "Loan Amount Adjustments"
                    @loan_amount["LoanAmount/LTV"] = {}
                  end
                  if value == "Feature Adjustments"
                    @property_hash["PropertyType/LTV"] = {}
                  end
                  # Loan Amount Adjustments
                  if r >= 67 && r <= 70 && cc == 15
                    if value.include?("≤")
                      ltv_key = "0-"+value.tr('A-Z≤ $ ','')+",000,000"
                    else
                      ltv_key = (value.tr('A-Z$ ','').split("-").first.to_f*1000000).to_s+"-"+(value.tr('A-Z$ ','').split("-").last.to_f*1000000).to_s
                    end
                    @loan_amount["LoanAmount/LTV"][ltv_key] = {}
                  end
                  if r >= 67 && r <= 70 && cc > 15 && cc <= 25
                    if @cltv_data2[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data2[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data2[cc-2]
                    end
                    @loan_amount["LoanAmount/LTV"][ltv_key][secondry_key] = {}
                    @loan_amount["LoanAmount/LTV"][ltv_key][secondry_key] = value
                  end
                  # Purchase Transactions Adjustment
                  if r >= 68 && r <= 74 && cc == 3
                    if value.include?("≥")
                      primary_key = value.tr('≥ ','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      primary_key = get_value value
                    end
                    @adjustment_hash["LoanPurpose/FICO/LTV"]["Purchase"][primary_key] = {}
                  end
                  if r >= 68 && r <= 74 && cc >3 && cc <= 13
                    if @cltv_data[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data[cc-2]
                    end
                    @adjustment_hash["LoanPurpose/FICO/LTV"]["Purchase"][primary_key][secondry_key] = {}
                    @adjustment_hash["LoanPurpose/FICO/LTV"]["Purchase"][primary_key][secondry_key] = value
                  end
                  # Feature Adjustments
                  if r >= 75 && r <= 80 && cc == 15
                    primary_key = value
                    @property_hash["PropertyType/LTV"][primary_key] = {}
                  end
                  if r >= 75 && r <= 80 && cc > 15 && cc <= 25
                    if @cltv_data2[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data2[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data2[cc-2]
                    end
                    @property_hash["PropertyType/LTV"][primary_key][secondry_key] = {}
                    @property_hash["PropertyType/LTV"][primary_key][secondry_key] = value
                  end
                  # R/T Refinance Transactions Adjustment
                  if r >= 78 && r <= 84 && cc == 3
                    if value.include?("≥")
                      primary_key = value.tr('≥ ','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      primary_key = get_value value
                    end
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Rate and Term"][primary_key] = {}
                  end
                  if r >= 78 && r <= 84 && cc >3 && cc <= 13
                    if @cltv_data[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data[cc-2]
                    end
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Rate and Term"][primary_key][secondry_key] = {}
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Rate and Term"][primary_key][secondry_key] = value
                  end
                  # # C/O Refinance Transactions Adjustment
                  if r >= 88 && r <= 94 && cc == 3
                    if value.include?("≥")
                      primary_key = value.tr('≥ ','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      primary_key = get_value value
                    end
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key] = {}
                  end
                  if r >= 88 && r <= 94 && cc >3 && cc <= 13
                    if @cltv_data[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data[cc-2]
                    end
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][secondry_key] = {}
                    @refinance_hash["RefinanceOption/FICO/LTV"]["Cash Out"][primary_key][secondry_key] = value
                  end
                  # State Adjustments
                  if r == 99 && cc == 3
                    @state["State"]["FL"] = {}
                    @state["State"]["NV"] = {}
                  end
                  if r ==99 && cc >3 && cc <= 13
                    if @cltv_data[cc-2].include?("≤")
                      secondry_key = "0-"+@cltv_data[cc-2].tr('≤ ','')
                    else
                      secondry_key = get_value @cltv_data[cc-2]
                    end
                    @state["State"]["FL"][secondry_key] = {}
                    @state["State"]["NV"][secondry_key] = {}
                    @state["State"]["FL"][secondry_key] = value
                    @state["State"]["NV"][secondry_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@refinance_hash,@loan_amount,@state,@property_hash]
        create_adjust(adjustment,sheet)
        create_program_association_with_adjustment(@sheet)
      end
    end
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  def dream_big
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "Dream Big")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @adjustment_hash = {}
        @jumbo_adjustment = {}
        @cash_out = {}
        @program_ids = []
        fixed_key = ''
        ltv_key = ''
        @sheet = sheet
        (1..33).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("Dream Big Jumbo"))
            rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 2 + max_column*6 # (3 / 9 / 15)
              begin
                # title
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                # term
                term = nil
                program_heading = @title.split
                if @title.include?("10yr") || @title.include?("10 Yr")
                  term = 10
                elsif @title.include?("15yr") || @title.include?("15 Yr")
                  term = 15
                elsif @title.include?("20yr") || @title.include?("20 Yr")
                  term = 20
                elsif @title.include?("25yr") || @title.include?("25 Yr")
                  term = 25
                elsif @title.include?("30yr") || @title.include?("30 Yr")
                  term = 30
                end
                if @title.include?("20/25/30")
                  term = 2030
                end
                # interest type
                if p_name.include?("Fixed")
                  loan_type = "Fixed"
                elsif p_name.include?("ARM")
                  loan_type = "ARM"
                  arm_benchmark = "LIBOR"
                  arm_margin = 0
                elsif p_name.include?("Floating")
                  loan_type = "Floating"
                elsif p_name.include?("Variable")
                  loan_type = "Variable"
                else
                  loan_type = "Fixed"
                end

                # Arm basic
                if @title.include?("5/1 ARM") || @title.include?("7/1 ARM") || @title.include?("10-1 ARM") || @title.include?("10/1 ARM")
                  arm_basic = @title.scan(/\d+/)[0].to_i
                end

                # Arm Advanced
                if @title.downcase.include?("arm")
                  arm_advanced = @title.downcase.split("arm").last.tr('A-Za-z- ','')
                  if arm_advanced.include?('/')
                    arm_advanced = arm_advanced.tr('/','-')
                  else
                    arm_advanced
                  end
                end
                # conforming
                if p_name.downcase.include?("conforming")
                  conforming = true
                  loan_size = "Conforming"
                else
                  loan_size = "Conforming"
                end

                # freddie_mac
                if p_name.downcase.include?("freddie mac")
                  freddie_mac = true
                end

                # fannie_mae
                if p_name.downcase.include?("fannie mae")
                  fannie_mae = true
                end
                # loan_purpose
                if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                  loan_purpose = "Refinance"
                else
                  loan_purpose = "Purchase"
                end

                # lp and du
                if p_name.downcase.include?('du ')
                  du = true
                end
                if p_name.downcase.include?('lp ')
                  lp = true
                end

                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @program_ids << @program.id
                @program.update(term: term,loan_type: loan_type,conforming: conforming,freddie_mac: freddie_mac, fannie_mae: fannie_mae, arm_basic: arm_basic, loan_category: @sheet_name,arm_advanced: arm_advanced, loan_purpose: loan_purpose, du: du, lp: lp, loan_size: loan_size, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (0..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    else
                      @block_hash[key][15*c_i] = value
                    end
                    @data << value
                  end

                  if @data.compact.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil?
                  @block_hash.values.first.shift
                end
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Adjustments
        (38..62).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(39)
          @ltv_arm_data = sheet_data.row(54)
          if row.compact.count >= 1
            (0..18).each do |cc|
              value = sheet_data.cell(r,cc)
              begin
                if value.present?
                  if value == "LTV Based Adjustments for 20/25/30 Yr Fixed Jumbo Products"
                    @adjustment_hash["LoanType/Term/FICO/LTV"] = {}
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"] = {}
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["20"] = {}
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["25"] = {}
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["30"] = {}

                    @cash_out["RefinanceOption/LTV"] = {}
                  end
                  if value == "LTV Based Adjustments for 15 Yr Fixed and All ARM Jumbo Products"
                    @jumbo_adjustment["LoanType/Term/FICO/LTV"] = {}
                    @jumbo_adjustment["LoanType/Term/FICO/LTV"]["Fixed"] = {}
                    @jumbo_adjustment["LoanType/Term/FICO/LTV"]["Fixed"]["15"] = {}
                    @jumbo_adjustment["LoanType/FICO/LTV"] = {}
                    @jumbo_adjustment["LoanType/FICO/LTV"]["ARM"] = {}

                    @jumbo_adjustment["LoanType/RefinanceOption/Term/FICO/LTV"] = {}
                    @jumbo_adjustment["LoanType/RefinanceOption/Term/FICO/LTV"]["Fixed"] = {}

                    @jumbo_adjustment["LoanType/RefinanceOption/FICO/LTV"] = {}
                    @jumbo_adjustment["LoanType/RefinanceOption/FICO/LTV"]["ARM"] = {}
                  end
                  # LTV Based Adjustments for 20/25/30 Yr Fixed Jumbo Products
                  if (r >= 40 && r <= 45 && cc == 3)
                    if value.include?(">")
                      ltv_key = value.tr('>= ','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      ltv_key = get_value value
                    end
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["20"][ltv_key] = {}
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["25"][ltv_key] = {}
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["30"][ltv_key] = {}
                  end
                  if r >= 40 && r <= 45 && cc > 3 && cc <= 14
                    if @ltv_data[cc-2].include?("<")
                      fixed_key = "0-"+ @ltv_data[cc-2].tr('<>= ','')
                    else
                      fixed_key = get_value @ltv_data[cc-2]
                    end
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["20"][ltv_key][fixed_key] = {}
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["25"][ltv_key][fixed_key] = {}
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["30"][ltv_key][fixed_key] = {}
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["20"][ltv_key][fixed_key] = value
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["25"][ltv_key][fixed_key] = value
                    @adjustment_hash["LoanType/Term/FICO/LTV"]["Fixed"]["30"][ltv_key][fixed_key] = value
                  end
                  if r == 46 && cc == 2
                    @cash_out["RefinanceOption/LTV"]["Purchase"] = {}
                  end
                  if r == 46 && cc >= 4 && cc <= 14
                    if @ltv_data[cc-2].include?("<")
                      fixed_key = "0-"+ @ltv_data[cc-2].tr('<>= ','')
                    else
                      fixed_key = get_value @ltv_data[cc-2]
                    end
                    @cash_out["RefinanceOption/LTV"]["Purchase"][fixed_key] = {}
                    @cash_out["RefinanceOption/LTV"]["Purchase"][fixed_key] = value
                  end
                  if r == 47 && cc == 2
                    @cash_out["RefinanceOption/LTV"]["Cash Out"] = {}
                  end
                  if r == 47 && cc >= 4 && cc <= 14
                    if @ltv_data[cc-2].include?("<")
                      fixed_key = "0-"+ @ltv_data[cc-2].tr('<>= ','')
                    else
                      fixed_key = get_value @ltv_data[cc-2]
                    end
                    @cash_out["RefinanceOption/LTV"]["Cash Out"][fixed_key] = {}
                    @cash_out["RefinanceOption/LTV"]["Cash Out"][fixed_key] = value
                  end
                  if r == 48 && cc == 2
                    @cash_out["RefinanceOption/LTV"]["Rate and Term"] = {}
                  end
                  if r == 48 && cc >= 4 && cc <= 14
                    if @ltv_data[cc-2].include?("<")
                      fixed_key = "0-"+ @ltv_data[cc-2].tr('<>= ','')
                    else
                      fixed_key = get_value @ltv_data[cc-2]
                    end
                    @cash_out["RefinanceOption/LTV"]["Rate and Term"][fixed_key] = {}
                    @cash_out["RefinanceOption/LTV"]["Rate and Term"][fixed_key] = value
                  end
                  if r == 50 && cc == 2
                    @cash_out["RefinanceOption/LTV"]["Non-Owner Occupied"] = {}
                  end
                  if r == 50 && cc >= 4 && cc <= 14
                    if @ltv_data[cc-2].include?("<")
                      fixed_key = "0-"+ @ltv_data[cc-2].tr('<>= ','')
                    else
                      fixed_key = get_value @ltv_data[cc-2]
                    end
                    @cash_out["RefinanceOption/LTV"]["Non-Owner Occupied"][fixed_key] = {}
                    @cash_out["RefinanceOption/LTV"]["Non-Owner Occupied"][fixed_key] = value
                  end
                  # LTV Based Adjustments for 15 Yr Fixed and All ARM Jumbo Products
                  if r >= 55 && r <= 60 && cc == 3
                    if value.include?(">")
                      ltv_key = value.tr('>= ','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      ltv_key = get_value value
                    end
                    @jumbo_adjustment["LoanType/Term/FICO/LTV"]["Fixed"]["15"][ltv_key] = {}
                    @jumbo_adjustment["LoanType/FICO/LTV"]["ARM"][ltv_key] = {}
                  end
                  if r >= 55 && r <= 60 && cc > 3 && cc <= 14
                    if @ltv_arm_data[cc-2].include?("<")
                      fixed_key = "0-"+ @ltv_arm_data[cc-2].tr('<>= ','')
                    else
                      fixed_key = get_value @ltv_arm_data[cc-2]
                    end
                    @jumbo_adjustment["LoanType/Term/FICO/LTV"]["Fixed"]["15"][ltv_key][fixed_key] = {}
                    @jumbo_adjustment["LoanType/Term/FICO/LTV"]["Fixed"]["15"][ltv_key][fixed_key] = value
                    @jumbo_adjustment["LoanType/FICO/LTV"]["ARM"][ltv_key][fixed_key] = {}
                    @jumbo_adjustment["LoanType/FICO/LTV"]["ARM"][ltv_key][fixed_key] = value
                  end
                  if r == 61 && cc == 2
                    @jumbo_adjustment["LoanType/RefinanceOption/Term/FICO/LTV"]["Fixed"]["Purchase"] = {}
                    @jumbo_adjustment["LoanType/RefinanceOption/FICO/LTV"]["ARM"]["Purchase"] = {}
                    @jumbo_adjustment["LoanType/RefinanceOption/Term/FICO/LTV"]["Fixed"]["Purchase"]["15"] = {}
                  end
                  if r == 61 && cc > 3 && cc <= 14
                    if @ltv_arm_data[cc-2].include?("<")
                      fixed_key = "0-"+ @ltv_arm_data[cc-2].tr('<>= ','')
                    else
                      fixed_key = get_value @ltv_arm_data[cc-2]
                    end
                    @jumbo_adjustment["LoanType/RefinanceOption/Term/FICO/LTV"]["Fixed"]["Purchase"]["15"][fixed_key] = {}
                    @jumbo_adjustment["LoanType/RefinanceOption/FICO/LTV"]["ARM"]["Purchase"][fixed_key] = {}
                    @jumbo_adjustment["LoanType/RefinanceOption/Term/FICO/LTV"]["Fixed"]["Purchase"]["15"][fixed_key] = value
                    @jumbo_adjustment["LoanType/RefinanceOption/FICO/LTV"]["ARM"]["Purchase"][fixed_key] = value
                  end
                  if r == 62 && cc == 2
                    @jumbo_adjustment["LoanType/RefinanceOption/Term/FICO/LTV"]["Fixed"]["Cash Out"] = {}
                    @jumbo_adjustment["LoanType/RefinanceOption/FICO/LTV"]["ARM"]["Cash Out"] = {}
                    @jumbo_adjustment["LoanType/RefinanceOption/Term/FICO/LTV"]["Fixed"]["Cash Out"]["15"] = {}
                  end
                  if r == 62 && cc > 3 && cc <= 14
                    if @ltv_arm_data[cc-2].include?("<")
                      fixed_key = "0-"+ @ltv_arm_data[cc-2].tr('<>= ','')
                    else
                      fixed_key = get_value @ltv_arm_data[cc-2]
                    end
                    @jumbo_adjustment["LoanType/RefinanceOption/Term/FICO/LTV"]["Fixed"]["Cash Out"]["15"][fixed_key] = {}
                    @jumbo_adjustment["LoanType/RefinanceOption/FICO/LTV"]["ARM"]["Cash Out"][fixed_key] = {}
                    @jumbo_adjustment["LoanType/RefinanceOption/Term/FICO/LTV"]["Fixed"]["Cash Out"]["15"][fixed_key] = value
                    @jumbo_adjustment["LoanType/RefinanceOption/FICO/LTV"]["ARM"]["Cash Out"][fixed_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@jumbo_adjustment,@cash_out]
        create_adjust(adjustment,sheet)
        create_program_association_with_adjustment(@sheet)
      end
    end
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  def high_balance_extra
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "High Balance Extra")
        @sheet_name = sheet
        sheet_data = @xlsx.sheet(sheet)
        @program_ids = []
        @adjustment_hash = {}
        @sub_hash = {}
        @cash_out = {}
        @bal_data = []
        @sub_data = []
        primary_key = ''
        secondry_key = ''
        ltv_key = ''
        cltv_key = ''
        key = ''
        bal_data = ''
        sub_data = ''
        @sheet = sheet
        (5..23).each do |r|
          row = sheet_data.row(r)
          if (row.compact.include?("High Balance Extra 30 Yr Fixed"))
            rr = r + 1
            max_column_section = row.compact.count
            (0..max_column_section).each do |max_column|
              cc = 2 + max_column*6 # (3 / 9 / 15)
              begin
                # title
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                if @title.present?
                  # term
                  term = nil
                  if @title.include?("10yr") || @title.include?("10 Yr")
                    term = @title.scan(/\d+/)[0]
                  elsif @title.include?("15yr") || @title.include?("15 Yr")
                    term = @title.scan(/\d+/)[0]
                  elsif @title.include?("20yr") || @title.include?("20 Yr")
                    term = @title.scan(/\d+/)[0]
                  elsif @title.include?("25yr") || @title.include?("25 Yr")
                    term = @title.scan(/\d+/)[0]
                  elsif @title.include?("30yr") || @title.include?("30 Yr")
                    term = @title.scan(/\d+/)[0]
                  end


                  # rate type
                  if p_name.include?("Fixed")
                    loan_type = "Fixed"
                  elsif p_name.include?("ARM")
                    loan_type = "ARM"
                    arm_benchmark = "LIBOR"
                    arm_margin = 0
                  elsif p_name.include?("Floating")
                    loan_type = "Floating"
                  elsif p_name.include?("Variable")
                    loan_type = "Variable"
                  else
                    loan_type = "Fixed"
                  end
                  # rate arm
                  if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM")
                    arm_basic = @title.scan(/\d+/)[0].to_i
                  end
                  # High Balance
                  if p_name.downcase.include?("high balance extra")
                    loan_size = "High-Balance Extra"
                  else
                    loan_size = "Conforming"
                  end
                  # loan_purpose
                  if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                    loan_purpose = "Refinance"
                  else
                    loan_purpose = "Purchase"
                  end
                  # lp and du
                  if p_name.downcase.include?('du ')
                    du = true
                  end
                  if p_name.downcase.include?('lp ')
                    lp = true
                  end
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  @program_ids << @program.id
                  @program.update(term: term,loan_type: loan_type, arm_basic: arm_basic, loan_category: @sheet_name, loan_size: loan_size, loan_purpose: loan_purpose, du: du, lp: lp, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (0..19).each do |max_row|
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

                    if @data.compact.length == 0
                      break # terminate the loop
                    end
                  end
                  if @block_hash.values.first.keys.first.nil? || @block_hash.keys.first == "Rate"
                    @block_hash.shift
                  end
                  @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Adjustments
        (25..44).each do |r|
          row = sheet_data.row(r)
          @bal_data = sheet_data.row(27)
          @sub_data = sheet_data.row(41)
          if row.compact.count >= 1
            (0..9).each do |max_column|
              cc = max_column
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Pricing Adjustments"
                    @adjustment_hash["LoanSize/FICO/LTV"] = {}
                    @adjustment_hash["LoanSize/FICO/LTV"]["High-Balance"] = {}
                  end
                  if value == "Cashout (adjustments are cumulative)"
                    @cash_out["RefinanceOption/FICO/LTV"] = {}
                    @cash_out["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                  end
                  if value == "Sub Financing (adjustments are cumulative)"
                    @sub_hash["FinancingType/LTV/CLTV/FICO"] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"] = {}
                  end
                  # All High Balance Extra Loans
                  if r >= 28 && r <= 32 && cc == 2
                    if value.include?(">")
                      ltv_key = value.tr('>=','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      ltv_key = get_value value
                    end
                    @adjustment_hash["LoanSize/FICO/LTV"]["High-Balance"][ltv_key] = {}
                  end
                  if r >= 28 && r <= 32 && cc > 3 && cc <= 9
                    if @bal_data[cc-2].include?("<")
                      bal_data = "0-"+ @bal_data[cc-2].tr('<= ','')
                    else
                      bal_data = get_value @bal_data[cc-2]
                    end
                    @adjustment_hash["LoanSize/FICO/LTV"]["High-Balance"][ltv_key][bal_data] = {}
                    @adjustment_hash["LoanSize/FICO/LTV"]["High-Balance"][ltv_key][bal_data] = value
                  end
                  # Cashout Adjustments
                  if r >= 34 && r <= 38 && cc == 2
                    if value.include?(">")
                      ltv_key = value.tr('>=','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      ltv_key = get_value value
                    end
                    @cash_out["RefinanceOption/FICO/LTV"]["Cash Out"][ltv_key] = {}
                  end
                  if r >= 34 && r <= 38 && cc > 3 && cc <= 9
                    if @bal_data[cc-2].include?("<")
                      bal_data = "0-"+ @bal_data[cc-2].tr('<= ','')
                    else
                      bal_data = get_value @bal_data[cc-2]
                    end
                    @cash_out["RefinanceOption/FICO/LTV"]["Cash Out"][ltv_key][bal_data] = {}
                    @cash_out["RefinanceOption/FICO/LTV"]["Cash Out"][ltv_key][bal_data] = value
                  end

                  # Subordinate Financing Adjustments
                  if r >= 42 && r <= 44 && cc == 2
                    if value.include?("<")
                      ltv_key = "0-"+ value.tr('<= ','')
                    else
                      ltv_key = get_value value
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][ltv_key] = {}
                  end
                  if r >= 42 && r <= 44 && cc == 3
                    cltv_key = get_value value
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][ltv_key][cltv_key] = {}
                  end
                  if r >= 42 && r <= 44 && cc > 3 && cc <= 5
                    if @sub_data[cc-2].include?(">")
                      sub_data = @sub_data[cc-2].tr('>= ','')+"-#{(Float::INFINITY).to_s.downcase}"
                    else
                      sub_data = get_value @sub_data[cc-2]
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][ltv_key][cltv_key][sub_data] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][ltv_key][cltv_key][sub_data] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@sub_hash,@cash_out]
        create_adjust(adjustment,sheet)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  def freddie_arms
    @program_ids = []
    @allAdjustments = {}
    @xlsx.sheets.each do |sheet|
      if (sheet == "Freddie ARMs")
        @sheet_name = sheet
        @sheet = sheet
        sheet_data = @xlsx.sheet(sheet)

        (1..47).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet")) || (row.include?("Freddie Mac 10-1 ARM (5-2-5) Super Conforming"))
            rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3 + max_column*6 # (3 / 9 / 15)
              begin
                # title
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                # term
                term = nil
                if @title.include?("10yr") || @title.include?("10 Yr")
                  term = 10
                elsif @title.include?("15yr") || @title.include?("15 Yr")
                  term = 15
                elsif @title.include?("20yr") || @title.include?("20 Yr")
                  term = 20
                elsif @title.include?("25yr") || @title.include?("25 Yr")
                  term = 25
                elsif @title.include?("30yr") || @title.include?("30 Yr")
                  term = 30
                end

                # rate type
                if p_name.include?("Fixed")
                  loan_type = "Fixed"
                elsif p_name.include?("ARM")
                  loan_type = "ARM"
                  arm_benchmark = "LIBOR"
                  arm_margin = 0
                elsif p_name.include?("Floating")
                  loan_type = "Floating"
                elsif p_name.include?("Variable")
                  loan_type = "Variable"
                else
                  loan_type = "Fixed"
                end

                # Arm Basic
                if @title.include?("3-1 ARM") || @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM")
                  arm_basic = @title.scan(/\d+/)[0].to_i
                end

                # Arm Advanced
                if @title.downcase.include?("arm")
                  arm_advanced = @title.downcase.split("arm").last.tr('A-Za-z() ','')
                  if arm_advanced.include?('/')
                    arm_advanced = arm_advanced.tr('/','-')
                  else
                    arm_advanced
                  end
                end

                # conforming
                if p_name.downcase.include?("super conforming")
                  loan_size = "Super Conforming"
                elsif p_name.downcase.include?("conforming") 
                  conforming = true
                  loan_size = "Conforming"
                else
                  loan_size = "Conforming"
                end

                # freddie_mac
                freddie_mac = false
                if p_name.include?("Freddie Mac")
                  freddie_mac = true
                end

                # fannie_mae
                fannie_mae = false
                if p_name.include?("Fannie Mae") 
                  fannie_mae = true
                end

                # loan_purpose
                if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                  loan_purpose = "Refinance"
                else
                  loan_purpose = "Purchase"
                end

                # lp and du
                if p_name.downcase.include?('du ')
                  du = true
                end
                if p_name.downcase.include?('lp ')
                  lp = true
                end

                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @program_ids << @program.id
                @program.update(term: term,loan_type: loan_type,conforming: conforming,freddie_mac: freddie_mac, fannie_mae: fannie_mae, arm_basic: arm_basic, loan_category: @sheet_name, arm_advanced: arm_advanced,loan_size: loan_size, loan_purpose: loan_purpose, du: du, lp: lp, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (0..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    else
                      @block_hash[key][15*c_i] = value
                    end
                    @data << value
                  end

                  if @data.compact.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil?
                  @block_hash.values.first.shift
                end
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # adjustments
        previous_title = nil
        @another_title = nil
        modified_keys  = get_table_keys
        data = get_table_keys
        (49..96).each do |r|
          row    = sheet_data.row(r)
          # r == 52 / 68 / 81 / 84 / 89 / 94
          rr = r #+ 1 # (r == 53) / (r == 69) / (r == 82) / (r == 90) / (r == 95)
          max_column_section = row.compact.count - 1
          (0..max_column_section).each do |max_column|
            cc = 3 + max_column * 9 # (2 / 11)
            @title = sheet_data.cell(r,cc)
            @block_hash = {}
            if(@title.eql?("All Conforming ARMs (Does not include LP Open Access)"))
              @title = "LoanSize/LoanType/FICO/LTV"

              unless @block_hash.has_key?(@title)
                @block_hash[@title] = {}
                @block_hash[@title]["Conforming"] = {}
                @block_hash[@title]["Conforming"]["ARM"] = {}
              end

              @block_hash["PropertyType"] = {} unless @block_hash.has_key?("PropertyType")
              @block_hash["MiscAdjuster"] = {} unless @block_hash.has_key?("MiscAdjuster")
              @block_hash["LockDay"] = {} unless @block_hash.has_key?("LockDay")
              @block_hash["LTV"] = {} unless @block_hash.has_key?("LTV")

              unless @block_hash.has_key?("LoanPurpose/RefinanceOption/LTV")
                @block_hash["LoanPurpose/RefinanceOption/LTV"] = {}
                @block_hash["LoanPurpose/RefinanceOption/LTV"]["Purchase"] = {}
                @block_hash["LoanPurpose/RefinanceOption/LTV"]["Purchase"]["Rate & Term"] = {}
                @block_hash["RefinanceOption/LTV"] = {}
                @block_hash["RefinanceOption/LTV"]["Cash Out"] = {}
              end

              key = ''
              another_key = ''
              keyOfHash = ''
              # for Misc Adjusters
              first_key   = ''
              second_key  = ''
              third_key   = ''
              final_key   = ''
              f1_key      = ''
              f2_key      = ''
              loan_amount = ''

              (0..47).each do |max_row|
                @data = []
                (7..19).each_with_index do |index, c_i|
                  rrr = rr + max_row
                  ccc = index
                  begin
                    value = sheet_data.cell(rrr,ccc)
                    # implementation of first key
                    if rrr.eql?(63)
                      # for 2nd table
                      @title = sheet_data.cell(rrr,cc)
                      unless @block_hash.has_key?(@title)
                        @block_hash[@title] = {}
                        @block_hash[@title]["Cash Out"] = {}
                      end
                    elsif rrr.eql?(69)
                      # for 3rd table
                      previous_title = @title = sheet_data.cell(rrr,ccc - 4) unless previous_title == @title
                      unless @block_hash.has_key?(@title)
                        @block_hash[@title] = {}
                        first_key  = "LPMI/RefinanceOption/LTV"
                        second_key = "LPMI/PropertyType/LTV"
                        final_key  = "LPMI/FICO/LTV"
                        @block_hash[@title][first_key] = {}
                        @block_hash[@title][first_key]["true"] = {}
                        @block_hash[@title][second_key] = {}
                        @block_hash[@title][second_key]["true"] = {}
                        @block_hash[@title][final_key] = {}
                        @block_hash[@title][final_key]["true"] = {}
                      end
                    elsif rrr.eql?(81) && index == 7
                      # for Number Of Units
                      @title = sheet_data.cell(rrr,(ccc - 4))
                      unless @block_hash.has_key?(@title)
                        @block_hash[@title] = {}
                      end
                    elsif rrr.eql?(81) && index == 13
                      @another_title = sheet_data.cell(rrr+1,index)
                      unless @block_hash.has_key?(@another_title)
                        @block_hash[@another_title] = {}
                      end
                    elsif rrr.eql?(84) && index.eql?(7)
                      # for Subordinate Financing
                      @title = sheet_data.cell(rrr,ccc - 4)
                      unless @block_hash.has_key?(@title)
                        @block_hash[@title] = {}
                        @block_hash[@title]["Subordinate Financing"] = {}
                      end
                    elsif rrr.eql?(89) && index.eql?(7)
                      # for Misc Adjusters
                      @title = sheet_data.cell(rrr,ccc - 4)
                      @block_hash[@title] = {} unless @block_hash.has_key?(@title)
                    elsif rrr.eql?(94) && index.eql?(7)
                      # for Non Owner Occupied
                      @title = sheet_data.cell(rrr,ccc - 4)
                      @block_hash[@title] = {} unless @block_hash.has_key?(@title)
                      @block_hash[@title]["Non-Owner Occupied"] = {}
                    end

                    # implementation of second key inside first key
                    if rrr > 52 && rrr < 60 && index == 7 && value
                      # for 1st table
                      key = get_value(value)
                      @block_hash[@title]["Conforming"]["ARM"][key] = {} unless @block_hash[@title]["Conforming"]["ARM"].has_key?(key)
                    elsif rrr > 62 && rrr < 67 && index == 7 && value
                      # for 2nd table
                      key = get_value(value)
                      @block_hash[@title]["Cash Out"][key] = {} unless @block_hash[@title]["Cash Out"].has_key?(key)
                    elsif (69..79).to_a.include?(rrr) && index == 7 && value
                      if(68..74).to_a.include?(rrr) && index == 7 && value
                        key = sheet_data.cell(rrr,ccc - 2)
                        if ["Rate & Term Refi", "Cash Out"].include?(key)
                          key = key.eql?("Rate & Term Refi") ? "Rate & Term" : "Cash Out"
                          @block_hash[@title][first_key]["true"][key] = {}
                        else
                          @block_hash[@title][second_key]["true"][key] = {}
                        end
                      elsif(76..79).to_a.include?(rrr) && index == 7 && value
                        key = sheet_data.cell(rrr,ccc - 2)
                        key = key.eql?("<= 85") ? set_range(key) : get_value(key)
                        @block_hash[@title][final_key]["true"][key] = {}
                      else
                        @block_hash[@title][key] = {}
                      end
                    else
                      if [82,83].include?(rrr) && index == 7
                        # for Number Of Units
                        key = sheet_data.cell(rrr,ccc - 1)
                        @block_hash[@title][key] = {}
                      elsif (rrr >= 82 && rrr <= 89) && index.eql?(15)
                        # for Loan Size Adjustments
                        loan_amount = get_value(sheet_data.cell(rrr, ccc))
                        @block_hash[@another_title][loan_amount] = {}
                      end

                      if (85..88).to_a.include?(rrr) && ccc < 13
                        # for Subordinate Financing
                        if index.eql?(7)
                          key = sheet_data.cell(rrr,ccc - 1)
                          key = set_range(key).nil? ? get_value(key) : set_range(key)
                          @block_hash[@title]["Subordinate Financing"][key] = {} unless @block_hash[@title]["Subordinate Financing"].has_key?(key)
                        elsif index.eql?(8)
                          keyOfHash = sheet_data.cell(rrr,ccc - 1)
                          keyOfHash = set_range(keyOfHash).nil? ? get_value(keyOfHash) : set_range(keyOfHash)
                          @block_hash[@title]["Subordinate Financing"][key][keyOfHash] = {}
                        end
                      end

                      if (89..93).to_a.include?(rrr) && ccc < 13
                        # for Misc Adjusters
                        if index.eql?(7)
                          key = sheet_data.cell(rrr,ccc - 1)
                          if key && key.eql?("Condo > 75 LTV (>15yr Term)")
                            first_key = key.split(" >")[0]
                            @block_hash[@title][first_key] = {}
                            second_key = sheet_data.cell(rrr,ccc - 1).split(" ")[2] + ".01"
                            @block_hash[@title][first_key][second_key] = {}
                            third_key = sheet_data.cell(rrr,ccc - 1).split(" ")[4].split("(>")[1].split("yr")[0] + ".01"
                          elsif key && key.eql?(">90 LTV")
                            first_key  = set_range(key.split(" LTV")[0])
                          end
                        end
                      end
                    end

                    # implementation of third key inside second key with value
                    if rrr > 52 && rrr < 60 && index > 7 && value
                      diff_of_row = rrr - 52
                      hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                      hash_key = hash_key.eql?("≥ 760") ? set_range(hash_key) : get_value(hash_key)
                      if hash_key.present?
                        @block_hash[@title]["Conforming"]["ARM"][key][hash_key] = value unless @block_hash[@title]["Conforming"]["ARM"][key].has_key?(hash_key)
                      end
                    elsif rrr > 62 && rrr < 67 && index > 7 && value
                      # for 2nd table
                      hash_key = sheet_data.cell(rrr - (max_row + 1),ccc)
                      hash_key = hash_key.eql?(">= 760") ? set_range(hash_key) : get_value(hash_key)
                      if hash_key.present?
                        @block_hash[@title]["Cash Out"][key][hash_key] = value unless @block_hash[@title]["Cash Out"][key].has_key?(hash_key)
                      end
                    elsif rrr >= 69 && index >= 7 && value
                      if (rrr <= 79)
                        # for 3rd table (69..79).to_a
                        diff_of_row = rrr - 68
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = set_range(hash_key).nil? ? get_value(hash_key) : set_range(hash_key)
                        if (69..74).to_a.include?(rrr)
                          if(69..74).to_a.include?(rrr) && index >= 7 && value
                            if [69,74].include?(rrr)
                              @block_hash[@title][first_key]["true"][key][hash_key] = value
                            else
                              @block_hash[@title][second_key]["true"][key][hash_key] = value
                            end
                          end
                        elsif(76..79).to_a.include?(rrr) && index >= 7 && value
                          @block_hash[@title][final_key]["true"][key][hash_key] = value
                        end
                      elsif [82,83].include?(rrr) && [9,10,11].include?(index)
                        # for Number Of Units
                        diff_of_row = rrr - 81
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = (hash_key.eql?("<=80") || hash_key.eql?("> 85")) ? set_range(hash_key) : get_value(hash_key)
                        @block_hash[@title][key][hash_key] = value if hash_key.present?
                      elsif (82..89).to_a.include?(rrr) && ccc > 15 && value
                        #for Loan Size Adjustments
                        diff_of_row  = rrr - 81
                        loan_purpose = sheet_data.cell(rrr-diff_of_row,ccc)
                        @block_hash[@another_title][loan_amount][loan_purpose] = value
                      end

                      if (85..88).to_a.include?(rrr) && [10,11].include?(ccc)
                        # for Subordinate Financing
                        diff_of_row = rrr - 84
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = hash_key.eql?(">= 720") ? set_range(hash_key) : get_value(hash_key)
                        @block_hash[@title]["Subordinate Financing"][key][keyOfHash][hash_key] = value if hash_key.present?
                      end

                      if (89..93).to_a.include?(rrr) && ccc.eql?(11)
                        # for Misc Adjusters
                        if rrr.eql?(89)
                          @block_hash[@title][first_key][second_key][third_key] = value
                        elsif rrr.eql?(90)
                          @block_hash["LTV"][first_key] = value
                        elsif [91, 92].include?(rrr)
                          misc_adjuster = sheet_data.cell(rrr,(ccc -5))
                          @block_hash["MiscAdjuster"][misc_adjuster] = value
                        elsif rrr.eql?(93)
                          @block_hash["PropertyType"]["Manufactured Home"] = value
                        end
                      end

                      if [94,95,96].include?(rrr) && ccc.eql?(11)
                        #for Non Owner Occupied
                        occupancy_key = sheet_data.cell(rrr,(ccc -4))
                        occupancy_key = set_range(occupancy_key).nil? ? get_value(occupancy_key) : set_range(occupancy_key)
                        @block_hash[@title]["Non-Owner Occupied"][occupancy_key] = value if key && value
                      end

                      if (91..94).to_a.include?(rrr)
                        # for Super Conforming
                        if index.eql?(19)
                          has_key  = sheet_data.cell(rrr,ccc - 3)
                          has_key  = has_key.split(" ")[2] + has_key.split(" ")[3] unless [91, 92].include?(rrr)
                          hash_key = set_range(has_key.split(" ")[4]).nil? ? get_value(has_key.split(" ")[4]) : set_range(has_key.split(" ")[4]) if [91, 92].include?(rrr)
                          hash_key = set_range(has_key).nil? ? get_value(has_key) : set_range(has_key) unless [91, 92].include?(rrr)
                          @block_hash["LoanPurpose/RefinanceOption/LTV"]["Purchase"]["Rate & Term"][hash_key] = value if [91, 92].include?(rrr)
                          @block_hash["RefinanceOption/LTV"]["Cash Out"][hash_key] = value unless [91, 92].include?(rrr)
                        end
                      end

                      if rrr.eql?(96) && index.eql?(19)
                        @block_hash["LockDay"]["30"] = value
                        @block_hash["LockDay"]["45"] = value
                        @block_hash["LockDay"]["60"] = value
                      end
                    end
                  rescue Exception => e
                    error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                    error_log.save
                  end
                end

                @allAdjustments[@title] = @block_hash[@title]
                if @another_title
                  @allAdjustments[@another_title] = @block_hash[@another_title]
                  @allAdjustments["PropertyType"] = @block_hash["PropertyType"]
                  @allAdjustments["MiscAdjuster"] = @block_hash["MiscAdjuster"]
                  @allAdjustments["PropertyType/LTV"] = @block_hash["PropertyType/LTV"]
                  @allAdjustments["LockDay"] = @block_hash["LockDay"]
                  @allAdjustments["LTV"] = @block_hash["LTV"]
                end
              end
            end
          end
        end
      end
    end

    # rename first level keys
    @allAdjustments.keys.each do |key|
      data = get_table_keys
      if data[key]
        @allAdjustments[data[key]] = @allAdjustments.delete(key)
      end
    end

    # create adjustment for each program
    make_adjust(@allAdjustments, @sheet_name)
    create_program_association_with_adjustment(@sheet)
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  def conforming_arms
    @program_ids = []
    @allAdjustments = {}
    @xlsx.sheets.each do |sheet|
      if (sheet == "Conforming ARMs")
        @sheet_name = sheet
        @sheet = sheet
        sheet_data = @xlsx.sheet(sheet)

        (1..47).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet")) || row.compact.include?("Fannie Mae 10-1 ARM (5-2-5) High Balance")
            # r == 7 / 35 / 55
            rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3 + max_column*6 # (3 / 9 / 15)
              begin
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                term = nil
                if @title.include?("10yr") || @title.include?("10 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("15yr") || @title.include?("15 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("20yr") || @title.include?("20 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("25yr") || @title.include?("25 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("30yr") || @title.include?("30 Yr")
                  term = @title.scan(/\d+/)[0]
                end

                if p_name.include?("Fixed")
                  loan_type = "Fixed"
                elsif p_name.include?("ARM")
                  loan_type = "ARM"
                  arm_benchmark = "LIBOR"
                  arm_margin = 0
                elsif p_name.include?("Floating")
                  loan_type = "Floating"
                elsif p_name.include?("Variable")
                  loan_type = "Variable"
                else
                  loan_type = "Fixed"
                end

                # rate arm
                if @title.include?("3-1 ARM") || @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM") || @title.include?("5/1 ARM") || @title.include?("7/1 ARM") || @title.include?("10/1 ARM")
                  arm_basic = @title.scan(/\d+/)[0].to_i
                end

                freddie_mac = false
                if p_name.downcase.include?("freddie mac")
                  freddie_mac = true
                end

                conforming = false
                if p_name.downcase.include?("conforming") 
                  conforming = true
                end

                fannie_mae = false
                if p_name.downcase.include?("fannie mae")
                  fannie_mae = true
                end
                # Arm Advanced
                if @title.downcase.include?("arm")
                  arm_advanced = @title.split("ARM").last.tr('A-Za-z ()', '')
                  if arm_advanced.include?('/')
                    arm_advanced = arm_advanced.tr('/','-')
                  else
                    arm_advanced
                  end
                end
                # High Balance
                if p_name.include?("High Balance")
                  loan_size = "High-Balance"
                else
                  loan_size = "Conforming"
                end

                # Fha, va, usda
                if p_name.downcase.include?("fha")
                  fha = true
                end
                if p_name.downcase.include?("va")
                  va = true
                end
                if p_name.downcase.include?("usda")
                  usda = true
                end

                # loan_purpose
                if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                  loan_purpose = "Refinance"
                else
                  loan_purpose = "Purchase"
                end

                # lp and du
                if p_name.downcase.include?('du ')
                  du = true
                end
                if p_name.downcase.include?('lp ')
                  lp = true
                end

                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                @program_ids << @program.id
     
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (0..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    else
                      @block_hash[key][15*c_i] = value
                    end
                    @data << value
                  end

                  if @data.compact.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil?
                  @block_hash.values.first.shift
                end
                @program.update(term: term,loan_type: loan_type,conforming: conforming,freddie_mac: freddie_mac, fha: fha, va: va, usda: usda, fannie_mae: fannie_mae, loan_size: loan_size, loan_category: @sheet_name, arm_basic: arm_basic, arm_advanced: arm_advanced ,base_rate: @block_hash, loan_purpose: loan_purpose, du: du, lp: lp, arm_benchmark: arm_benchmark, arm_margin: arm_margin)

                # @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # adjustments
        previous_title = nil
        @another_title = nil
        modified_keys  = get_table_keys
        data = get_table_keys
        (49..95).each do |r|
          row = sheet_data.row(r)
          # r == 52 / 68 / 81 / 84 / 89 / 94
          rr = r #+ 1 # (r == 53) / (r == 69) / (r == 82) / (r == 90) / (r == 95)
          max_column_section = row.compact.count - 1
          (0..max_column_section).each do |max_column|
            cc = 3 + max_column * 9 # (2 / 11)
            begin
              @title = sheet_data.cell(r,cc)
              @block_hash = {}

              if(@title.eql?("All Conforming ARMs (Does not include DU Refi Plus)"))
                @title = "LoanSize/LoanType/FICO/LTV"
                @block_hash[@title] = {}
                @block_hash[@title]["Conforming"] = {}
                @block_hash[@title]["Conforming"]["ARM"] = {}
                @block_hash["PropertyType"] = {} unless @block_hash.has_key?("PropertyType")
                @block_hash["MiscAdjuster"] = {} unless @block_hash.has_key?("MiscAdjuster")
                @block_hash["LockDay"] = {} unless @block_hash.has_key?("LockDay")
                #  for high balance key
                @block_hash["LoanSize/LoanPurpose/RefinanceOption/LTV"] = {} unless @block_hash.has_key?("LoanSize/LoanPurpose/RefinanceOption/LTV")
                @block_hash["LoanSize/LoanPurpose/RefinanceOption/LTV"]["High-Balance"] = {} unless @block_hash["LoanSize/LoanPurpose/RefinanceOption/LTV"].has_key?("High Balance")
                @block_hash["LoanSize/LoanPurpose/RefinanceOption/LTV"]["High-Balance"]["Purchase"] = {} unless @block_hash["LoanSize/LoanPurpose/RefinanceOption/LTV"]["High-Balance"].has_key?("Purchase")
                @block_hash["LoanSize/RefinanceOption/LTV"] = {} unless @block_hash.has_key?("LoanSize/RefinanceOption/LTV")
                @block_hash["LoanSize/RefinanceOption/LTV"]["High-Balance"] = {} unless @block_hash["LoanSize/RefinanceOption/LTV"].has_key?("High Balance")

                key = ''
                another_key = ''
                keyOfHash = ''
                # for Misc Adjusters
                first_key   = ''
                second_key  = ''
                third_key   = ''
                final_key   = ''
                f1_key      = ''
                f2_key      = ''
                loan_amount = ''

                (0..47).each do |max_row|
                  @data = []
                  (7..19).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = index
                    value = sheet_data.cell(rrr,ccc)
                    # implementation of first key
                    if rrr.eql?(63)
                      # for 2nd table
                      @title = sheet_data.cell(rrr,cc)
                      unless @block_hash.has_key?(@title)
                        @block_hash[@title] = {}
                        @block_hash[@title]["Cash Out"] = {}
                      end
                    elsif rrr.eql?(68)
                      # for 3rd table
                      previous_title = @title = sheet_data.cell(rrr,ccc - 4) unless previous_title == @title
                      unless @block_hash.has_key?(@title)
                        @block_hash[@title] = {}
                        first_key  = "LPMI/RefinanceOption/LTV"
                        second_key = "LPMI/PropertyType/LTV"
                        final_key  = "LPMI/FICO/LTV"
                        @block_hash[@title][first_key] = {}
                        @block_hash[@title][first_key]["true"] = {}
                        @block_hash[@title][second_key] = {}
                        @block_hash[@title][second_key]["true"] = {}
                        @block_hash[@title][final_key] = {}
                        @block_hash[@title][final_key]["true"] = {}
                      end
                    elsif rrr.eql?(81) && index == 13
                      # for Loan Size Adjustments
                      @another_title = sheet_data.cell(rrr,index)
                      unless @block_hash.has_key?(@another_title)
                        @block_hash[@another_title] = {}
                      end
                    elsif rrr.eql?(81) && index == 7
                      # for Subordinate Financing
                      @title = sheet_data.cell(rrr,ccc - 4)
                      unless @block_hash.has_key?(@title)
                        @block_hash[@title] = {}
                        @block_hash[@title]["Subordinate Financing"] = {}
                      end
                    elsif rrr.eql?(87) && index.eql?(7)
                      # for Non Owner Occupied
                      @title = sheet_data.cell(rrr,ccc - 4)
                      @block_hash[@title] = {} unless @block_hash.has_key?(@title)
                      @block_hash[@title]["Non-Owner Occupied"] = {}
                    elsif rrr.eql?(91) && index.eql?(7)
                      # for Misc Adjusters
                      @title = "PropertyType/LTV"
                      @block_hash[@title] = {} unless @block_hash.has_key?(@title)
                    end

                    # implementation of second key inside first key
                    if rrr > 52 && rrr < 61 && index == 7 && value
                      # for 1st table
                      key = get_value(value)
                      @block_hash[@title]["Conforming"]["ARM"][key] = {} unless @block_hash[@title]["Conforming"]["ARM"].has_key?(key)
                    elsif rrr > 62 && rrr < 66 && index == 7 && value
                      # for 2nd table
                      key = get_value(value)
                      @block_hash[@title]["Cash Out"][key] = {} unless @block_hash[@title]["Cash Out"].has_key?(key)
                    elsif (68..79).to_a.include?(rrr) && index == 7 && value
                      if(68..72).to_a.include?(rrr) && index == 7 && value
                        key = sheet_data.cell(rrr,ccc - 2)
                        if "Rate & Term Refi".eql?(key)
                          key = "Rate & Term"
                          @block_hash[@title][first_key]["true"][key] = {}
                        else
                          @block_hash[@title][second_key]["true"][key] = {}
                        end
                      elsif(75..78).to_a.include?(rrr) && index == 7 && value
                        key = sheet_data.cell(rrr,ccc - 2)
                        key = key.eql?("<= 85") ? set_range(key) : get_value(key)
                        @block_hash[@title][final_key]["true"][key] = {}
                      end
                    else
                      if (81..84).to_a.include?(rrr) && ccc < 12
                        # for Subordinate Financing
                        if index.eql?(7)
                          key = sheet_data.cell(rrr,ccc - 2)
                          key = key.eql?("<=65") ? set_range(key) : get_value(key)
                          @block_hash[@title]["Subordinate Financing"][key] = {} unless @block_hash[@title]["Subordinate Financing"].has_key?(key)
                        elsif index.eql?(8)
                          keyOfHash = sheet_data.cell(rrr,ccc - 2)
                          keyOfHash = get_value(keyOfHash)
                          @block_hash[@title]["Subordinate Financing"][key][keyOfHash] = {}
                        end
                      end

                      if (rrr >= 81 && rrr <= 88) && index.eql?(15)
                        # for Loan Size Adjustments
                        loan_amount = get_value(sheet_data.cell(rrr, ccc))
                        @block_hash[@another_title][loan_amount] = {}
                      end

                      if [87,88,89].include?(rrr) && [7].include?(ccc)
                        #for Non Owner Occupied
                        diff_of_column = ccc - 6
                        hash_key = sheet_data.cell(rrr,(ccc -diff_of_column))
                        hash_key = hash_key.eql?("> 80") ? set_range(hash_key) : get_value(hash_key)
                        key = hash_key
                        @block_hash[@title]["Non-Owner Occupied"][hash_key] = {} if hash_key.present?
                      end

                      if [89,91].include?(rrr)
                        # for High Balance
                        if rrr.eql?(89) && index.eql?(16)
                          @block_hash["LoanSize/LoanPurpose/RefinanceOption/LTV"]["High-Balance"]["Purchase"]["Rate and Term"] = {} unless @block_hash["LoanSize/LoanPurpose/RefinanceOption/LTV"]["High-Balance"]["Purchase"].has_key?("Rate and Term")
                        elsif rrr.eql?(91) && index.eql?(16)
                          @block_hash["LoanSize/RefinanceOption/LTV"]["High-Balance"]["Cash Out"] = {} unless @block_hash["LoanSize/RefinanceOption/LTV"]["High-Balance"].has_key?("Cash Out")
                        end
                      end

                      if (91..95).to_a.include?(rrr)
                        # for Misc Adjusters
                        if index.eql?(7)
                          key = sheet_data.cell(rrr,ccc - 2)
                          if key && key.eql?("Attached Condo > 75 LTV")
                            first_key = key.split(" >")[0].split(" ").last
                            @block_hash[@title][first_key] = {}
                            second_key = key.split(" ")[3] + ".01"
                          elsif key && key.eql?(">90 LTV")
                            first_key  = key.split(" ")[1]
                            @block_hash[@title][first_key] = {}
                            second_key = key.split(">")[1].split(" ").first
                          end
                        end
                      end
                    end

                    # implementation of third key inside second key with value
                    if rrr > 52 && rrr < 61 && index > 7 && value
                      diff_of_row = rrr - 52
                      hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                      hash_key = get_value(hash_key)
                      if hash_key.present?
                        @block_hash[@title]["Conforming"]["ARM"][key][hash_key] = value unless @block_hash[@title]["Conforming"]["ARM"][key].has_key?(hash_key)
                      end
                    end

                    if rrr > 62 && rrr < 67 && index > 7 && value
                      # for 2nd table
                      hash_key = sheet_data.cell(rrr - (max_row + 1),ccc)
                      hash_key = get_value(hash_key)
                      if hash_key.present?
                        @block_hash[@title]["Cash Out"][key][hash_key] = value unless @block_hash[@title]["Cash Out"][key].has_key?(hash_key)
                      end
                    elsif rrr >= 68 && index >= 7 && value
                      if(rrr <= 78)
                        diff_of_row = rrr - 67
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = set_range(hash_key).nil? ? get_value(hash_key) : set_range(hash_key)
                        if (68..72).to_a.include?(rrr)
                          if(68..72).to_a.include?(rrr) && index >= 7 && value
                            if rrr.eql?(68)
                              @block_hash[@title][first_key]["true"][key][hash_key] = value
                            else
                              @block_hash[@title][second_key]["true"][key][hash_key] = value
                            end
                          end
                        elsif(75..78).to_a.include?(rrr) && index >= 7 && value
                          @block_hash[@title][final_key]["true"][key][hash_key] = value
                        end
                      elsif (81..88).to_a.include?(rrr) && ccc > 15 && value
                        #for Loan Size Adjustments
                        diff_of_row  = rrr - 80
                        loan_purpose = sheet_data.cell(rrr-diff_of_row,ccc)
                        @block_hash[@another_title][loan_amount][loan_purpose] = value
                      end

                      if (81..84).to_a.include?(rrr) && [9,10].include?(ccc)
                        # for Subordinate Financing
                        diff_of_row = rrr - 80
                        hash_key = sheet_data.cell((rrr - diff_of_row),ccc)
                        hash_key = hash_key.eql?(">= 720") ? set_range(hash_key) : get_value(hash_key)
                        @block_hash[@title]["Subordinate Financing"][key][keyOfHash][hash_key] = value if hash_key.present?
                      end

                      if [87,88,89].include?(rrr) && [9].include?(ccc)
                        @block_hash[@title]["Non-Owner Occupied"][key] = value if key && value
                      end

                      if (89..92).to_a.include?(rrr)
                        # for High Balance
                        ltv_value = set_range(sheet_data.cell(rrr,ccc - 1).split("LTV ")[-1]) if index.eql?(19)
                        if [89,90].include?(rrr) && index.eql?(19)
                          @block_hash["LoanSize/LoanPurpose/RefinanceOption/LTV"]["High-Balance"]["Purchase"]["Rate and Term"][ltv_value] = value
                        elsif [91,92].include?(rrr) && index.eql?(19)
                          @block_hash["LoanSize/RefinanceOption/LTV"]["High-Balance"]["Cash Out"][ltv_value] = value
                        end
                      end

                      if (91..96).to_a.include?(rrr) && ccc.eql?(9)
                        # for Misc Adjusters
                        if rrr.eql?(93)
                          @block_hash[@title][first_key][second_key] = value
                        elsif rrr.eql?(96)
                          ltv_value = sheet_data.cell(rrr, ccc - 4).split(">")[-1].split("LTV")[0] + " - #{Float::INFINITY}"
                          @block_hash[@title][first_key][ltv_value] = value
                        elsif [91,92].include?(rrr)
                          property_type_value = sheet_data.cell(rrr, ccc - 4)
                          @block_hash["PropertyType"][property_type_value] = value
                        elsif [94,95].include?(rrr)
                          misc_adjuster_value = sheet_data.cell(rrr, ccc - 4)
                          @block_hash["MiscAdjuster"][misc_adjuster_value] = value
                        end
                      end

                      if rrr.eql?(94) && ccc.eql?(17)
                        @block_hash["LockDay"]["30"] = value
                        @block_hash["LockDay"]["45"] = value
                        @block_hash["LockDay"]["60"] = value
                      end
                    end
                  end

                  @allAdjustments[@title] = @block_hash[@title]
                  if @another_title
                    @allAdjustments[@another_title] = @block_hash[@another_title]
                    @allAdjustments["LoanSize/LoanPurpose/RefinanceOption/LTV"] = @block_hash["LoanSize/LoanPurpose/RefinanceOption/LTV"]
                    @allAdjustments["LoanSize/RefinanceOption/LTV"] = @block_hash["LoanSize/RefinanceOption/LTV"]
                    @allAdjustments["PropertyType/LTV"] = @block_hash["PropertyType/LTV"]
                    @allAdjustments["PropertyType"] = @block_hash["PropertyType"]
                    @allAdjustments["MiscAdjuster"] = @block_hash["MiscAdjuster"]
                    @allAdjustments["LockDay"] = @block_hash["LockDay"]
                  end
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
              error_log.save
            end
          end
        end
      end
    end

    # rename first level keys
    @allAdjustments.keys.each do |key|
      data = get_table_keys
      if data[key]
        @allAdjustments[data[key]] = @allAdjustments.delete(key)
      end
    end

    # create adjustment for each program
    make_adjust(@allAdjustments, @sheet_name)
    create_program_association_with_adjustment(@sheet)
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  def homeready
    program_ids = []
    @allAdjustments = {}
    @xlsx.sheets.each do |sheet|
      if (sheet == "HomeReady")
        @sheet_name = sheet
        @sheet = sheet
        sheet_data = @xlsx.sheet(sheet)
        @adjustment_hash = {}
        @property_hash = {}
        @sub_hash = {}
        @loan_amount = {}
        primary_key = ''
        ltv_key = ''
        loan_key = ''
        (1..76).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet"))
            rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|

              cc = 3 + max_column*6 # (3 / 9 / 15) 3/8/13
              begin
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                # term
                term = nil
                program_heading = @title.split
                if @title.include?("10yr") || @title.include?("10 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("15yr") || @title.include?("15 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("20yr") || @title.include?("20 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("25yr") || @title.include?("25 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("30yr") || @title.include?("30 Yr")
                  term = @title.scan(/\d+/)[0]
                end

                # rate type
                if p_name.include?("Fixed")
                  loan_type = "Fixed"
                elsif p_name.include?("ARM")
                  loan_type = "ARM"
                  arm_benchmark = "LIBOR"
                  arm_margin = 0
                elsif p_name.include?("Floating")
                  loan_type = "Floating"
                elsif p_name.include?("Variable")
                  loan_type = "Variable"
                else
                  loan_type = "Fixed"
                end

                # rate arm
                if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM")
                  arm_basic = @title.scan(/\d+/)[0].to_i
                end

                # Arm Advanced
                if @title.downcase.include?("arm") 
                  arm_advanced = @title.split("ARM").last.tr('A-Z- () ','')
                  if arm_advanced.include?('/')
                    arm_advanced = arm_advanced.tr('/','-')
                  else
                    arm_advanced
                  end
                end

                if p_name.downcase.include?("homeready")
                  fannie_mae_product = "HomeReady"
                end

                # fannie_mae
                if p_name.downcase.include?("fnma")
                  fannie_mae = true
                end

                # loan_purpose
                if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                  loan_purpose = "Refinance"
                else
                  loan_purpose = "Purchase"
                end

                loan_size = "Conforming"

                # lp and du
                if p_name.downcase.include?('du ')
                  du = true
                end
                if p_name.downcase.include?('lp ')
                  lp = true
                end

                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_ids << @program.id
                @program.update(term: term,loan_type: loan_type, arm_basic: arm_basic,arm_advanced: arm_advanced, fannie_mae_product: fannie_mae_product, loan_category: @sheet_name, loan_purpose: loan_purpose, du: du, lp: lp, loan_size: loan_size,fannie_mae: fannie_mae, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (0..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    else
                      @block_hash[key][15*c_i] = value
                    end
                    @data << value
                  end

                  if @data.compact.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil?
                  @block_hash.values.first.shift
                end
                @block_hash.delete(nil)
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: row, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Adjustments
        (73..131).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(80)
          @lpmi = sheet_data.row(97)
          @fico = sheet_data.row(112)
          if row.compact.count >= 1
            (0..19).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Loan Level Price Adjustments"
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"] = {}
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"] = {}
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"]["Fixed"] = {}
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"]["Fixed"]["0-15"] = {}
                    @adjustment_hash["RefinanceOption/LTV/FICO"] = {}
                    @adjustment_hash["RefinanceOption/LTV/FICO"]["Cash Out"] = {}
                  end
                  if value == "LPMI Adjustments Applied after Cap"
                    @property_hash["LPMI/PropertyType/FICO"] = {}
                    @property_hash["LPMI/PropertyType/FICO"][true] = {}
                    @property_hash["LPMI/Term/LTV/FICO"] = {}
                    @property_hash["LPMI/Term/LTV/FICO"][true] = {}
                    @property_hash["LPMI/Term/LTV/FICO"][true]["0-20"] = {}
                    @property_hash["LPMI/Term/LTV/FICO"][true]["20-Inf"] = {}
                    @property_hash["PropertyType/LTV"] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"] = {}
                  end
                  if value == "Adjustments Applied after Cap"
                    @loan_amount["LoanAmount/LoanPurpose"] = {}
                  end
                  if r >= 81 && r <= 88 && cc == 7
                    primary_key = get_value value
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"]["Fixed"]["0-15"][primary_key] = {}
                  end
                  if r >= 81 && r <= 88 && cc >= 10 && cc <= 19
                    ltv_key = get_value @ltv_data[cc-2]
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"]["Fixed"]["0-15"][primary_key][ltv_key] = {}
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"]["Fixed"]["0-15"][primary_key][ltv_key] = value
                  end
                  if r >= 91 && r <= 93 && cc == 7
                    primary_key = get_value value
                    @adjustment_hash["RefinanceOption/LTV/FICO"]["Cash Out"][primary_key] = {}
                  end
                  if r >= 91 && r <= 93 && cc >= 10 && cc <= 19
                    ltv_key = get_value @ltv_data[cc-2]
                    @adjustment_hash["RefinanceOption/LTV/FICO"]["Cash Out"][primary_key][ltv_key] = {}
                    @adjustment_hash["RefinanceOption/LTV/FICO"]["Cash Out"][primary_key][ltv_key] = value
                  end
                  if r == 98 && cc == 5
                    @property_hash["LPMI/RefinanceOption/FICO"] = {}
                    @property_hash["LPMI/RefinanceOption/FICO"][true] = {}
                    @property_hash["LPMI/RefinanceOption/FICO"][true]["Rate and Term"] = {}
                  end
                  if r == 98 && cc >= 7 && cc <= 19
                    ltv_key = get_value @ltv_data[cc+1]
                    @property_hash["LPMI/RefinanceOption/FICO"][true]["Rate and Term"][ltv_key] = {}
                    @property_hash["LPMI/RefinanceOption/FICO"][true]["Rate and Term"][ltv_key] = value
                  end
                  if r >= 99 && r <= 100 && cc == 5
                    primary_key = value
                    @property_hash["LPMI/PropertyType/FICO"][true][primary_key] = {}
                  end
                  if r >= 99 && r <= 100 && cc >= 7 && cc <= 19
                    ltv_key = get_value @ltv_data[cc+1]
                    @property_hash["LPMI/PropertyType/FICO"][true][primary_key][ltv_key] = {}
                    @property_hash["LPMI/PropertyType/FICO"][true][primary_key][ltv_key] = value
                  end
                  if r >= 102 && r <= 105 && cc == 6
                    primary_key = get_value value
                    @property_hash["LPMI/Term/LTV/FICO"][true]["0-20"][primary_key] = {}
                  end
                  if r >= 102 && r <= 105 && cc >= 7 && cc <= 19
                    ltv_key = get_value @lpmi[cc-2]
                    @property_hash["LPMI/Term/LTV/FICO"][true]["0-20"][primary_key][ltv_key] = {}
                    @property_hash["LPMI/Term/LTV/FICO"][true]["0-20"][primary_key][ltv_key] = value
                  end
                  if r >= 107 && r <= 110 && cc == 6
                    primary_key = get_value value
                    @property_hash["LPMI/Term/LTV/FICO"][true]["20-Inf"][primary_key] = {}
                  end
                  if r >= 107 && r <= 110 && cc >= 7 && cc <= 19
                    ltv_key = get_value @lpmi[cc-2]
                    @property_hash["LPMI/Term/LTV/FICO"][true]["20-Inf"][primary_key][ltv_key] = {}
                    @property_hash["LPMI/Term/LTV/FICO"][true]["20-Inf"][primary_key][ltv_key] = value
                  end
                  if r >= 113 && r <= 118 && cc == 6
                    if value.downcase.include?('all')
                      primary_key = "0-Inf"
                    else
                      primary_key = get_value value
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key] = {}
                  end
                  if r >= 113 && r <= 118 && cc == 7
                    if value.downcase.include?('all')
                      ltv_key = "0-Inf"
                    else
                      ltv_key = get_value value
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key] = {}
                  end
                  if r >= 113 && r <= 118 && cc >= 10 && cc <= 12
                    cltv_key = get_value @fico[cc-2]
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key][cltv_key] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key][cltv_key] = value
                  end
                  if r == 119 && cc == 11
                    @property_hash["PropertyType"] = {}
                    @property_hash["PropertyType"]["2-4 Unit"] = {}
                    @property_hash["PropertyType"]["2-4 Unit"] = value
                  end
                  if r == 120 && cc == 11
                    @property_hash["PropertyType/Term/LTV"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = value
                  end
                  if r == 121 && cc == 11
                    @property_hash["PropertyType"]["Manufactured Home"] = {}
                    @property_hash["PropertyType"]["Manufactured Home"] = value
                  end
                  if r >= 122 && r <= 124 && cc == 7
                    primary_key = get_value value
                    @property_hash["PropertyType/LTV"][primary_key] = {}
                    cc = cc + 4
                    new_val = sheet_data.cell(r,cc)
                    @property_hash["PropertyType/LTV"][primary_key] = new_val
                  end
                  if r == 126 && cc == 8
                    @property_hash["LoanPurpose/LockDay"] = {}
                    @property_hash["LoanPurpose/LockDay"]["Purchase"] = {}
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["30"] = {}
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["45"] = {}
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["60"] = {}
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["30"] = value
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["45"] = value
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["60"] = value
                  end
                  if r >= 114 && r <= 120 && cc == 15
                    if value.downcase.include?("conforming")
                      loan_key = "300000-Inf"
                    else
                      loan_key = get_value value
                    end
                    @loan_amount["LoanAmount/LoanPurpose"][loan_key] = {}
                  end
                  if r >= 114 && r <= 120 && cc == 18
                    @loan_amount["LoanAmount/LoanPurpose"][loan_key]["Purchase"] = {}
                    @loan_amount["LoanAmount/LoanPurpose"][loan_key]["Purchase"] = value
                  end
                  if r >= 114 && r <= 120 && cc == 19
                    @loan_amount["LoanAmount/LoanPurpose"][loan_key]["Refinance"] = {}
                    @loan_amount["LoanAmount/LoanPurpose"][loan_key]["Refinance"] = value
                  end
                  if r == 120 && cc == 15 
                    @loan_amount["LoanSize/LoanPurpose"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["Conforming"] = {}
                  end
                  if r == 120 && cc == 18
                    @loan_amount["LoanSize/LoanPurpose"]["Conforming"]["Purchase"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["Conforming"]["Purchase"] = value
                  end
                  if r == 120 && cc == 19
                    @loan_amount["LoanSize/LoanPurpose"]["Conforming"]["Refinance"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["Conforming"]["Refinance"] = value
                  end
                  if r == 121 && cc == 18
                    @loan_amount["LoanSize/LoanPurpose"]["High-Balance"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["High-Balance"]["Purchase"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["High-Balance"]["Refinance"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["High-Balance"]["Purchase"] =value
                    cc = cc + 1
                    new_val = sheet_data.cell(r,cc)
                    @loan_amount["LoanSize/LoanPurpose"]["High-Balance"]["Refinance"] = new_val
                  end
                  if r == 122 && cc == 19
                    @loan_amount["MiscAdjuster/LoanPurpose"] = {}
                    @loan_amount["MiscAdjuster/LoanPurpose"]["CA Escrow Waiver (Full or Taxes Only)"] = {}
                    @loan_amount["MiscAdjuster/LoanPurpose"]["CA Escrow Waiver (Full or Taxes Only)"]["Refinance"] = {}
                    @loan_amount["MiscAdjuster/LoanPurpose"]["CA Escrow Waiver (Full or Taxes Only)"]["Refinance"] = value
                  end
                  if r == 123 && cc == 19
                    @loan_amount["PropertyType/LoanPurpose"] = {}
                    @loan_amount["PropertyType/LoanPurpose"]["Manufactured Home"] = {}
                    @loan_amount["PropertyType/LoanPurpose"]["Manufactured Home"]["Refinance"] = {}
                    @loan_amount["PropertyType/LoanPurpose"]["Manufactured Home"]["Refinance"] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@property_hash,@sub_hash,@loan_amount]
        create_adjust(adjustment,@sheet_name)
      end
    end
    create_program_association_with_adjustment(@sheet)
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  def homeready_hb
    program_ids = []
    @allAdjustments = {}
    @xlsx.sheets.each do |sheet|
      if (sheet == "HomeReady HB")
        @sheet_name = sheet
        @sheet = sheet
        sheet_data = @xlsx.sheet(sheet)
        @adjustment_hash = {}
        @property_hash = {}
        @sub_hash = {}
        @loan_amount = {}
        primary_key = ''
        ltv_key = ''
        loan_key = ''

        (1..75).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 3)) && (!row.compact.include?("California Wholesale Rate Sheet"))
            rr = r + 1 # (r == 8) / (r == 36) / (r == 56)
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 3 + max_column*6 
              begin
                @title = sheet_data.cell(r,cc)
                p_name = @title + " " + sheet
                 # term
                term = nil
                if @title.include?("10yr") || @title.include?("10 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("15yr") || @title.include?("15 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("20yr") || @title.include?("20 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("25yr") || @title.include?("25 Yr")
                  term = @title.scan(/\d+/)[0]
                elsif @title.include?("30yr") || @title.include?("30 Yr")
                  term = @title.scan(/\d+/)[0]
                end

                # rate type
                if p_name.include?("Fixed")
                  loan_type = "Fixed"
                elsif p_name.include?("ARM")
                  loan_type = "ARM"
                  arm_benchmark = "LIBOR"
                  arm_margin = 0
                elsif p_name.include?("Floating")
                  loan_type = "Floating"
                elsif p_name.include?("Variable")
                  loan_type = "Variable"
                else
                  loan_type = "Fixed"
                end

                # Arm Basic
                if @title.include?("5-1 ARM") || @title.include?("7-1 ARM") || @title.include?("10-1 ARM") || @title.include?("10-1 ARM") || @title.include?("5/1 ARM") || @title.include?("7/1 ARM") || @title.include?("10/1 ARM")
                  arm_basic = @title.scan(/\d+/)[0].to_i
                end
                # Arm Advanced
                if @title.downcase.include?("arm") 
                  arm_advanced = @title.split("ARM").last.tr('A-Z- () ','')
                  if arm_advanced.include?('/')
                    arm_advanced = arm_advanced.tr('/','-')
                  else
                    arm_advanced
                  end
                end

                if p_name.include?("Fannie Mae") || p_name.downcase.include?("fnma")
                  fannie_mae = true
                end

                fannie_mae_home_ready = false
                if p_name.include?("Fannie Mae HomeReady")
                  fannie_mae_home_ready = true
                end
                # Loan Size
                if p_name.downcase.include?("high balance") || p_name.downcase.include?("hb")
                  loan_size = "High-Balance"
                else
                  loan_size = "Conforming"
                end
                # Fannie_mae_product
                if p_name.downcase.include?("homeready")
                  fannie_mae_product = 'HomeReady'
                end

                # loan_purpose
                if p_name.downcase.include?('refinance') || p_name.downcase.include?('refi')
                  loan_purpose = "Refinance"
                else
                  loan_purpose = "Purchase"
                end

                # lp and du
                if p_name.downcase.include?('du ')
                  du = true
                end
                if p_name.downcase.include?('lp ')
                  lp = true
                end
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_ids << @program.id
                @program.update(term: term,loan_type: loan_type, arm_basic: arm_basic, arm_advanced: arm_advanced, fannie_mae: fannie_mae, fannie_mae_home_ready: fannie_mae_home_ready, loan_category: @sheet_name,loan_size: loan_size, fannie_mae_product: fannie_mae_product, loan_purpose: loan_purpose, du: du, lp: lp, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (0..50).each do |max_row|
                  @data = []
                  (0..4).each_with_index do |index, c_i|
                    rrr = rr + max_row
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    else
                      @block_hash[key][15*c_i] = value
                    end
                    @data << value
                  end

                  if @data.compact.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.values.first.keys.first.nil?
                  @block_hash.values.first.shift
                end
                @block_hash.delete(nil)
                @program.update(base_rate: @block_hash,loan_category: @sheet_name)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: @sheet_name, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Adjustments
        (77..130).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(79)
          @lpmi = sheet_data.row(96)
          @fico = sheet_data.row(111)
          if row.compact.count >= 1
            (0..19).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Loan Level Price Adjustments"
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"] = {}
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"] = {}
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"]["Fixed"] = {}
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"]["Fixed"]["0-15"] = {}
                    @adjustment_hash["RefinanceOption/LTV/FICO"] = {}
                    @adjustment_hash["RefinanceOption/LTV/FICO"]["Cash Out"] = {}
                  end
                  if value == "LPMI Adjustments Applied after Cap"
                    @property_hash["LPMI/PropertyType/FICO"] = {}
                    @property_hash["LPMI/PropertyType/FICO"][true] = {}
                    @property_hash["LPMI/Term/LTV/FICO"] = {}
                    @property_hash["LPMI/Term/LTV/FICO"][true] = {}
                    @property_hash["LPMI/Term/LTV/FICO"][true]["0-20"] = {}
                    @property_hash["LPMI/Term/LTV/FICO"][true]["20-Inf"] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"] = {}
                    @property_hash["LoanSize/LoanType/LTV"] = {}
                    @property_hash["LoanSize/LoanType/LTV"]["High-Balance"] = {}
                    @property_hash["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"] = {}
                  end
                  if value == "Adjustments Applied after Cap"
                    @loan_amount["LoanAmount/LoanPurpose"] = {}
                  end
                  if r >= 80 && r <= 87 && cc == 7
                    primary_key = get_value value
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"]["Fixed"]["0-15"][primary_key] = {}
                  end
                  if r >= 80 && r <= 87 && cc >= 10 && cc <= 19
                    ltv_key = get_value @ltv_data[cc-2]
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"]["Fixed"]["0-15"][primary_key][ltv_key] = {}
                    @adjustment_hash["LoanSize/LoanType/Term/LTV/FICO"]["Conforming"]["Fixed"]["0-15"][primary_key][ltv_key] = value
                  end
                  if r >= 90 && r <= 92 && cc == 7
                    primary_key = get_value value
                    @adjustment_hash["RefinanceOption/LTV/FICO"]["Cash Out"][primary_key] = {}
                  end
                  if r >= 90 && r <= 92 && cc >= 10 && cc <= 19
                    ltv_key = get_value @ltv_data[cc-2]
                    @adjustment_hash["RefinanceOption/LTV/FICO"]["Cash Out"][primary_key][ltv_key] = {}
                    @adjustment_hash["RefinanceOption/LTV/FICO"]["Cash Out"][primary_key][ltv_key] = value
                  end
                  if r == 97 && cc == 5
                    @property_hash["LPMI/RefinanceOption/FICO"] = {}
                    @property_hash["LPMI/RefinanceOption/FICO"][true] = {}
                    @property_hash["LPMI/RefinanceOption/FICO"][true]["Rate and Term"] = {}
                  end
                  if r == 97 && cc >= 7 && cc <= 19
                    ltv_key = get_value @ltv_data[cc+1]
                    @property_hash["LPMI/RefinanceOption/FICO"][true]["Rate and Term"][ltv_key] = {}
                    @property_hash["LPMI/RefinanceOption/FICO"][true]["Rate and Term"][ltv_key] = value
                  end
                  if r >= 98 && r <= 99 && cc == 5
                    primary_key = value
                    @property_hash["LPMI/PropertyType/FICO"][true][primary_key] = {}
                  end
                  if r >= 98 && r <= 99 && cc >= 7 && cc <= 19
                    ltv_key = get_value @ltv_data[cc+1]
                    @property_hash["LPMI/PropertyType/FICO"][true][primary_key][ltv_key] = {}
                    @property_hash["LPMI/PropertyType/FICO"][true][primary_key][ltv_key] = value
                  end
                  if r >= 101 && r <= 104 && cc == 6
                    primary_key = get_value value
                    @property_hash["LPMI/Term/LTV/FICO"][true]["0-20"][primary_key] = {}
                  end
                  if r >= 101 && r <= 104 && cc >= 7 && cc <= 19
                    ltv_key = get_value @lpmi[cc-2]
                    @property_hash["LPMI/Term/LTV/FICO"][true]["0-20"][primary_key][ltv_key] = {}
                    @property_hash["LPMI/Term/LTV/FICO"][true]["0-20"][primary_key][ltv_key] = value
                  end
                  if r >= 106 && r <= 109 && cc == 6
                    primary_key = get_value value
                    @property_hash["LPMI/Term/LTV/FICO"][true]["20-Inf"][primary_key] = {}
                  end
                  if r >= 106 && r <= 109 && cc >= 7 && cc <= 19
                    ltv_key = get_value @lpmi[cc-2]
                    @property_hash["LPMI/Term/LTV/FICO"][true]["20-Inf"][primary_key][ltv_key] = {}
                    @property_hash["LPMI/Term/LTV/FICO"][true]["20-Inf"][primary_key][ltv_key] = value
                  end
                  if r >= 112 && r <= 117 && cc == 6
                    if value.downcase.include?('all')
                      primary_key = "0-Inf"
                    else
                      primary_key = get_value value
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key] = {}
                  end
                  if r >= 112 && r <= 117 && cc == 7
                    if value.downcase.include?('all')
                      ltv_key = "0-Inf"
                    else
                      ltv_key = get_value value
                    end
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key] = {}
                  end
                  if r >= 112 && r <= 117 && cc >= 10 && cc <= 12
                    cltv_key = get_value @fico[cc-2]
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key][cltv_key] = {}
                    @sub_hash["FinancingType/LTV/CLTV/FICO"]["Subordinate Financing"][primary_key][ltv_key][cltv_key] = value
                  end
                  if r == 118 && cc == 11
                    @property_hash["PropertyType"] = {}
                    @property_hash["PropertyType"]["2-4 Unit"] = {}
                    @property_hash["PropertyType"]["2-4 Unit"] = value
                  end
                  if r == 119 && cc == 11
                    @property_hash["PropertyType/Term/LTV"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = {}
                    @property_hash["PropertyType/Term/LTV"]["Condo"]["15-Inf"]["75-Inf"] = value
                  end
                  if r == 120 && cc == 11
                    @property_hash["PropertyType"]["Manufactured Home"] = {}
                    @property_hash["PropertyType"]["Manufactured Home"] = value
                  end
                  if r == 121 && cc == 11
                    @property_hash["LoanSize/LoanType"] = {}
                    @property_hash["LoanSize/LoanType"]["High-Balance"] = {}
                    @property_hash["LoanSize/LoanType"]["High-Balance"]["Fixed"] = {}
                    @property_hash["LoanSize/LoanType"]["High-Balance"]["Fixed"] = value
                  end
                  if r >= 122 && r <= 123 && cc == 6
                    primary_key = get_value value
                    primary_key =  primary_key.gsub('--','-')
                    @property_hash["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"][primary_key] = {}
                    cc = cc + 5
                    new_val = sheet_data.cell(r,cc)
                    @property_hash["LoanSize/LoanType/LTV"]["High-Balance"]["ARM"][primary_key] = new_val
                  end
                  if r == 125 && cc == 8
                    @property_hash["LoanPurpose/LockDay"] = {}
                    @property_hash["LoanPurpose/LockDay"]["Purchase"] = {}
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["30"] = {}
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["45"] = {}
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["60"] = {}
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["30"] = value
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["45"] = value
                    @property_hash["LoanPurpose/LockDay"]["Purchase"]["60"] = value
                  end
                  if r >= 113 && r <= 119 && cc == 15
                    if value.downcase.include?("conforming")
                      loan_key = "300000-Inf"
                    else
                      loan_key = get_value value
                    end
                    @loan_amount["LoanAmount/LoanPurpose"][loan_key] = {}
                  end
                  if r >= 113 && r <= 119 && cc == 18
                    @loan_amount["LoanAmount/LoanPurpose"][loan_key]["Purchase"] = {}
                    @loan_amount["LoanAmount/LoanPurpose"][loan_key]["Purchase"] = value
                  end
                  if r >= 113 && r <= 119 && cc == 19
                    @loan_amount["LoanAmount/LoanPurpose"][loan_key]["Refinance"] = {}
                    @loan_amount["LoanAmount/LoanPurpose"][loan_key]["Refinance"] = value
                  end
                  if r == 119 && cc == 15 
                    @loan_amount["LoanSize/LoanPurpose"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["Conforming"] = {}
                  end
                  if r == 119 && cc == 18
                    @loan_amount["LoanSize/LoanPurpose"]["Conforming"]["Purchase"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["Conforming"]["Purchase"] = value
                  end
                  if r == 119 && cc == 19
                    @loan_amount["LoanSize/LoanPurpose"]["Conforming"]["Refinance"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["Conforming"]["Refinance"] = value
                  end
                  if r == 120 && cc == 18
                    @loan_amount["LoanSize/LoanPurpose"]["High-Balance"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["High-Balance"]["Purchase"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["High-Balance"]["Refinance"] = {}
                    @loan_amount["LoanSize/LoanPurpose"]["High-Balance"]["Purchase"] =value
                    cc = cc + 1
                    new_val = sheet_data.cell(r,cc)
                    @loan_amount["LoanSize/LoanPurpose"]["High-Balance"]["Refinance"] = new_val
                  end
                  if r == 121 && cc == 19
                    @loan_amount["MiscAdjuster/LoanPurpose"] = {}
                    @loan_amount["MiscAdjuster/LoanPurpose"]["CA Escrow Waiver (Full or Taxes Only)"] = {}
                    @loan_amount["MiscAdjuster/LoanPurpose"]["CA Escrow Waiver (Full or Taxes Only)"]["Refinance"] = {}
                    @loan_amount["MiscAdjuster/LoanPurpose"]["CA Escrow Waiver (Full or Taxes Only)"]["Refinance"] = value
                  end
                  if r == 122 && cc == 19
                    @loan_amount["PropertyType/LoanPurpose"] = {}
                    @loan_amount["PropertyType/LoanPurpose"]["Manufactured Home"] = {}
                    @loan_amount["PropertyType/LoanPurpose"]["Manufactured Home"]["Refinance"] = {}
                    @loan_amount["PropertyType/LoanPurpose"]["Manufactured Home"]["Refinance"] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@property_hash,@sub_hash,@loan_amount]
        create_adjust(adjustment,@sheet_name)
      end
    end
    redirect_to programs_ob_new_rez_wholesale5806_path(@sheet_obj)
  end

  def programs
    @programs = @sheet_obj.programs
  end

  def single_program
  end

  private

  def read_sheet
  	file = File.join(Rails.root + "other_sheets", 'OB_NewRez_Wholesale5806.xls')
    @xlsx = Roo::Spreadsheet.open(file)
  end

  def check_sheet_empty
    action =  params[:action]
    sheet_data = @xlsx.sheet(action) rescue @xlsx.sheet(action.upcase) rescue @xlsx.sheet(action.downcase) rescue @xlsx.sheet(action.capitalize)

    if sheet_data.first_row.blank?
      @msg = "Sheet is empty."
      redirect_to ob_new_rez_wholesale5806_index_path
    end
  end

  def get_sheet
    @sheet_obj = Sheet.find(params[:id])
  end

  def get_program
    @program = Program.find(params[:id])
  end

  def get_bank
    @bank = Bank.find(params[:id])
  end

  def get_titles
    return ["FICO/LTV Adjustments - Loan Amount ≤ $1MM", "State Adjustments", "FICO/LTV Adjustments - Loan Amount > $1MM", "Feature Adjustments", "Max Price"]
  end

  def all_lp
    data = Adjustment::ALL_IP

    return data
  end

  def high_bal_adjustment
    data = Adjustment::HIGH_BALANCE_ADJUSTMENT
    return data
  end

  def jumbo_series_i_adjustment
      data = Adjustment::JUMBO_SERIES_I_ADJUSTMENT
    return data
  end

  def dream_big_adjustment
    data = Adjustment::DREAM_BIG_ADJUSTMENT

    return data
  end

  def table_data
    hash_keys = {
      "FICO/LTV Adjustments" => "LoanAmount/FICO/LTV",
      "Feature Adjustments"  => "Feature/LTV",
      "State Adjustments" => "State",
      "Max Price" => "Max Price"
    }

    return hash_keys
  end

  # def make_adjust(block_hash, p_ids)
  #   begin
  #     adjustment = Adjustment.create(data: block_hash)

  #     # assign for all projects
  #     p_ids.each do |id|
  #       program = Program.find(id)
  #       program.adjustments << adjustment
  #     end
  #   rescue Exception => e
  #     puts e
  #   end
  # end

  def make_adjust(block_hash, sheet)
    block_hash.keys.each do |key|
      unless ["Lender Paid MI Adj.", "Term/LTV/FICO"].include?(key)
        hash = {}
        hash[key] = block_hash[key]
        Adjustment.create(data: hash,loan_category: @sheet_name)
      else
        unless block_hash[key].empty?
          block_hash[key].keys.each do |s_key|
            h1 = {}
            h1[s_key] = block_hash[key][s_key]
            Adjustment.create(data: h1,loan_category: @sheet_name)
          end
        end
      end
    end
  end

  def find_key(title)
    if title.eql?("FICO/LTV Adjustments - Loan Amount ≤ $1MM") or title.eql?("FICO/LTV Adjustments - Loan Amount > $1MM")
      base_key = table_data[@title.split(" -").first]
    else
      base_key = table_data[@title]
    end

    return base_key
  end

  def get_table_keys
    table_keys = Adjustment::MAIN_KEYS
    return table_keys
  end

  # def get_value value1
  #   if value1.present?
  #     if (!value1.include?("$")) && ((value1.include?("≤")) || (value1.include?("<")))
  #       value1 = "0 - " + value1.split().last
  #     elsif (value1.include?("-")) && !value1.include?("$")
  #       # value1 = value1.split("-").first.squish
  #       value1 = value1
  #     elsif (value1.include?("≥"))
  #       value1 = value1.split("≥").last.squish
  #     elsif (value1.include?(">="))
  #       value1.split(">=").last.squish
  #     elsif (value1.include?(">"))
  #       value1.split(">").last.squish
  #     elsif (value1.include?("+"))
  #       value1.split("+").first
  #     elsif value1.include?("$") && !value1.include?("-")
  #       "0-" + value1.split("$").last.gsub(/[\s,]/ ,"").squish
  #     elsif value1.include?("$") && value1.include?("-")
  #       if !value1.split(" - ").last.eql?("Conforming Limit")
  #         value1 = value1.split("$")[1].gsub(/[\s,]/ ,"") + value1.split("$")[-1].gsub(/[\s,]/ ,"")
  #       else
  #         value1 = value1.split(" - ").first.gsub("$", "").gsub(",", "") + "-" + value1.split(" - ").last.squish
  #       end
  #     else
  #       value1
  #     end
  #   end
  # end

  def get_value value1
    if value1.present?
      if value1.include?("<=") || value1.include?("<") || value1.include?("≤")
        value1 = "0-"+value1.split("<=").last.tr('A-Za-z%$><=≤, ','')
        value1 = value1.tr('–','-')
      elsif value1.include?(">") || value1.include?("+")
        value1 = value1.split(">").last.tr('A-Za-z+ ','')+"-Inf"
        value1 = value1.tr('–','-')
      elsif value1.include?("≥")
        value1 = value1.split("≥").last.tr('A-Za-z$, ','')+"-Inf"
        value1 = value1.tr('–','-')
      else
        value1 = value1.tr('$, ','')
        value1 = value1.tr('–','-')
      end
    end
  end

  def set_range value
    if value.split()[0].eql?("≤") || value.split()[0].eql?("<=") then
      value = "0-" + value.split()[1]
    elsif [">","≥",">=", "+"].include?(value.split()[0]) then
      value.split()[1] + "-#{Float::INFINITY}"
    elsif [">","≥",">=", "+"].include?(value.split("")[-1])
      value.split("+")[0] + "-#{Float::INFINITY}"
    elsif value.include?(">")
      value.split(">")[-1] + "-#{Float::INFINITY}"
    elsif value.include?("<=")
      value = "0-" + value.split("<=")[-1]
    end
  end

  def convert_range value
    if value.include?("≤") && value.include?("MM")
      value = "0-"+value.split("MM")[0].split("$")[-1] + "000000"
    elsif value.include?("-") && value.include?("MM") && value.include?("$")
      if value.split(" - ")[-1].split("MM")[0].split("$")[-1].include?(".")
        value = value.split(" - ")[0].split("MM")[0].split("$")[-1] + "000000" + "-" + value.split(" - ")[-1].split("MM")[0].split("$")[-1].gsub(".", "") + "000000"
      else
        value = value.split(" - ")[0].split("MM")[0].split("$")[-1].gsub(".", "") + "000000" + "-" + value.split(" - ")[-1].split("MM")[0].split("$")[-1] + "000000" if value.split(" - ")[0].split("MM")[0].split("$")[-1].include?(".")
      end
    end

    return value
  end

  def get_main_key heading
    heading.split(" ").each do |data|
      data.gsub!("#{data}", 'LoanType') if data.eql?("Fixed")
      data.gsub!("#{data}", 'Term') if data.eql?("terms")
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

  def create_adjust(block_hash, sheet)
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
end
