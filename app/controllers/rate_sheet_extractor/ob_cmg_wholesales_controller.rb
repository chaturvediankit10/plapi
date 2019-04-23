class RateSheetExtractor::ObCmgWholesalesController < RateSheetExtractor::ApplicationController
  before_action :read_sheet, only: [:index,:gov, :agency, :durp, :oa, :jumbo_700,:jumbo_7200_6700, :jumbo_6600, :jumbo_6200, :jumbo_7600, :jumbo_6800, :jumbo_6900_7900, :programs, :jumbo_6400,:mi_llpas]
  before_action :get_sheet, only: [:gov, :agency, :durp, :oa, :jumbo_700,:jumbo_7200_6700, :jumbo_6600, :jumbo_6200, :jumbo_7600, :jumbo_6800, :jumbo_6900_7900, :programs, :jumbo_6400, :mi_llpas, :program_property]
  before_action :get_program, only: [:single_program, :program_property]

  def index
    begin
      @xlsx.sheets.each do |sheet|
        if (sheet == "AGENCY")
          headers = ["Phone", "General Contacts", "Mortgagee Clause (Wholesale)"]
          @name = "CMG Financial"
          @bank = Bank.find_or_create_by(name: @name)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
      end
    rescue
      # the required headers are not all present
    end
  end

  def agencyllpas
    redirect_to error_page_ob_new_rez_wholesale5806_path
  end

  def aio
    redirect_to error_page_ob_new_rez_wholesale5806_path
  end

  def gov
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "GOV")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        first_key = ''
        first_key1 = ''
        first_key2 = ''
        second_key = ''
        second_key1 = ''
        second_key2 = ''
        state_key = ''
        cc = ''
        ccc = ''
        cltv_key = ''
        k_val = ''
        key_val = ''
        value1 = ''
        @block_hash = {}
        @data_hash = {}
        @misc_hash = {}
        @state_hash = {}
        adj_key = []
        (10..60).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_property sheet

                @programs_ids << @program.id
                @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..3).each_with_index do |index, c_i|
                    rrr = rr + max_row -1
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)

                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      elsif (c_i == 1)
                        @block_hash[key][21] = value
                      elsif (c_i == 2)
                        @block_hash[key][30] = value
                      elsif (c_i == 3)
                        @block_hash[key][45] = value
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
                @program.update(base_rate: @block_hash)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Adjustments
        (67..87).each do |r|
          row = sheet_data.row(r)
          @key_data = sheet_data.row(40)
          if (row.compact.count >= 1)
            (0..7).each do |max_column|
              cc = max_column
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "GOVERNMENT ADJUSTMENTS"
                    @data_hash["FICO"] = {}
                    @data_hash["LoanAmount"] = {}
                    @data_hash["PropertyType"] = {}
                    @data_hash["LoanSize/Term"] = {}
                    @data_hash["LoanSize/Term"]["High-Balance"] = {}
                  end
                  if r >= 70 && r <= 76 && cc == 1
                    if value.include?("-")
                      secondary_key = value.tr('A-Z+ ' , '')
                    elsif value.include?("+")
                      secondary_key = value.tr('A-Z+ ','')+"-Inf"
                    end
                    ccc = cc + 6
                    c_val = sheet_data.cell(r,ccc)
                    @data_hash["FICO"][secondary_key] = c_val
                  end
                  if r == 77 && cc == 1
                    ccc = cc +6
                    c_val = sheet_data.cell(r,ccc)
                    @data_hash["One Score"] = {}
                    @data_hash["One Score"] = c_val
                  end
                  if r >= 78 && r <= 82 && cc == 1
                    if value.include?("Conf Limit")
                      secondary_key = value.tr('A-Za-z<>=$, ','') + "Inf"
                    elsif value.include?("-")
                      secondary_key = value.tr('A-Za-z<>=$, ','')
                    else
                      secondary_key = get_value value
                    end
                    @data_hash["LoanAmount"][secondary_key] = {}
                    ccc = cc + 6
                    c_val = sheet_data.cell(r,ccc)
                    @data_hash["LoanAmount"][secondary_key] = c_val
                  end
                  if r >= 83 && r <= 85 && cc == 1
                    if value.downcase.include?('units')
                      secondary_key = value.split('s').first
                    else
                      secondary_key = value
                    end
                    @data_hash["PropertyType"][secondary_key] = {}
                    ccc = cc + 6
                    c_val = sheet_data.cell(r,ccc)
                    @data_hash["PropertyType"][secondary_key] = c_val
                  end
                  if r == 86 && cc == 1
                    @data_hash["LoanSize/Term"]["High-Balance"]["15"] = {}
                    @data_hash["LoanSize/Term"]["High-Balance"]["20"] = {}
                    ccc = cc + 6
                    c_val = sheet_data.cell(r,ccc)
                    @data_hash["LoanSize/Term"]["High-Balance"]["15"] = c_val
                    @data_hash["LoanSize/Term"]["High-Balance"]["20"] = c_val
                  end
                  if r == 87 && cc == 1
                    @data_hash["LoanSize/LoanType"] = {}
                    @data_hash["LoanSize/LoanType"]["High-Balance"] = {}
                    @data_hash["LoanSize/LoanType"]["High-Balance"]["ARM"] = {}
                    ccc = cc + 6
                    c_val = sheet_data.cell(r,ccc)
                    @data_hash["LoanSize/LoanType"]["High-Balance"]["ARM"] = c_val
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end

            (10..16).each do |max_column|
              cc = max_column
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "MISCELLANEOUS"
                    @misc_hash["MiscAdjuster/LockDay"] = {}
                    @misc_hash["MiscAdjuster/LockDay"]["Miscellaneous"] = {}
                    @misc_hash["MiscAdjuster/LockDay"]["Miscellaneous"]["60"] = {}
                    @misc_hash["MiscAdjuster/VA/RefinanceOption"] = {}
                    @misc_hash["MiscAdjuster/VA/RefinanceOption"]["Miscellaneous"] = {}
                    @misc_hash["MiscAdjuster/VA/RefinanceOption"]["Miscellaneous"]["true"] = {}
                  end
                  if r == 70 && cc == 10
                    ccc = cc + 6
                    c_val = sheet_data.cell(r,ccc)
                    @misc_hash["MiscAdjuster/LockDay"]["Miscellaneous"]["60"] = c_val
                  end
                  if r == 71 && cc == 10
                    @misc_hash["MiscAdjuster/FHA/Streamline"] = {}
                    @misc_hash["MiscAdjuster/FHA/Streamline"]["Miscellaneous"] = {}
                    @misc_hash["MiscAdjuster/FHA/Streamline"]["Miscellaneous"]["true"] = {}
                    @misc_hash["MiscAdjuster/FHA/Streamline"]["Miscellaneous"]["true"]["true"] = {}
                    ccc = cc + 6
                    c_val = sheet_data.cell(r,ccc)
                    @misc_hash["MiscAdjuster/FHA/Streamline"]["Miscellaneous"]["true"]["true"] = c_val
                  end
                  if r >= 72 && r <= 74 && cc == 10
                    if value.include?("Non-IRRRL")
                      secondary_key = "Non-IRRRL"
                    else
                      secondary_key = get_value value
                    end
                    @misc_hash["MiscAdjuster/VA/RefinanceOption"]["Miscellaneous"]["true"][secondary_key] = {}
                    ccc = cc + 6
                    c_val = sheet_data.cell(r,ccc)
                    @misc_hash["MiscAdjuster/VA/RefinanceOption"]["Miscellaneous"]["true"][secondary_key] = c_val
                  end
                  if r == 75 && cc == 10
                    @misc_hash["MiscAdjuster/RefinanceOption/VA/FICO"] = {}
                    @misc_hash["MiscAdjuster/RefinanceOption/VA/FICO"]["Miscellaneous"] = {}
                    @misc_hash["MiscAdjuster/RefinanceOption/VA/FICO"]["Miscellaneous"]["Cash Out"] = {}
                    @misc_hash["MiscAdjuster/RefinanceOption/VA/FICO"]["Miscellaneous"]["Cash Out"]["true"] = {}
                    ccc = cc + 6
                    c_val = sheet_data.cell(r,ccc)
                    @misc_hash["MiscAdjuster/RefinanceOption/VA/FICO"]["Miscellaneous"]["Cash Out"]["true"] = c_val
                  end
                  if r == 76 && cc == 10
                    @misc_hash["MiscAdjuster/LoanType"] = {}
                    @misc_hash["MiscAdjuster/LoanType"]["Miscellaneous"] = {}
                    @misc_hash["MiscAdjuster/LoanType"]["Miscellaneous"]["Fixed"] = {}
                    ccc = cc + 6
                    c_val = sheet_data.cell(r,ccc)
                    @misc_hash["MiscAdjuster/LoanType"]["Miscellaneous"]["Fixed"] = c_val
                  end
                  if r == 77 && cc == 10
                    @misc_hash["MiscAdjuster/State"] = {}
                    @misc_hash["MiscAdjuster/State"]["Miscellaneous"] = {}
                    @misc_hash["MiscAdjuster/State"]["Miscellaneous"]["NY"] = {}
                    ccc = cc + 6
                    c_val = sheet_data.cell(r,ccc)
                    @misc_hash["MiscAdjuster/State"]["Miscellaneous"]["NY"] = c_val
                  end

                  if value == "STATE ADJUSTMENTS"
                    @state_hash["State"] = {}
                  end

                  if r >= 80 && r <= 87 && cc == 11
                    adj_key = value.split(', ')
                    adj_key.each do |f_key|
                      key_val = f_key
                      ccc = cc + 5
                      k_val = sheet_data.cell(r,ccc)
                      @state_hash["State"][key_val] = k_val
                    end
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@data_hash,@misc_hash,@state_hash]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def agency
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      # Programs
      if (sheet == "AGENCY")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        (10..87).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1

              @title = sheet_data.cell(r,cc)
              if @title.present? && @title != "2.250% MARGIN - 2/2/6 CAPS - 1 YR LIBOR" && @title != "2.250% MARGIN - 5/2/5 CAPS - 1 YR LIBOR"
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_property sheet
                @programs_ids << @program.id
                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..17).each do |max_row|
                  @data = []
                  (0..3).each_with_index do |index, c_i|
                    rrr = rr + max_row -1
                    ccc = cc + c_i
                    begin
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        elsif (c_i == 1)
                          @block_hash[key][21] = value
                        elsif (c_i == 2)
                          @block_hash[key][30] = value
                        elsif (c_i == 3)
                          @block_hash[key][45] = value
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
              end
              if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                @block_hash.shift
              end
              @program.update(base_rate: @block_hash)
            end
          end
        end
      end

      # Adjustments
      if (sheet == "AGENCYLLPAS")
        sheet_data = @xlsx.sheet(sheet)
        @ltv_data = []
        @cltv_data = []
        @adjustment_hash = {}
        @adjustment_fico = {}
        @cashout_adjustment = {}
        @subordinate_hash = {}
        @adjustment_cap = {}
        @loan_adjustment = {}
        @state_adjustments = {}
        @other_adjustment = {}
        @lpmi_hash = {}
        @lpmi_adj = {}
        @home_ready = {}
        @home_possible = {}
        @property_hash = {}
        primary_key = ''
        primary_key1 = ''
        primary_key2 = ''
        primary_key3 = ''
        first_key    = ''
        secondary_key = ''
        secondary_key1 = ''
        ltv_key = ''
        cltv_key = ''
        cash_key = ''
        key = ''
        term_key = ''
        cash_key1 = ''
        (8..93).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(10)
          @cltv_data = sheet_data.row(38)
          @lpmi_data = sheet_data.row(70)
          (0..16).each do |cc|
            value = sheet_data.cell(r,cc)
            value = value

            begin
              if value.present?
                if value == "AGENCY FIXED AND ARM ADJUSTMENTS"
                  secondary_key = "Fixed"
                  primary_key1 = "ARM"
                  term_key = "15-Inf"
                  primary_key = "LoanType/PropertyType/LTV"
                  @adjustment_hash[primary_key] = {}
                  primary_key2 = "LoanType/Term/FICO/LTV"
                  @adjustment_fico[primary_key2] = {}
                  @adjustment_fico[primary_key2][secondary_key] = {}
                  @adjustment_fico[primary_key2][secondary_key][term_key] = {}
                  @adjustment_fico[primary_key2][primary_key1] = {}
                  @adjustment_fico[primary_key2][primary_key1][term_key] = {}
                  cash_key = "LoanType/RefinanceOption/FICO/LTV"
                  cash_key1 = "Cash Out"
                  @cashout_adjustment[cash_key] = {}
                  @cashout_adjustment[cash_key][secondary_key] = {}
                  @cashout_adjustment[cash_key][primary_key1] = {}
                  @cashout_adjustment[cash_key][secondary_key][cash_key1] = {}
                  @cashout_adjustment[cash_key][primary_key1][cash_key1] = {}
                end
                if value == "SUBORDINATE FINANCING"
                  primary_key = "FinancingType/LTV/CLTV/FICO"
                  primary_key3 = "Subordinate Financing"
                  @subordinate_hash[primary_key] = {}
                  @subordinate_hash[primary_key][primary_key3] = {}
                end
                if value == "HOMEREADY ADJUSTMENT CAPS*"
                  primary_key = "FannieMaeProduct/FICO/LTV"
                  @adjustment_cap[primary_key] = {}
                  @adjustment_cap[primary_key]["HomeReady"] = {}
                end
                if value == "HOME POSSIBLE AND HOME POSSIBLE ADVANTAGE ADJUSTMENT CAPS*"
                  primary_key1 = "FreddieMacProduct/FICO/LTV"
                  @adjustment_cap[primary_key1] = {}
                  @adjustment_cap[primary_key1]["HomePossible"] = {}
                end
                if value == "LENDER PAID MI"
                  primary_key = "LPMI/LoanType/LTV/FICO"
                  cash_key = "LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"
                  first_key = "LPMI/LoanType/Term/LTV/FICO"
                  @lpmi_hash[primary_key] = {}
                  @lpmi_adj[primary_key] = {}
                  @lpmi_adj[first_key] = {}
                  @home_ready[cash_key] = {}
                  @home_possible[cash_key] = {}
                end
                if value == "LPMI (in addition to adjustments above)"
                  primary_key = "LPMI/RefinanceOption/FICO"
                  primary_key1 = "LPMI/PropertyType/FICO"
                  @property_hash[primary_key] = {}
                  @property_hash[primary_key1] = {}
                  @property_hash[primary_key]["true"] = {}
                  @property_hash[primary_key1]["true"] = {}
                end
                # AGENCY FIXED AND ARM ADJUSTMENTS
                if r == 11 && cc == 1
                  secondary_key = "Fixed"
                  primary_key1 = "ARM"
                  secondary_key1 = "Investment Property"
                  @adjustment_hash[primary_key][secondary_key] = {}
                  @adjustment_hash[primary_key][secondary_key][secondary_key1] = {}
                  @adjustment_hash[primary_key][primary_key1] = {}
                  @adjustment_hash[primary_key][primary_key1][secondary_key1] = {}
                end
                if r == 12 && cc == 1
                  secondary_key1 = "2nd Home"
                  @adjustment_hash[primary_key][secondary_key][secondary_key1] = {}
                  @adjustment_hash[primary_key][primary_key1][secondary_key1] = {}
                end
                if r == 13 && cc == 1
                  secondary_key1 = "2 Unit"
                  @adjustment_hash[primary_key][secondary_key][secondary_key1] = {}
                  @adjustment_hash[primary_key][primary_key1][secondary_key1] = {}
                end
                if r == 17 && cc == 1
                  secondary_key1 = "Manufactured Home"
                  @adjustment_hash[primary_key][secondary_key][secondary_key1] = {}
                  @adjustment_hash[primary_key][primary_key1][secondary_key1] = {}
                end
                if r == 14 && cc == 1
                  secondary_key1 = "3-4 Unit"
                  @adjustment_hash[primary_key][secondary_key][secondary_key1] = {}
                end
                if r == 14 && cc >= 9 && cc <= 16
                  ltv_key = get_value @ltv_data[cc-1]
                  @adjustment_hash[primary_key][secondary_key][secondary_key1][ltv_key] = {}
                  @adjustment_hash[primary_key][secondary_key][secondary_key1][ltv_key] = value
                end
                if r == 15 && cc == 1
                  secondary_key1 = "3-4 Unit"
                  @adjustment_hash[primary_key][primary_key1][secondary_key1] = {}
                end
                if r == 15 && cc >= 9 && cc <= 16
                  ltv_key = get_value @ltv_data[cc-1]
                  @adjustment_hash[primary_key][primary_key1][secondary_key1][ltv_key] = {}
                  @adjustment_hash[primary_key][primary_key1][secondary_key1][ltv_key] = value
                end
                if r == 16 && cc == 1
                  @adjustment_hash["LoanType/PropertyType/Term/LTV"] = {}
                  @adjustment_hash["LoanType/PropertyType/Term/LTV"]["Fixed"] = {}
                  @adjustment_hash["LoanType/PropertyType/Term/LTV"]["Fixed"]["Condo"] = {}
                  @adjustment_hash["LoanType/PropertyType/Term/LTV"]["Fixed"]["Condo"]["15-Inf"] = {}

                  @adjustment_hash["LoanType/PropertyType/Term/LTV"]["ARM"] = {}
                  @adjustment_hash["LoanType/PropertyType/Term/LTV"]["ARM"]["Condo"] = {}
                  @adjustment_hash["LoanType/PropertyType/Term/LTV"]["ARM"]["Condo"]["15-Inf"] = {}
                end
                if r == 16 && cc >= 9 && cc <= 16
                  ltv_key = get_value @ltv_data[cc-1]
                  @adjustment_hash["LoanType/PropertyType/Term/LTV"]["Fixed"]["Condo"]["15-Inf"][ltv_key] = {}
                  @adjustment_hash["LoanType/PropertyType/Term/LTV"]["ARM"]["Condo"]["15-Inf"][ltv_key] = {}
                  @adjustment_hash["LoanType/PropertyType/Term/LTV"]["Fixed"]["Condo"]["15-Inf"][ltv_key] = value
                  @adjustment_hash["LoanType/PropertyType/Term/LTV"]["ARM"]["Condo"]["15-Inf"][ltv_key] = value
                end
                if r >= 11 && r <= 17 && r != 14 && r != 15 && r != 16 && cc >= 9 && cc <= 16
                  ltv_key = get_value @ltv_data[cc-1]
                  @adjustment_hash[primary_key][secondary_key][secondary_key1][ltv_key] = {}
                  @adjustment_hash[primary_key][secondary_key][secondary_key1][ltv_key] = value
                  @adjustment_hash[primary_key][primary_key1][secondary_key1][ltv_key] = {}
                  @adjustment_hash[primary_key][primary_key1][secondary_key1][ltv_key] = value
                end
                # Fico Adjustments
                if r >= 18 && r <= 24 && cc == 1
                  if value.include?(">")
                    cltv_key = value.split(">").last.split("(N/A for 15 Year Term or less)").first.tr('= ' , '') + "-Inf"
                  elsif value.include?("FICO")
                    cltv_key = value.split("(N/A for 15 Year Term or less)").first.tr('FICO ', '')
                  end
                  @adjustment_fico[primary_key2][secondary_key][term_key][cltv_key] = {}
                  @adjustment_fico[primary_key2][primary_key1][term_key][cltv_key] = {}
                end
                if r >= 18 && r <= 24 && cc >= 9 && cc <= 16
                  ltv_key = get_value @ltv_data[cc-1]
                  @adjustment_fico[primary_key2][secondary_key][term_key][cltv_key][ltv_key] = {}
                  @adjustment_fico[primary_key2][secondary_key][term_key][cltv_key][ltv_key] = value
                  @adjustment_fico[primary_key2][primary_key1][term_key][cltv_key][ltv_key] = {}
                  @adjustment_fico[primary_key2][primary_key1][term_key][cltv_key][ltv_key] = value
                end

                # cashout_adjustment
                if r >= 25 && r <= 31 && cc == 1
                  if value.include?(">")
                    cltv_key = value.split(">").last.tr('= ' , '') + "-Inf"
                  elsif value.include?("FICO")
                    cltv_key = value.split("FICO").last.tr(' ', '')
                  end
                  @cashout_adjustment[cash_key][secondary_key][cash_key1][cltv_key] = {}
                  @cashout_adjustment[cash_key][primary_key1][cash_key1][cltv_key] = {}
                end
                if r >= 25 && r <= 31 && cc >= 9 && cc <= 16
                  ltv_key = get_value @ltv_data[cc-1]
                  @cashout_adjustment[cash_key][secondary_key][cash_key1][cltv_key][ltv_key] = {}
                  @cashout_adjustment[cash_key][secondary_key][cash_key1][cltv_key][ltv_key] = value
                  @cashout_adjustment[cash_key][primary_key1][cash_key1][cltv_key][ltv_key] = {}
                  @cashout_adjustment[cash_key][primary_key1][cash_key1][cltv_key][ltv_key] = value
                end

                # High-Balance Adjustments
                if r == 33 && cc == 1
                  cltv_key = "Standard Cash Out"
                  @cashout_adjustment[cash_key][secondary_key][cash_key1][cltv_key] = {}
                end
                if r == 33 && cc >= 9 && cc <= 16
                  ltv_key = get_value @ltv_data[cc-1]
                  @cashout_adjustment[cash_key][secondary_key][cash_key1][cltv_key][ltv_key] = {}
                  @cashout_adjustment[cash_key][secondary_key][cash_key1][cltv_key][ltv_key] = value
                end
                if r == 34 && cc == 1
                  cash_key = "LoanType/LoanPurpose/RefinanceOption/LTV"
                  primary_key1 = "ARM"
                  primary_key2 = "Purchase"
                  secondary_key = "Rate and Term"
                  @cashout_adjustment[cash_key] = {}
                  @cashout_adjustment[cash_key][primary_key1] = {}
                  @cashout_adjustment[cash_key][primary_key1][primary_key2] = {}
                  @cashout_adjustment[cash_key][primary_key1][primary_key2][secondary_key] = {}
                end
                if r == 34 && cc >= 9 && cc <= 16
                  ltv_key = get_value @ltv_data[cc-1]
                  @cashout_adjustment[cash_key][primary_key1][primary_key2][secondary_key][ltv_key] = {}
                  @cashout_adjustment[cash_key][primary_key1][primary_key2][secondary_key][ltv_key] = value
                end

                # SUBORDINATE FINANCING
                if r >= 39 && r <= 43 && cc == 1
                  if value.include?("%")
                    secondary_key = value.split('.').first
                  end
                  secondary_key = get_value secondary_key
                  @subordinate_hash[primary_key][primary_key3][secondary_key] = {}
                end
                if r >= 39 && r <= 43 && cc == 3
                  if value.include?("%")
                    ltv_key = value.split('.').first
                  end
                  ltv_key = get_value ltv_key
                  @subordinate_hash[primary_key][primary_key3][secondary_key][ltv_key] = {}
                end
                if r >= 39 && r <= 43 && cc >= 5 && cc <= 7
                  cltv_key = get_value @cltv_data[cc-1]
                  @subordinate_hash[primary_key][primary_key3][secondary_key][ltv_key][cltv_key] = {}
                  @subordinate_hash[primary_key][primary_key3][secondary_key][ltv_key][cltv_key] = value
                end
                if r == 44 && cc == 1
                  @subordinate_hash["FinancingType"] = {}
                  @subordinate_hash["FinancingType"]["Home Possible"] = {}
                end
                if r == 44 && cc == 5
                  @subordinate_hash["FinancingType"]["Home Possible"] = value
                end

                # HOMEREADY ADJUSTMENT CAPS
                if r == 48 && cc == 1
                  @adjustment_cap[primary_key]["HomeReady"]["680-Inf"] = {}
                  @adjustment_cap[primary_key]["HomeReady"]["680-Inf"]["80-Inf"] = {}
                end
                if r == 48 && cc == 8
                  @adjustment_cap[primary_key]["HomeReady"]["680-Inf"]["80-Inf"] = value
                end
                if r == 49 && cc == 1
                  @adjustment_cap[primary_key]["HomeReady"]["0-679"] = {}
                  @adjustment_cap[primary_key]["HomeReady"]["0-679"]["0-79"] = {}
                end
                if r == 49 && cc == 8
                  @adjustment_cap[primary_key]["HomeReady"]["0-679"]["0-79"] = value
                end
                if r == 54 && cc == 1
                  @adjustment_cap[primary_key1]["HomePossible"]["680-Inf"] = {}
                  @adjustment_cap[primary_key1]["HomePossible"]["680-Inf"]["80-Inf"] = {}
                end
                if r == 54 && cc == 8
                  @adjustment_cap[primary_key1]["HomePossible"]["680-Inf"]["80-Inf"] = value
                end
                if r == 55 && cc == 1
                  @adjustment_cap["FreddieMacProduct/FICO/LTV"] = {}
                  @adjustment_cap["FreddieMacProduct/FICO/LTV"]["HomePossible"] = {}
                  @adjustment_cap["FreddieMacProduct/FICO/LTV"]["HomePossible"]["0-679"] = {}
                  @adjustment_cap["FreddieMacProduct/FICO/LTV"]["HomePossible"]["0-679"]["0-79"] = {}
                end
                if r == 55 && cc == 8
                  @adjustment_cap["FreddieMacProduct/FICO/LTV"]["HomePossible"]["0-679"]["0-79"] = value
                end
                # LENDER PAID MI
                if r >= 71 && r <= 74 && cc == 3
                  primary_key1 = "True"
                  secondary_key = "Fixed"
                  ltv_key = "ARM"
                  @lpmi_hash[primary_key][primary_key1] = {}
                  @lpmi_hash[primary_key][primary_key1][secondary_key] = {}
                  @lpmi_hash[primary_key][primary_key1][ltv_key] = {}
                  # changed code on 12 march by Neeraj Pathak
                  @lpmi_adj[first_key][primary_key1] = {}
                  @lpmi_adj[first_key][primary_key1][secondary_key] = {}
                  ["25", "30"].each{|num| @lpmi_adj[first_key][primary_key1][secondary_key][num] = {}}
                end
                if r >= 75 && r <= 78 && cc == 3
                  primary_key1 = "True"
                  secondary_key = "Fixed"
                  ltv_key = "ARM"
                  @lpmi_adj[primary_key][primary_key1] = {}
                  @lpmi_adj[primary_key][primary_key1][secondary_key] = {}
                  @lpmi_adj[primary_key][primary_key1][ltv_key] = {}
                  # changed code on 12 march by Neeraj Pathak
                  ["10", "15", "20"].each{|num| @lpmi_adj[first_key][primary_key1][secondary_key][num] = {}}
                end
                if r >= 71 && r <= 74 && cc == 5
                  secondary_key1 = get_value value
                  @lpmi_hash[primary_key][primary_key1][secondary_key][secondary_key1] = {}
                  @lpmi_hash[primary_key][primary_key1][ltv_key][secondary_key1] = {}
                  # changed code on 12 march by Neeraj Pathak
                  ["25", "30"].each{|num| @lpmi_adj[first_key][primary_key1][secondary_key][num][secondary_key1] = {}}
                end
                if r >= 71 && r <= 74 && cc >= 6 && cc <= 14
                  unless @lpmi_data[cc-1].eql?("%")
                    lpmi_key = get_value @lpmi_data[cc-1]
                    @lpmi_hash[primary_key][primary_key1][secondary_key][secondary_key1][lpmi_key] = {}
                    @lpmi_hash[primary_key][primary_key1][secondary_key][secondary_key1][lpmi_key] = value
                    @lpmi_hash[primary_key][primary_key1][ltv_key][secondary_key1][lpmi_key] = {}
                    @lpmi_hash[primary_key][primary_key1][ltv_key][secondary_key1][lpmi_key] = value
                    # changed code on 12 march by Neeraj Pathak
                    ["25", "30"].each{|num| @lpmi_adj[first_key][primary_key1][secondary_key][num][secondary_key1][lpmi_key] = value}
                  end
                end
                if r >= 75 && r <= 78 && cc == 5
                  secondary_key1 = get_value value
                  @lpmi_adj[primary_key][primary_key1][secondary_key][secondary_key1] = {}
                  @lpmi_adj[primary_key][primary_key1][ltv_key][secondary_key1] = {}
                  # changed code on 12 march by Neeraj Pathak
                  ["10", "15", "20"].each{|num| @lpmi_adj[first_key][primary_key1][secondary_key][num][secondary_key1] = {}}
                end
                if r >= 75 && r <= 78 && cc >= 6 && cc <= 14
                  unless @lpmi_data[cc-1].eql?("%")
                    lpmi_key = get_value @lpmi_data[cc-1]
                    @lpmi_adj[primary_key][primary_key1][secondary_key][secondary_key1][lpmi_key] = {}
                    @lpmi_adj[primary_key][primary_key1][secondary_key][secondary_key1][lpmi_key] = value
                    @lpmi_adj[primary_key][primary_key1][ltv_key][secondary_key1][lpmi_key] = {}
                    @lpmi_adj[primary_key][primary_key1][ltv_key][secondary_key1][lpmi_key] = value
                    # changed code on 12 march by Neeraj Pathak
                    ["10", "15", "20"].each{|num| @lpmi_adj[first_key][primary_key1][secondary_key][num][secondary_key1][lpmi_key] = value}
                  end
                end
                # HomeReady & HomePossible
                if r >= 79 && r <= 82 && cc == 3
                  primary_key1 = true
                  secondary_key = "HomeReady"
                  cltv_key = "Home Possible"
                  ltv_key = "Fixed"
                  @home_ready[cash_key][primary_key1] = {}
                  @home_ready[cash_key][primary_key1][secondary_key] = {}
                  @home_ready[cash_key][primary_key1][secondary_key][ltv_key] = {}
                  @home_ready[cash_key][primary_key1][secondary_key][ltv_key]["30"] = {}
                  @home_ready[cash_key][primary_key1][cltv_key] = {}
                  @home_ready[cash_key][primary_key1][cltv_key][ltv_key] = {}
                  @home_ready[cash_key][primary_key1][cltv_key][ltv_key]["15"] = {}
                  @home_ready[cash_key][primary_key1][cltv_key][ltv_key]["20"] = {}
                end
                if r >= 83 && r <= 86 && cc == 3
                  primary_key1 = "True"
                  secondary_key = "HomeReady"
                  cltv_key = "HomePossible"
                  ltv_key = "Fixed"
                  @home_possible[cash_key][primary_key1] = {}
                  @home_possible[cash_key][primary_key1][secondary_key] = {}
                  @home_possible[cash_key][primary_key1][secondary_key][ltv_key] = {}
                  @home_possible[cash_key][primary_key1][cltv_key] = {}
                  @home_possible[cash_key][primary_key1][cltv_key][ltv_key] = {}
                end
                if r >= 79 && r <= 82 && cc == 5
                  secondary_key1 = get_value value
                  @home_ready[cash_key][primary_key1][secondary_key][ltv_key]["30"][secondary_key1] = {}
                  @home_ready[cash_key][primary_key1][cltv_key][ltv_key]["15"][secondary_key1] = {}
                  @home_ready[cash_key][primary_key1][cltv_key][ltv_key]["20"][secondary_key1] = {}
                end
                if r >= 79 && r <= 82 && cc >= 6 && cc <= 14
                  unless @lpmi_data[cc-1].eql?("%")
                    lpmi_key = get_value @lpmi_data[cc-1]
                    @home_ready[cash_key][primary_key1][secondary_key][ltv_key]["30"][secondary_key1][lpmi_key] = {}
                    @home_ready[cash_key][primary_key1][secondary_key][ltv_key]["30"][secondary_key1][lpmi_key] = value
                    @home_ready[cash_key][primary_key1][cltv_key][ltv_key]["15"][secondary_key1][lpmi_key] = {}
                    @home_ready[cash_key][primary_key1][cltv_key][ltv_key]["15"][secondary_key1][lpmi_key] = value
                    @home_ready[cash_key][primary_key1][cltv_key][ltv_key]["20"][secondary_key1][lpmi_key] = {}
                    @home_ready[cash_key][primary_key1][cltv_key][ltv_key]["20"][secondary_key1][lpmi_key] = value
                  end
                end
                if r >= 83 && r <= 86 && cc == 5
                  secondary_key1 = get_value value
                  @home_possible[cash_key][primary_key1][secondary_key][ltv_key]["30"] = {}
                  @home_possible[cash_key][primary_key1][secondary_key][ltv_key]["30"][secondary_key1] = {}
                  @home_possible[cash_key][primary_key1][cltv_key][ltv_key]["15"] = {}
                  @home_possible[cash_key][primary_key1][cltv_key][ltv_key]["20"] = {}
                  @home_possible[cash_key][primary_key1][cltv_key][ltv_key]["15"][secondary_key1] = {}
                  @home_possible[cash_key][primary_key1][cltv_key][ltv_key]["20"][secondary_key1] = {}
                end
                if r >= 83 && r <= 86 && cc >= 6 && cc <= 14
                  lpmi_key = get_value @lpmi_data[cc-1]
                  if lpmi_key.present?
                    @home_possible[cash_key][primary_key1][secondary_key][ltv_key]["30"][secondary_key1][lpmi_key] = {}
                    @home_possible[cash_key][primary_key1][secondary_key][ltv_key]["30"][secondary_key1][lpmi_key] = value
                    @home_possible[cash_key][primary_key1][cltv_key][ltv_key]["15"][secondary_key1][lpmi_key] = {}
                    @home_possible[cash_key][primary_key1][cltv_key][ltv_key]["20"][secondary_key1][lpmi_key] = {}
                    @home_possible[cash_key][primary_key1][cltv_key][ltv_key]["15"][secondary_key1][lpmi_key] = value
                    @home_possible[cash_key][primary_key1][cltv_key][ltv_key]["20"][secondary_key1][lpmi_key] = value
                  end
                end
                # LPMI (in addition to adjustments above)
                if r >= 88 && r <= 89 && cc == 3
                  if value == "Rate/Term"
                    secondary_key = "Rate and Term"
                  elsif value == "Investment"
                    secondary_key = "Investment Property"
                  else
                    secondary_key = get_value value
                  end
                  @property_hash[primary_key]["true"][secondary_key] = {}
                end
                if r >= 88 && r <= 89 && cc >= 7 && cc <= 14
                  lpmi_key = get_value @lpmi_data[cc-1]
                  @property_hash[primary_key]["true"][secondary_key][lpmi_key] = {}
                  @property_hash[primary_key]["true"][secondary_key][lpmi_key] = value
                end
                if r >= 90 && r <= 93 && cc == 3
                  secondary_key = get_value value
                  @property_hash[primary_key1]["true"][secondary_key] = {}
                end
                if r >= 90 && r <= 93 && cc >= 7 && cc <= 14
                  lpmi_key = get_value @lpmi_data[cc-1]
                  @property_hash[primary_key1]["true"][secondary_key][lpmi_key] = {}
                  @property_hash[primary_key1]["true"][secondary_key][lpmi_key] = value
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
          (10..16).each do |cc|
            value = sheet_data.cell(r,cc)
            begin
              if value.present?
                if value == "LOAN AMOUNT "
                  primary_key1 = "LoanAmount"
                  @loan_adjustment[primary_key1] = {}
                end
                if value == "STATE ADJUSTMENTS"
                  primary_key1 = "State"
                  @state_adjustments[primary_key1] = {}
                end
                # LOAN AMOUNT
                if r >= 38 && r <= 42 && cc == 10
                  if value.include?("Conf Limit")
                    secondary_key1 = value.split("Loan Amount").last.tr('$a-zA-Z><= ', '').gsub(",", "")+"Inf"
                  elsif value.include?("Loan Amount")
                    secondary_key1 = value.split("Loan Amount").last.tr('$><= ', '').gsub(",", "")
                  else
                    secondary_key1 = get_value value
                  end
                  @loan_adjustment[primary_key1][secondary_key1] = {}
                end
                if r >= 38 && r <= 42 && cc == 16
                  @loan_adjustment[primary_key1][secondary_key1] = value
                end
                # STATE ADJUSTMENTS
                if r >= 46 && r <= 52 && cc == 11
                  adj_key = value.split(', ')
                  adj_key.each do |f_key|
                    key = f_key
                    ccc = cc + 5
                    c_val = sheet_data.cell(r,ccc)
                    @state_adjustments[primary_key1][key] = c_val
                  end
                end

                if r == 55 && cc == 10
                  @other_adjustment["LockDay"] = {}
                  @other_adjustment["LockDay"]["60"] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @other_adjustment["LockDay"]["60"] = new_val
                end
                if r == 56 && cc == 10
                  @other_adjustment["MiscAdjuster"] = {}
                  @other_adjustment["MiscAdjuster"][value] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @other_adjustment["MiscAdjuster"][value] = new_val
                end
                if r == 59 && cc == 10
                  @other_adjustment["FreddieMacProduct/LoanType"] = {}
                  @other_adjustment["FreddieMacProduct/LoanType"]["Home Possible"] = {}
                  @other_adjustment["FreddieMacProduct/LoanType"]["Home Possible"]["ARM"] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @other_adjustment["FreddieMacProduct/LoanType"]["Home Possible"]["ARM"] = new_val
                end
                if r == 60 && cc == 10
                  @other_adjustment["LoanType"] = {}
                  @other_adjustment["LoanType"]["Fixed"] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @other_adjustment["LoanType"]["Fixed"] = new_val
                end
                if r == 61 && cc == 10
                  @other_adjustment["State"] = {}
                  @other_adjustment["State"]["NY"] = {}
                  cc = cc + 6
                  new_val = sheet_data.cell(r,cc)
                  @other_adjustment["State"]["NY"] = new_val
                end
              end
            rescue Exception => e
              error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
              error_log.save
            end
          end
        end
        adjustment = [@adjustment_hash,@adjustment_fico,@cashout_adjustment,@subordinate_hash,@adjustment_cap,@loan_adjustment,@state_adjustments,@other_adjustment,@lpmi_hash,@lpmi_adj,@home_ready,@home_possible,@property_hash]
        make_adjust(adjustment,"AGENCY")
        create_program_association_with_adjustment("AGENCY")
      end

    end
    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def durp
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "DURP")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @subordinate_hash = {}
        @adjustment_cap = {}
        @misc_adjustment = {}
        @state_adjustment = {}
        primary_key = ''
        primary_key1 = ''
        secondary_key = ''
        fnma_key = ''
        sub_data = ''
        sub_key = ''
        cltv_key = ''
        cap_key = ''
        m_key = ''
        key = ''
        loan_key = ''
        new_key = ''
        (10..53).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_property sheet
                @programs_ids << @program.id
                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..3).each_with_index do |index, c_i|
                    rrr = rr + max_row -1
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      elsif (c_i == 1)
                        @block_hash[key][21] = value
                      elsif (c_i == 2)
                        @block_hash[key][30] = value
                      elsif (c_i == 3)
                        @block_hash[key][45] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Adjustment
        (55..88).each do |r|
          row = sheet_data.row(r)
          @fnma_data = sheet_data.row(57)
          @sub_data = sheet_data.row(73)
          @cap_data = sheet_data.row(80)
          if row.compact.count >= 1
            (0..16).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "FNMA DU REFI PLUS ADJUSTMENTS"
                    primary_key = "PropertyType/LTV"
                    @adjustment_hash[primary_key] = {}
                    @adjustment_hash["FannieMae/Term/FICO/LTV"] = {}
                    @adjustment_hash["FannieMae/Term/FICO/LTV"]["true"] = {}
                    @adjustment_hash["FannieMae/Term/FICO/LTV"]["true"]["15-Inf"] = {}
                  elsif value == "SUBORDINATE FINANCING"
                    primary_key = "FinancingType/LTV/CLTV/FICO"
                    @subordinate_hash[primary_key] = {}
                    @subordinate_hash[primary_key]["Subordinate Financing"] = {}
                  elsif value == "DU REFI PLUS ADJUSTMENT CAP (MAX ADJ) *"
                    primary_key = "FannieMae/PropertyType/Term/LTV"
                    @adjustment_cap[primary_key] = {}
                    @adjustment_cap[primary_key]["true"] = {}
                  end
                  if r >= 58 && r <= 59 && cc == 1
                    if value.downcase.include?('units')
                      new_key = value.split('s').first
                    else
                      new_key = value
                    end
                    @adjustment_hash[primary_key][new_key] = {}
                  end
                  if r >= 58 && r <= 59 && cc >= 8 && cc <= 16
                    fnma_key = get_value @fnma_data[cc-1]
                    @adjustment_hash[primary_key][new_key][fnma_key] = {}
                    @adjustment_hash[primary_key][new_key][fnma_key] = value
                  end
                  if r == 60 && cc >= 8 && cc <= 16
                    primary_key = "PropertyType/Term/LTV"
                    @adjustment_hash[primary_key] = {}
                    new_key = "Condo"
                    @adjustment_hash[primary_key][new_key] = {}
                    term_key = "15-Inf"
                    @adjustment_hash[primary_key][new_key][term_key] = {}
                  end
                  if r == 60 && cc >= 8 && cc <= 16
                    fnma_key = get_value @fnma_data[cc-1]
                    @adjustment_hash[primary_key][new_key][term_key][fnma_key] = {}
                    @adjustment_hash[primary_key][new_key][term_key][fnma_key] = value
                  end
                  if r >= 61 && r <= 68 && cc == 1
                    if value.include?("<")
                      secondary_key = "0-"+value.split("(N/A for 15 Year Term or less)").first.tr('A-Z>< ','')
                    elsif value.include?(">=")
                      secondary_key = value.split("(N/A for 15 Year Term or less)").first.tr('A-Z<>= ','')+"-Inf"
                    elsif value.include?("(N/A for 15 Year Term or less)")
                      secondary_key = value.split("(N/A for 15 Year Term or less)").first.tr('A-Z ','')
                    end
                    @adjustment_hash["FannieMae/Term/FICO/LTV"]["true"]["15-Inf"][secondary_key] = {}
                  end
                  if r >= 61 && r <= 68 && cc >= 8 && cc <= 16
                    ltv_key = get_value @fnma_data[cc-1]
                    @adjustment_hash["FannieMae/Term/FICO/LTV"]["true"]["15-Inf"][secondary_key][ltv_key] = {}
                    @adjustment_hash["FannieMae/Term/FICO/LTV"]["true"]["15-Inf"][secondary_key][ltv_key] = value
                  end
                  if r == 69 && cc == 1
                    @adjustment_hash["PropertyType/LTV"]["Manufactured Home"] = {}
                  end
                  if r == 69 && cc >= 8 && cc <= 16
                    ltv_key = get_value @fnma_data[cc-1]
                    @adjustment_hash["PropertyType/LTV"]["Manufactured Home"][ltv_key] = {}
                    @adjustment_hash["PropertyType/LTV"]["Manufactured Home"][ltv_key] = value
                  end
                  if r == 70 && cc == 1
                    @adjustment_hash["LoanSize/Term/LTV"] = {}
                    @adjustment_hash["LoanSize/Term/LTV"]["High-Balance"] = {}
                    @adjustment_hash["LoanSize/Term/LTV"]["High-Balance"]["15"] = {}
                  end
                  if r == 70 && cc >= 8 && cc <= 16
                    ltv_key = get_value @fnma_data[cc-1]
                    @adjustment_hash["LoanSize/Term/LTV"]["High-Balance"]["15"][ltv_key] = {}
                    @adjustment_hash["LoanSize/Term/LTV"]["High-Balance"]["15"][ltv_key] = value
                  end

                  # subordinate adjustment
                  if r >= 74 && r <= 78 && cc == 1
                    if value.include?("-")
                      secondary_key = value.tr('%$' , '')
                    elsif value.include?("All")
                      secondary_key = "0-Inf"
                    else
                      secondary_key = get_value value
                    end
                    @subordinate_hash[primary_key]["Subordinate Financing"][secondary_key] = {}
                  end
                  if r >= 74 && r <= 78 && cc == 3
                    if value.include?("-")
                      cltv_key = value.tr('%$' , '')
                    else
                      cltv_key = get_value value
                    end
                    @subordinate_hash[primary_key]["Subordinate Financing"][secondary_key][cltv_key] = {}
                  end
                  if r >= 74 && r <= 78 && cc >= 5 && cc <= 7
                    sub_data = get_value @sub_data[cc-1]
                    @subordinate_hash[primary_key]["Subordinate Financing"][secondary_key][cltv_key][sub_data] = {}
                    @subordinate_hash[primary_key]["Subordinate Financing"][secondary_key][cltv_key][sub_data] = value
                  end
                  # Adjustment Cap
                  if r >= 81 && r <= 82 && cc == 1
                    if value == "Primary / Second Home"
                      secondary_key = "2nd Home"
                    elsif value.downcase.include?("all")
                      secondary_key = "0-Inf"
                    else
                      secondary_key = value
                    end
                    @adjustment_cap[primary_key]["true"][secondary_key] = {}
                  end
                  if r >= 81 && r <= 82 && cc == 4
                    if value.downcase.include?("all")
                      cltv_key = "0-Inf"
                    else
                      cltv_key = get_value value
                    end
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key] = {}
                  end
                  if r >= 81 && r <= 82 && cc >= 5 && cc <= 7
                    cap_key = get_value @cap_data[cc-1]
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key][cap_key] = {}
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key][cap_key] = value
                  end
                  if r == 83 && cc == 4
                    cltv_key = get_value value
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key] = {}
                  end
                  if r == 83 && cc >= 5 && cc <= 7
                    cap_key = get_value @cap_data[cc-1]
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key][cap_key] = {}
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key][cap_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
            (10..16).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value == "LOAN AMOUNT "
                  primary_key1 = "LoanAmount"
                  @misc_adjustment[primary_key1] = {}
                end
                if value == "STATE ADJUSTMENTS"
                  primary_key1 = "State"
                  @state_adjustment[primary_key1] = {}
                end
                if value.present?
                  # MISCELLANEOUS
                  if r == 73 && cc == 10 
                    @misc_adjustment["LockDay"] = {}
                    @misc_adjustment["LockDay"]["60"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @misc_adjustment["LockDay"]["60"] = new_val
                  end
                  if r == 74 && cc == 10 
                    @misc_adjustment["State"] = {}
                    @misc_adjustment["State"]["NY"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @misc_adjustment["State"]["NY"] = new_val
                  end
                  # LOAN AMOUNT ADJUSTMENT
                  if r >= 76 && r <= 80 && cc == 10
                    if value.include?(">=")
                      m_key = value.tr('A-Za-z$%<>=, ','')
                    elsif value.downcase.include?('conf limit')
                      m_key = value.tr('A-Za-z$, ','') + "Inf"
                    else
                      m_key =  get_value value
                    end
                    @misc_adjustment[primary_key1][m_key] = {}
                  end
                  if r >= 76 && r <= 80 && cc == 16
                    @misc_adjustment[primary_key1][m_key] = value
                  end
                  # STATE ADJUSTMENTS
                  if r >= 83 && r <= 88 && cc == 11
                    adj_key = value.split(', ')
                    adj_key.each do |f_key|
                      key = f_key
                      ccc = cc + 5
                      c_val = sheet_data.cell(r,ccc)
                      @state_adjustment[primary_key1][key] = c_val
                    end
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@subordinate_hash,@adjustment_cap,@misc_adjustment,@state_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def oa
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "OA")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @subordinate_hash = {}
        @adjustment_cap = {}
        @misc_adjustment = {}
        @state_adjustment = {}
        primary_key = ''
        primary_key1 = ''
        secondary_key = ''
        fnma_key = ''
        sub_data = ''
        sub_key = ''
        cltv_key = ''
        cap_key = ''
        m_key = ''
        key = ''
        loan_key = ''
        @programs_ids = []
        (10..53).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_property sheet
                @programs_ids << @program.id
                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..3).each_with_index do |index, c_i|
                    rrr = rr + max_row -1
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      elsif (c_i == 1)
                        @block_hash[key][21] = value
                      elsif (c_i == 2)
                        @block_hash[key][30] = value
                      elsif (c_i == 3)
                        @block_hash[key][45] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Adjustment
        (54..88).each do |r|
          row = sheet_data.row(r)
          @fnma_data = sheet_data.row(56)
          @sub_data = sheet_data.row(73)
          @cap_data = sheet_data.row(82)
          if row.compact.count >= 1
            (0..16).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?

                  if value == "FHLMC LP OPEN ACCESS ADJUSTMENTS"
                    primary_key = "FreddieMac/PropertyType/LTV"
                    @adjustment_hash[primary_key] = {}
                    @adjustment_hash[primary_key]["true"] = {}
                    @adjustment_hash["FreddieMac/Term/FICO/LTV"] = {}
                    @adjustment_hash["FreddieMac/Term/FICO/LTV"]["true"] = {}
                    @adjustment_hash["FreddieMac/Term/FICO/LTV"]["true"]["15-Inf"] = {}
                  elsif value == "SUBORDINATE FINANCING"
                    primary_key = "FinancingType/LTV/CLTV/FICO"
                    @subordinate_hash[primary_key] = {}
                    @subordinate_hash[primary_key]["Subordinate Financing"] = {}
                  elsif value == "OPEN ACCESS ADJUSTMENT CAP (MAX ADJ) *"
                    primary_key = "FannieMae/PropertyType/Term/LTV"
                    @adjustment_cap[primary_key] = {}
                    @adjustment_cap[primary_key]["true"] = {}
                  end
                  if r >= 57 && r <= 60 && cc == 1
                    if value.downcase.include?('units') || value.downcase.include?('homes')
                      secondary_key = value.split('s').first
                    else
                      secondary_key = get_value value
                    end
                    @adjustment_hash[primary_key]["true"][secondary_key] = {}
                  end
                  if r >= 57 && r <= 60 && cc >= 8 && cc <= 16
                    fnma_key = get_value @fnma_data[cc-1]
                    @adjustment_hash[primary_key]["true"][secondary_key][fnma_key] = {}
                    @adjustment_hash[primary_key]["true"][secondary_key][fnma_key] = value
                  end
                  if r == 61 && cc == 1
                    @adjustment_hash["FreddieMac/PropertyType/Term/LTV"] = {}
                    @adjustment_hash["FreddieMac/PropertyType/Term/LTV"]["true"] = {}
                    @adjustment_hash["FreddieMac/PropertyType/Term/LTV"]["true"]["Condo"] = {}
                    @adjustment_hash["FreddieMac/PropertyType/Term/LTV"]["true"]["Condo"]["15-Inf"] = {}
                  end
                  if r == 61 && cc >= 8 && cc <= 16
                    fnma_key = get_value @fnma_data[cc-1]
                    @adjustment_hash["FreddieMac/PropertyType/Term/LTV"]["true"]["Condo"]["15-Inf"][fnma_key] = {}
                    @adjustment_hash["FreddieMac/PropertyType/Term/LTV"]["true"]["Condo"]["15-Inf"][fnma_key] = value
                  end
                  if r == 62 && cc == 1
                    @adjustment_hash["PropertyType/State"] = {}
                    @adjustment_hash["PropertyType/State"]["Condo"] = {}
                    @adjustment_hash["PropertyType/State"]["Condo"]["CA"] = {}
                  end
                  if r == 62 && cc >= 8 && cc <= 16
                    fnma_key = get_value @fnma_data[cc-1]
                    @adjustment_hash["PropertyType/State"]["Condo"]["CA"][fnma_key] = {}
                    @adjustment_hash["PropertyType/State"]["Condo"]["CA"][fnma_key] = value
                  end
                  if r >= 63 && r <= 69 && cc == 1
                    if value.include?("<")
                      secondary_key = "0-"+value.split("(N/A for 15 Year Term or less)").first.tr('A-Z><= ','')
                    elsif value.include?(">=")
                      secondary_key = value.split("(N/A for 15 Year Term or less)").first.tr('A-Z<>= ','')+"-Inf"
                    elsif value.include?("(N/A for 15 Year Term or less)")
                      secondary_key = value.split("(N/A for 15 Year Term or less)").first.tr('A-Z ','')
                    end
                    @adjustment_hash["FreddieMac/Term/FICO/LTV"]["true"]["15-Inf"][secondary_key] = {}
                  end
                  if r >= 63 && r <= 69 && cc >= 8 && cc <= 16
                    fnma_key = get_value @fnma_data[cc-1]
                    @adjustment_hash["FreddieMac/Term/FICO/LTV"]["true"]["15-Inf"][secondary_key][fnma_key] = {}
                    @adjustment_hash["FreddieMac/Term/FICO/LTV"]["true"]["15-Inf"][secondary_key][fnma_key] = value
                  end
                  if r == 70 && cc == 1
                    @adjustment_hash["LoanSize/LTV"] = {}
                    @adjustment_hash["LoanSize/LTV"]["High-Balance"] = {}
                  end
                  if r == 70 && cc >= 8 && cc <= 16
                    fnma_key = get_value @fnma_data[cc-1]
                    @adjustment_hash["LoanSize/LTV"]["High-Balance"][fnma_key] = {}
                    @adjustment_hash["LoanSize/LTV"]["High-Balance"][fnma_key] = value
                  end

                  # subordinate adjustment
                  if r >= 74 && r <= 80 && cc == 1
                    if value.include?("-")
                      secondary_key = value.tr('%$' , '')
                    elsif value.downcase.include?('all')
                      secondary_key = "0-Inf"
                    else
                      secondary_key = get_value value
                    end
                    @subordinate_hash[primary_key]["Subordinate Financing"][secondary_key] = {}
                  end
                  if r >= 74 && r <= 80 && cc == 3
                    if value.include?("-")
                      cltv_key = value.tr('%$' , '')
                    else
                      cltv_key = get_value value
                    end
                    @subordinate_hash[primary_key]["Subordinate Financing"][secondary_key][cltv_key] = {}
                  end
                  if r >= 74 && r <= 80 && cc >= 5 && cc <= 7
                    sub_data = get_value @sub_data[cc-1]
                    @subordinate_hash[primary_key]["Subordinate Financing"][secondary_key][cltv_key][sub_data] = {}
                    @subordinate_hash[primary_key]["Subordinate Financing"][secondary_key][cltv_key][sub_data] = value
                  end
                  # Adjustment Cap
                  if r >= 83 && r <= 84 && cc == 1
                    if value == "Primary / Second Home"
                      secondary_key = "2nd Home"
                    else
                      secondary_key = value
                    end
                    @adjustment_cap[primary_key]["true"][secondary_key] = {}
                  end
                  if r >= 83 && r <= 84 && cc == 4
                    if value.downcase.include?('all')
                      cltv_key = "0-Inf"
                    else
                      cltv_key = get_value value
                    end
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key] = {}
                  end
                  if r >= 83 && r <= 84 && cc >= 5 && cc <= 7
                    cap_key = get_value @cap_data[cc-1]
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key][cap_key] = {}
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key][cap_key] = value
                  end
                  if r == 85 && cc == 4
                    cltv_key = get_value value
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key] = {}
                  end
                  if r == 85 && cc >= 5 && cc <= 7
                    cap_key = get_value @cap_data[cc-1]
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key][cap_key] = {}
                    @adjustment_cap[primary_key]["true"][secondary_key][cltv_key][cap_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end

            (10..16).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "LOAN AMOUNT "
                    primary_key1 = "LoanAmount"
                    @misc_adjustment[primary_key1] = {}
                  end
                  if value == "STATE ADJUSTMENTS"
                    primary_key1 = "State"
                    @state_adjustment[primary_key1] = {}
                  end

                  # MISCELLANEOUS
                  if r == 73 && cc == 10
                    @misc_adjustment["LockDay"] = {}
                    @misc_adjustment["LockDay"]["60"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @misc_adjustment["LockDay"]["60"] = new_val
                  end
                  if r == 74 && cc == 10
                    @misc_adjustment["State"] = {}
                    @misc_adjustment["State"]["NY"] = {}
                  end
                  if r == 74 && cc == 16
                    @misc_adjustment["State"]["NY"] = value
                  end
                  # LOAN AMOUNT ADJUSTMENT
                  if r >= 76 && r <= 80 && cc == 10
                    if value.include?(">=")
                      m_key = value.tr('A-Za-z$%<>=, ','')
                    else
                      m_key =  get_value value
                    end
                    @misc_adjustment[primary_key1][m_key] = {}
                  end
                  if r >= 76 && r <= 80 && cc == 16
                    @misc_adjustment[primary_key1][m_key] = value
                  end
                  # STATE ADJUSTMENTS
                  if r >= 83 && r <= 88 && cc == 11
                    adj_key = value.split(', ')
                    adj_key.each do |f_key|
                      key = f_key
                      ccc = cc + 5
                      c_val = sheet_data.cell(r,ccc)
                      @state_adjustment[primary_key1][key] = c_val
                    end
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@subordinate_hash,@adjustment_cap,@misc_adjustment,@state_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end

    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def mi_llpas
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "MI LLPAS")
        program_sheet = "AGENCY"
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @standard_hash = {}
        @home_hash = {}
        @adjustment_cap = {}
        @subordinate_hash = {}
        @property_hash = {}
        ltv_key = ''
        secondary_key = ''

        # Adjustment
        (10..62).each do |r|
          begin
            row = sheet_data.row(r)
            @sub_data = sheet_data.row(11)
            if row.compact.count >= 1
              (0..14).each do |cc|
                begin
                  value = sheet_data.cell(r,cc)
                  if value.present?
                    if value == 'LENDER PAID MI'
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["25"] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["30"] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["10"] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["15"] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["20"] = {}
                      @adjustment_hash["LPMI/LoanType/LTV/FICO"] = {}
                      @adjustment_hash["LPMI/LoanType/LTV/FICO"]["true"] = {}
                      @adjustment_hash["LPMI/LoanType/LTV/FICO"]["true"]["ARM"] = {}
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"] = {}
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"] = {}
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"] = {}
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"] = {}
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["30"] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["30"] = {}

                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["15"] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["15"] = {}
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["20"] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["20"] = {}
                    end
                    if value == "LPMI (in addition to adjustments above)"
                      @subordinate_hash["RefinanceOption/FICO"] = {}
                      @subordinate_hash["PropertyType/FICO"] = {}
                    end
                    if value == 'ENTERPRISE PAID MI'
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["25"] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["30"] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["10"] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["15"] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["20"] = {}

                      @standard_hash["EPMI/LoanType/LTV/FICO"] = {}
                      @standard_hash["EPMI/LoanType/LTV/FICO"]["true"] = {}
                      @standard_hash["EPMI/LoanType/LTV/FICO"]["true"]["ARM"] = {}

                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["30"] = {}

                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["30"] = {}

                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["15"] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["15"] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["20"] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["20"] = {}

                      @home_hash["EPMI/FannieMaeProduct/LoanType/LTV/FICO"] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/LTV/FICO"]["true"] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/LTV/FICO"]["true"]["HomeReady"] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/LTV/FICO"]["true"]["HomeReady"]["ARM"] = {}

                      @home_hash["EPMI/FreddieMacProduct/LoanType/LTV/FICO"] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/LTV/FICO"]["true"] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/LTV/FICO"]["true"]["HomePossible"] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/LTV/FICO"]["true"]["HomePossible"]["ARM"] = {}
                    end
                    if value == "EPMI (in addition to adjustments above)"
                      @property_hash["EPMI/RefinanceOption/FICO"] = {}
                      @property_hash["EPMI/RefinanceOption/FICO"]["true"] = {}
                      @property_hash["EPMI/RefinanceOption/FICO"]["true"] = {}

                      @property_hash["EPMI/PropertyType/FICO"] = {}
                      @property_hash["EPMI/PropertyType/FICO"]["true"] = {}
                    end
                    if r >= 12 && r <= 15 && cc == 5
                      secondary_key = get_value value
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["25"][secondary_key] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["30"][secondary_key] = {}
                      @adjustment_hash["LPMI/LoanType/LTV/FICO"]["true"]["ARM"][secondary_key] = {}
                    end
                    if r >= 12 && r <= 15 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["25"][secondary_key][ltv_key] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["30"][secondary_key][ltv_key] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["25"][secondary_key][ltv_key] = value
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["30"][secondary_key][ltv_key] = value
                      @adjustment_hash["LPMI/LoanType/LTV/FICO"]["true"]["ARM"][secondary_key][ltv_key] = value
                    end
                    if r >= 16 && r <= 19 && cc == 5
                      secondary_key = get_value value
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["10"][secondary_key] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["15"][secondary_key] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["20"][secondary_key] = {}
                    end
                    if r >= 16 && r <= 19 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["10"][secondary_key][ltv_key] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["15"][secondary_key][ltv_key] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["20"][secondary_key][ltv_key] = {}
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["10"][secondary_key][ltv_key] = value
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["15"][secondary_key][ltv_key] = value
                      @adjustment_hash["LPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["20"][secondary_key][ltv_key] = value
                    end
                    # HomeReady and HomePossible
                    if r >= 20 && r <= 23 && cc == 5
                      secondary_key = get_value value
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["30"][secondary_key] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["30"][secondary_key] = {}
                    end
                    if r >= 20 && r <= 23 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["30"][secondary_key][ltv_key] = {}
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["30"][secondary_key][ltv_key] = value
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["30"][secondary_key][ltv_key] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["30"][secondary_key][ltv_key] = value
                    end
                    if r >= 24 && r <= 27 && cc == 5
                      secondary_key = get_value value
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["15"][secondary_key] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["20"][secondary_key] = {}
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["15"][secondary_key] = {}
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["20"][secondary_key] = {}
                    end
                    if r >= 24 && r <= 27 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["15"][secondary_key][ltv_key] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["20"][secondary_key][ltv_key] = {}
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["15"][secondary_key][ltv_key] = value
                      @adjustment_cap["LPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["20"][secondary_key][ltv_key] = value

                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["15"][secondary_key][ltv_key] = {}
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["20"][secondary_key][ltv_key] = {}
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["15"][secondary_key][ltv_key] = value
                      @adjustment_cap["LPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["20"][secondary_key][ltv_key] = value
                    end
                    # LPMI (in addition to adjustments above)
                    if r >= 29 && r <= 30 && cc == 3
                      if value.include?("Rate/Term")
                        secondary_key = "Rate and Term"
                      else
                        secondary_key = value
                      end
                      @subordinate_hash["RefinanceOption/FICO"][secondary_key] = {}
                    end
                    if r >= 29 && r <= 30 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @subordinate_hash["RefinanceOption/FICO"][secondary_key][ltv_key] = {}
                      @subordinate_hash["RefinanceOption/FICO"][secondary_key][ltv_key] = value
                    end
                    if r >= 31 && r <= 34 && cc == 3
                      if value.include?("Units")
                        secondary_key = value.split("s").first
                      elsif value.downcase.include?('investment')
                        secondary_key = "Investment Property"
                      else
                        secondary_key = value
                      end
                      @subordinate_hash["PropertyType/FICO"][secondary_key] = {}
                    end
                    if r >= 31 && r <= 34 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @subordinate_hash["PropertyType/FICO"][secondary_key][ltv_key] = {}
                      @subordinate_hash["PropertyType/FICO"][secondary_key][ltv_key] = value
                    end
                    # ENTERPRISE PAID MI
                    if r >= 38 && r <= 41 && cc == 5
                      secondary_key = get_value value
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["25"][secondary_key] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["30"][secondary_key] = {}
                      @standard_hash["EPMI/LoanType/LTV/FICO"]["true"]["ARM"][secondary_key] = {}
                    end
                    if r >= 38 && r <= 41 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["25"][secondary_key][ltv_key] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["30"][secondary_key][ltv_key] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["25"][secondary_key][ltv_key] = value
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["30"][secondary_key][ltv_key] = value
                      @standard_hash["EPMI/LoanType/LTV/FICO"]["true"]["ARM"][secondary_key][ltv_key] = value
                    end
                    if r >= 42 && r <= 45 && cc == 5
                      secondary_key = get_value value
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["10"][secondary_key] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["15"][secondary_key] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["20"][secondary_key] = {}
                    end
                    if r >= 42 && r <= 45 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["10"][secondary_key][ltv_key] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["15"][secondary_key][ltv_key] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["20"][secondary_key][ltv_key] = {}
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["10"][secondary_key][ltv_key] = value
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["15"][secondary_key][ltv_key] = value
                      @standard_hash["EPMI/LoanType/Term/LTV/FICO"]["true"]["Fixed"]["20"][secondary_key][ltv_key] = value
                    end
                    # HomeReady and HomePossible
                    if r >= 46 && r <= 49 && cc == 5
                      secondary_key = get_value value
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["30"][secondary_key] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["30"][secondary_key] = {}

                      @home_hash["EPMI/FannieMaeProduct/LoanType/LTV/FICO"]["true"]["HomeReady"]["ARM"][secondary_key] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/LTV/FICO"]["true"]["HomePossible"]["ARM"][secondary_key] = {}
                    end
                    if r >= 46 && r <= 49 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["30"][secondary_key][ltv_key] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["30"][secondary_key][ltv_key] = value
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["30"][secondary_key][ltv_key] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["30"][secondary_key][ltv_key] = value

                      @home_hash["EPMI/FannieMaeProduct/LoanType/LTV/FICO"]["true"]["HomeReady"]["ARM"][secondary_key][ltv_key] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/LTV/FICO"]["true"]["HomePossible"]["ARM"][secondary_key][ltv_key] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/LTV/FICO"]["true"]["HomeReady"]["ARM"][secondary_key][ltv_key] = value
                      @home_hash["EPMI/FreddieMacProduct/LoanType/LTV/FICO"]["true"]["HomePossible"]["ARM"][secondary_key][ltv_key] = value
                    end
                    if r >= 50 && r <= 53 && cc == 5
                      secondary_key = get_value value
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["15"][secondary_key] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["20"][secondary_key] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["15"][secondary_key] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["20"][secondary_key] = {}
                    end
                    if r >= 50 && r <= 53 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["15"][secondary_key][ltv_key] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["20"][secondary_key][ltv_key] = {}
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["15"][secondary_key][ltv_key] = value
                      @home_hash["EPMI/FreddieMacProduct/LoanType/Term/LTV/FICO"]["true"]["HomePossible"]["Fixed"]["20"][secondary_key][ltv_key] = value

                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["15"][secondary_key][ltv_key] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["20"][secondary_key][ltv_key] = {}
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["15"][secondary_key][ltv_key] = value
                      @home_hash["EPMI/FannieMaeProduct/LoanType/Term/LTV/FICO"]["true"]["HomeReady"]["Fixed"]["20"][secondary_key][ltv_key] = value
                    end
                    # EPMI (in addition to adjustments above)
                    if r == 55 && cc == 3
                      @property_hash["EPMI/RefinanceOption/FICO"]["true"]["Rate and Term"] = {}
                    end
                    if r == 55 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @property_hash["EPMI/RefinanceOption/FICO"]["true"]["Rate and Term"][ltv_key] = {}
                      @property_hash["EPMI/RefinanceOption/FICO"]["true"]["Rate and Term"][ltv_key] = value
                    end
                    if r == 56 && cc == 3
                      @property_hash["EPMI/RefinanceOption/FICO"]["true"]["Cash Out"] = {}
                    end
                    if r == 56 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @property_hash["EPMI/RefinanceOption/FICO"]["true"]["Cash Out"][ltv_key] = {}
                      @property_hash["EPMI/RefinanceOption/FICO"]["true"]["Cash Out"][ltv_key] = value
                    end
                    if r >= 57 && r <= 58 && cc == 3
                      secondary_key = value
                      @property_hash["EPMI/PropertyType/FICO"]["true"][secondary_key] = {}
                    end
                    if r >= 57 && r <= 58 && cc >= 7 && cc <= 14
                      if @sub_data[cc-1].include?("+")
                        ltv_key = @sub_data[cc-1].tr('+','')+"-Inf"
                      else
                        ltv_key = get_value @sub_data[cc-1]
                      end
                      @property_hash["EPMI/PropertyType/FICO"]["true"][secondary_key][ltv_key] = {}
                      @property_hash["EPMI/PropertyType/FICO"]["true"][secondary_key][ltv_key] = value
                    end
                  end
                rescue Exception => e
                  error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                  error_log.save
                end
              end
            end
          rescue
            raise "value is nil at row = #{r}"
          end
        end
        adjustment = [@adjustment_hash,@subordinate_hash,@adjustment_cap,@standard_hash,@home_hash,@property_hash]
        make_adjust(adjustment,program_sheet)
        create_program_association_with_adjustment(program_sheet)
      end
    end
    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def jumbo_700
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "JUMBO 700")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        first_key = ''
        @adjustment_hash = {}
        @state_adjustment = {}
        @data_hash = {}
        @sheet = sheet
        @ltv_data = []
        key = ''
        key1 = ''
        key2 = ''
        key3 = ''
        ltv_key = ''
        cltv_key = ''
        c_val = ''
        cc = ''
        value = ''
        state_key = ''
        adj_key = []
        (10..21).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_property sheet
                @programs_ids << @program.id
                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..3).each_with_index do |index, c_i|
                    rrr = rr + max_row -1
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      elsif (c_i == 1)
                        @block_hash[key][21] = value
                      elsif (c_i == 2)
                        @block_hash[key][30] = value
                      elsif (c_i == 3)
                        @block_hash[key][45] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # adjustments
        (23..47).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(25)
          if (row.compact.count > 1)
            (0..9).each do |max_column|
              cc = max_column
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "ELITE JUMBO 700 SERIES ADJUSTMENTS"
                    key = "LoanSize/LoanAmount/FICO/LTV"
                    @adjustment_hash[key] = {}
                    @adjustment_hash[key]["Jumbo"] = {}
                    @adjustment_hash["LoanSize/LoanAmount/PropertyType/LTV"] = {}
                    @adjustment_hash["LoanSize/LoanAmount/PropertyType/LTV"]["Jumbo"] = {}
                  end
                  if value == "Loan Amount <= $1,000,000"
                    key1 = "0-1000000"
                    @adjustment_hash[key]["Jumbo"][key1] = {}
                  end
                  if value == "Loan Amount > $1,000,000"
                    key1 = "1000000-Inf"
                    @adjustment_hash[key]["Jumbo"][key1] = {}
                    @adjustment_hash["LoanSize/LoanAmount/PropertyType/LTV"]["Jumbo"][key1] = {}
                  end
                  if r >= 27 && r <= 33 && cc == 1
                    if value.include?("-")
                      ltv_key = value.tr('A-Z ','')
                    else
                      ltv_key = get_value value
                    end
                    @adjustment_hash[key]["Jumbo"][key1][ltv_key] = {}
                  end
                  if r >= 27 && r <= 33 && cc > 4 && cc <= 9
                    cltv_key = get_value @ltv_data[cc-1]
                    @adjustment_hash[key]["Jumbo"][key1][ltv_key][cltv_key] = value
                  end
                  if r >= 35 && r <= 40 && cc == 1
                    if value.include?("-")
                      ltv_key = value.tr('A-Z ','')
                    else
                      ltv_key = get_value value
                    end
                    @adjustment_hash[key]["Jumbo"][key1][ltv_key] = {}
                  end
                  if r >= 35 && r <= 40 && cc >= 5 && cc <= 9
                    cltv_key = get_value @ltv_data[cc-1]
                    @adjustment_hash[key]["Jumbo"][key1][ltv_key][cltv_key] = value
                  end
                  if r >= 41 && r <= 44 && cc == 1
                    if value == "*Condos"
                      ltv_key = "Condo"
                    elsif value.downcase.include?('cashout')
                      ltv_key = "Cash Put"
                    else
                      ltv_key = value
                    end
                    @adjustment_hash["LoanSize/LoanAmount/PropertyType/LTV"]["Jumbo"][key1][ltv_key] = {}
                  end
                  if r >= 41 && r <= 44 && cc >= 5 && cc <= 9
                    cltv_key = get_value @ltv_data[cc-1]
                    @adjustment_hash["LoanSize/LoanAmount/PropertyType/LTV"]["Jumbo"][key1][ltv_key][cltv_key] = {}
                    @adjustment_hash["LoanSize/LoanAmount/PropertyType/LTV"]["Jumbo"][key1][ltv_key][cltv_key] = value
                  end
                  if r >= 45 && r <= 46 && cc == 1
                    ltv_key = value.split("Property").first
                    @adjustment_hash["LoanSize/LoanAmount/PropertyType/LTV"]["Jumbo"][key1][ltv_key] = {}
                  end
                  if r >= 45 && r <= 46 && cc >= 5 && cc <= 9
                    cltv_key = get_value @ltv_data[cc-1]
                    @adjustment_hash["LoanSize/LoanAmount/PropertyType/LTV"]["Jumbo"][key1][ltv_key][cltv_key] = {}
                    @adjustment_hash["LoanSize/LoanAmount/PropertyType/LTV"]["Jumbo"][key1][ltv_key][cltv_key] = value
                  end
                  if r == 47 && cc == 1
                    @adjustment_hash["LoanSize/LoanAmount/MiscAdjuster/LTV"] = {}
                    @adjustment_hash["LoanSize/LoanAmount/MiscAdjuster/LTV"]["Jumbo"] = {}
                    @adjustment_hash["LoanSize/LoanAmount/MiscAdjuster/LTV"]["Jumbo"][key1] = {}
                    @adjustment_hash["LoanSize/LoanAmount/MiscAdjuster/LTV"]["Jumbo"][key1]["Escrow Waiver"] = {}
                  end
                  if r == 47 && cc >= 5 && cc <= 9
                    cltv_key = get_value @ltv_data[cc-1]
                    @adjustment_hash["LoanSize/LoanAmount/MiscAdjuster/LTV"]["Jumbo"][key1]["Escrow Waiver"][cltv_key] = {}
                    @adjustment_hash["LoanSize/LoanAmount/MiscAdjuster/LTV"]["Jumbo"][key1]["Escrow Waiver"][cltv_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end

            #For STATE ADJUSTMENTS
            (12..16).each do |max_column|
              cc = max_column
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "STATE ADJUSTMENTS"
                    state_key = "State"
                    @state_adjustment[state_key] = {}
                  end
                  if r >= 24 && r < 28 && cc == 12
                    adj_key = value.split(', ')
                    adj_key.each do |f_key|
                      key3 = f_key
                      ccc = cc + 4
                      c_val = sheet_data.cell(r,ccc)
                      @state_adjustment[state_key][key3] = c_val
                    end
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end

            #For MISCELLANEOUS
            (12..16).each do |max_column|
              cc = max_column
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "MISCELLANEOUS"
                    @adjustment_hash["State"] = {}
                    @adjustment_hash["State"]["NY"] = {}
                  end
                  if r == 31 && cc == 12
                    ccc = cc + 4
                    c_val = sheet_data.cell(r,ccc)
                    @adjustment_hash["State"]["NY"] = c_val
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@state_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end

    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def jumbo_6200
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "JUMBO 6200")
        sheet_data = @xlsx.sheet(sheet)
        first_key = ''
        second_key = ''
        cc = ''
        cltv_key = ''
        key_val = ''
        @data_hash = {}
        @key_data = []
        @key2_data = []
        @programs_ids = []
        (10..34).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_property sheet
                @programs_ids << @program.id
                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..3).each_with_index do |index, c_i|
                    rrr = rr + max_row -1
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      elsif (c_i == 1)
                        @block_hash[key][21] = value
                      elsif (c_i == 2)
                        @block_hash[key][30] = value
                      elsif (c_i == 3)
                        @block_hash[key][45] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # Adjustments
        (37..88).each do |r|
          row = sheet_data.row(r)
          @key_data = sheet_data.row(40)
          @key2_data = sheet_data.row(83)
          if (row.compact.count >= 1)
            (0..13).each do |max_column|
              cc = max_column
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "PREMIER JUMBO 6200 SERIES ADJUSTMENTS"
                    first_key = "LoanSize/LoanPurpose/FICO/LTV"
                    @data_hash[first_key] = {}
                    @data_hash[first_key]["Jumbo"] = {}
                  end
                  if value == "Purchase Transaction"
                    second_key = "Purchase"
                    @data_hash[first_key]["Jumbo"][second_key] = {}
                  end
                  if value == "Rate/Term Transaction"
                    @data_hash["LoanSize/RefinanceOption/FICO/LTV"] = {}
                    @data_hash["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"] = {}
                    @data_hash["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"]["Rate and Term"] = {}
                  end
                  if value == "Cash Out Transaction"
                    second_key = "Cash Out"
                    @data_hash["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"][second_key] = {}
                    @data_hash["LoanSize/RefinanceOption/LoanAmount/LTV"] = {}
                    @data_hash["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"] = {}
                    @data_hash["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"][second_key] = {}
                    @data_hash["LoanSize/RefinanceOption/PropertyType/LTV"] = {}
                    @data_hash["LoanSize/RefinanceOption/PropertyType/LTV"]["Jumbo"] = {}
                    @data_hash["LoanSize/RefinanceOption/PropertyType/LTV"]["Jumbo"][second_key] = {}
                    @data_hash["LoanSize/RefinanceOption/Term/LTV"] = {}
                    @data_hash["LoanSize/RefinanceOption/Term/LTV"]["Jumbo"] = {}
                    @data_hash["LoanSize/RefinanceOption/Term/LTV"]["Jumbo"][second_key] = {}
                  end

                  # Purchase Transaction Adjustment
                  if r >= 41 && r <= 46 && cc == 1
                    if value.include?("-")
                      cltv_key = value.tr('A-Z ','')
                    else
                      cltv_key = get_value value
                    end
                    @data_hash[first_key]["Jumbo"][second_key][cltv_key] = {}
                  end
                  if r >= 41 && r <= 46 && cc >= 6 && cc <= 13
                    key_val = get_value @key_data[cc-1]
                    @data_hash[first_key]["Jumbo"][second_key][cltv_key][key_val] = value
                  end

                  # Rate/Term Transaction Adjustment
                  if r >= 49 && r <= 54 && cc == 1
                    if value.include?("-")
                      cltv_key = value.tr('A-Z ','')
                    else
                      cltv_key = get_value value
                    end
                    @data_hash["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"]["Rate and Term"][cltv_key] = {}
                  end
                  if r >= 49 && r <= 54 && cc >= 6 && cc <= 13
                    key_val = get_value @key_data[cc-1]
                    @data_hash["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"]["Rate and Term"][cltv_key][key_val] = value
                  end

                  # Cash Out Transaction Adjustment
                  if r >= 57 && r <= 61 && cc == 1
                    if value.include?("-")
                      cltv_key = value.tr('A-Z, ','')
                    else
                      cltv_key = get_value value
                    end
                    @data_hash["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"][second_key][cltv_key] = {}
                  end
                  if r >= 57 && r <= 61 && cc >= 6 && cc <= 13
                    key_val = get_value @key_data[cc-1]
                    @data_hash["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"][second_key][cltv_key][key_val] = value
                  end
                  if r >= 62 && r <= 65 && cc == 1
                    if value.include?("-")
                      cltv_key = value.tr('A-Za-z$,  ','')
                    else
                      cltv_key = get_value value
                    end
                    @data_hash["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"][second_key][cltv_key] = {}
                  end
                  if r >= 62 && r <= 65 && cc >= 6 && cc <= 13
                    key_val = get_value @key_data[cc-1]
                    @data_hash["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"][second_key][cltv_key][key_val] = {}
                    @data_hash["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"][second_key][cltv_key][key_val] = value
                  end
                  if r >= 66 && r <= 69 && cc == 1
                    if value.downcase.include?('units')
                      cltv_key = value.split('s').first
                    elsif value.downcase.include?('investment')
                      cltv_key = "Investment Property"
                    else
                      cltv_key = value
                    end
                    @data_hash["LoanSize/RefinanceOption/PropertyType/LTV"]["Jumbo"][second_key][cltv_key] = {}
                  end
                  if r >= 66 && r <= 69 && cc >= 6 && cc <= 13
                    key_val = get_value @key_data[cc-1]
                    @data_hash["LoanSize/RefinanceOption/PropertyType/LTV"]["Jumbo"][second_key][cltv_key][key_val] = {}
                    @data_hash["LoanSize/RefinanceOption/PropertyType/LTV"]["Jumbo"][second_key][cltv_key][key_val] = value
                  end
                  if r >= 70 && r <= 75 && cc == 1
                    cltv_key = value.tr('a-zA-Z-() ','')
                    @data_hash["LoanSize/RefinanceOption/Term/LTV"]["Jumbo"][second_key][cltv_key] = {}
                  end
                  if r >= 70 && r <= 75 && cc >= 6 && cc <= 13
                    key_val = get_value @key_data[cc-1]
                    @data_hash["LoanSize/RefinanceOption/Term/LTV"]["Jumbo"][second_key][cltv_key][key_val] = {}
                    @data_hash["LoanSize/RefinanceOption/Term/LTV"]["Jumbo"][second_key][cltv_key][key_val] = value
                  end
                  if r == 76 && cc == 1
                    cltv_key = value
                    @data_hash["LoanSize/RefinanceOption/MiscAdjuster/LTV"] = {}
                    @data_hash["LoanSize/RefinanceOption/MiscAdjuster/LTV"]["Jumbo"] = {}
                    @data_hash["LoanSize/RefinanceOption/MiscAdjuster/LTV"]["Jumbo"][second_key] = {}
                    @data_hash["LoanSize/RefinanceOption/MiscAdjuster/LTV"]["Jumbo"][second_key][cltv_key] = {}
                  end
                  if r == 76 && cc >= 6 &&  cc <= 13
                    key_val = get_value @key_data[cc-1]
                    @data_hash["LoanSize/RefinanceOption/MiscAdjuster/LTV"]["Jumbo"][second_key][cltv_key][key_val] = {}
                    @data_hash["LoanSize/RefinanceOption/MiscAdjuster/LTV"]["Jumbo"][second_key][cltv_key][key_val] = value
                  end
                  if r == 77 && cc == 1
                    @data_hash["LoanSize/RefinanceOption/State/LTV"] = {}
                    @data_hash["LoanSize/RefinanceOption/State/LTV"]["Jumbo"] = {}
                    @data_hash["LoanSize/RefinanceOption/State/LTV"]["Jumbo"][second_key] = {}
                    @data_hash["LoanSize/RefinanceOption/State/LTV"]["Jumbo"][second_key]["FL"] = {}
                    @data_hash["LoanSize/RefinanceOption/State/LTV"]["Jumbo"][second_key]["NV"] = {}
                  end
                  if r == 77 && cc >= 6 &&  cc <= 13
                    key_val = get_value @key_data[cc-1]
                    @data_hash["LoanSize/RefinanceOption/State/LTV"]["Jumbo"][second_key]["NV"][key_val] = {}
                    @data_hash["LoanSize/RefinanceOption/State/LTV"]["Jumbo"][second_key]["FL"][key_val] = {}
                    @data_hash["LoanSize/RefinanceOption/State/LTV"]["Jumbo"][second_key]["NV"][key_val] = value
                    @data_hash["LoanSize/RefinanceOption/State/LTV"]["Jumbo"][second_key]["FL"][key_val] = value
                  end

                  # MISCELLANEOUS Adjustment
                  if value == "MISCELLANEOUS"
                    second_key = "MiscAdjuster/State"
                    @data_hash[second_key] = {}
                    @data_hash[second_key]["Miscellaneous"] = {}
                    @data_hash[second_key]["Miscellaneous"]["NY"] = {}
                    k_val = sheet_data.cell(r+1,cc)
                    v_val = sheet_data.cell(r+1,cc+3)
                    @data_hash[second_key]["Miscellaneous"]["NY"][k_val] = v_val
                  end

                  # MAX PRICE AFTER ADJUSTMENTS
                  if value == "MAX PRICE AFTER ADJUSTMENTS"
                    second_key = "LoanAmount/LoanType/Term"
                    @data_hash[second_key] = {}
                    @data_hash["LoanAmount/LoanType"] = {}
                  end
                  if r >= 84 && r <= 85 && cc == 1
                    if value.include?('<')
                      cltv_key = "0-1000000"
                    else
                      cltv_key = "1000000-Inf"
                    end
                    @data_hash[second_key][cltv_key] = {}
                    @data_hash[second_key][cltv_key]["Fixed"] = {}
                    @data_hash["LoanAmount/LoanType"][cltv_key] = {}
                    @data_hash["LoanAmount/LoanType"][cltv_key]["ARM"] = {}
                  end
                  if r >= 84 && r <= 85 && cc >= 2 && cc <= 3
                    key_val = @key2_data[cc-1].tr('A-Za-z ','')
                    @data_hash[second_key][cltv_key]["Fixed"][key_val] = value
                  end
                  if r >= 84 && r <= 85 && cc == 4
                    @data_hash["LoanAmount/LoanType"][cltv_key]["ARM"] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@data_hash]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end

    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def jumbo_7200_6700
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "JUMBO 7200 & 6700")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @purchase_adjustment = {}
        @rate_adjustment = {}
        @other_adjustment = {}
        @jumbo_purchase_adjustment = {}
        @jumbo_rate_adjustment = {}
        @jumbo_other_adjustment = {}
        @cltv_data = []
        @ltv_data = []
        primary_key = ''
        secondary_key = ''
        cltv_key = ''
        m_key = ''
        max_key = ''
        ltv_key = ''
        key = ''
        adj_key = ''
        (10..22).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                if cc < 5
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  program_property sheet
                  @programs_ids << @program.id
                  @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..3).each_with_index do |index, c_i|
                      rrr = rr + max_row -1
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        elsif (c_i == 1)
                          @block_hash[key][21] = value
                        elsif (c_i == 2)
                          @block_hash[key][30] = value
                        elsif (c_i == 3)
                          @block_hash[key][45] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                    @block_hash.shift
                  end

                  @program.update(base_rate: @block_hash)
                end
                @program.update(base_rate: @block_hash)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        (56..64).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                if cc < 5
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  program_property sheet
                  @programs_ids << @program.id

                  # @program.adjustments.destroy_all
                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..3).each_with_index do |index, c_i|
                      rrr = rr + max_row -1
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        elsif (c_i == 1)
                          @block_hash[key][21] = value
                        elsif (c_i == 2)
                          @block_hash[key][30] = value
                        elsif (c_i == 3)
                          @block_hash[key][45] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                    @block_hash.shift
                  end
                  @program.update(base_rate: @block_hash)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        (12..46).each do |r|
          row = sheet_data.row(r)
          @cltv_data = sheet_data.row(13)
          if row.compact.count >= 1
            (6..16).each do |cc|
              value = sheet_data.cell(r,cc)
              begin
                if value.present?
                  if value == "Purchase Transaction"
                    primary_key = "LoanPurpose/FICO/LTV"
                    @purchase_adjustment[primary_key] = {}
                    @purchase_adjustment[primary_key]["Purchase"] = {}
                  elsif value == "Rate/Term Transaction"
                    primary_key = "RefinanceOption/FICO/LTV"
                    @rate_adjustment[primary_key] = {}
                    @rate_adjustment[primary_key]["Rate and Term"] = {}
                  elsif value == "Cash Out Transaction"
                    @rate_adjustment[primary_key]["Cash Out"] = {}
                    @rate_adjustment["RefinanceOption/LoanAmount/LTV"] = {}
                    @rate_adjustment["RefinanceOption/LoanAmount/LTV"]["Cash Out"] = {}
                    # @rate_adjustment[primary_key]["Cash Out"]["LoanAmount"] = {}
                    @rate_adjustment["RefinanceOption/PropertyType/LTV"] = {}
                    @rate_adjustment["RefinanceOption/PropertyType/LTV"]["Cash Out"] = {}
                    @rate_adjustment["RefinanceOption/LoanType/Term/State/LTV"] = {}
                    @rate_adjustment["RefinanceOption/LoanType/Term/State/LTV"]["Cash Out"] = {}
                    @rate_adjustment["RefinanceOption/LoanType/Term/State/LTV"]["Cash Out"]["Fixed"] = {}
                    @rate_adjustment["RefinanceOption/LoanType/Term/State/LTV"]["Cash Out"]["Fixed"][30] = {}
                  end
                  # Purchase Transaction Adjustment
                  if r >= 14 && r <= 19 && cc == 6
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @purchase_adjustment[primary_key]["Purchase"][secondary_key] = {}
                  end
                  if r >= 14 && r <= 19 && cc >= 10 && cc <= 16
                    cltv_key = get_value @cltv_data[cc-1]
                    @purchase_adjustment[primary_key]["Purchase"][secondary_key][cltv_key] = {}
                    @purchase_adjustment[primary_key]["Purchase"][secondary_key][cltv_key] = value
                  end

                  # Rate/Term Transaction Adjustment
                  if r >= 22 && r <= 27 && cc == 6
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @rate_adjustment[primary_key]["Rate and Term"][secondary_key] = {}
                  end
                  if r >= 22 && r <= 27 && cc >= 10 && cc <= 16
                    cltv_key = get_value @cltv_data[cc-1]
                    @rate_adjustment[primary_key]["Rate and Term"][secondary_key][cltv_key] = {}
                    @rate_adjustment[primary_key]["Rate and Term"][secondary_key][cltv_key] = value
                  end

                  # Cash Out Transaction Adjustment
                  if r >= 30 && r <= 34 && cc == 6
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @rate_adjustment[primary_key]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 30 && r <= 34 && cc >= 10 && cc <= 16
                    cltv_key = get_value @cltv_data[cc-1]
                    @rate_adjustment[primary_key]["Cash Out"][secondary_key][cltv_key] = {}
                    @rate_adjustment[primary_key]["Cash Out"][secondary_key][cltv_key] = value
                  end
                  if r >= 35 && r <= 38 && cc == 6
                    if value.include?("-")
                      secondary_key = value.tr('A-Za-z$, ','')
                    else
                      secondary_key = get_value value
                    end
                    @rate_adjustment["RefinanceOption/LoanAmount/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 35 && r <= 38 && cc >= 10 && cc <= 16
                    cltv_key = get_value @cltv_data[cc-1]
                    @rate_adjustment["RefinanceOption/LoanAmount/LTV"]["Cash Out"][secondary_key][cltv_key] = {}
                    @rate_adjustment["RefinanceOption/LoanAmount/LTV"]["Cash Out"][secondary_key][cltv_key] = value
                  end
                  if r >= 39 && r <= 42 && cc == 6
                    if value.downcase.include?('units')
                      secondary_key = value.split('s').first
                    elsif value.downcase.include?('investment')
                       secondary_key = "Investment Property"
                    else
                      secondary_key = value
                    end
                    @rate_adjustment["RefinanceOption/PropertyType/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 39 && r <= 42 && cc >= 10 && cc <= 16
                    cltv_key = get_value @cltv_data[cc-1]
                    @rate_adjustment["RefinanceOption/PropertyType/LTV"]["Cash Out"][secondary_key][cltv_key] = {}
                    @rate_adjustment["RefinanceOption/PropertyType/LTV"]["Cash Out"][secondary_key][cltv_key] = value
                  end
                  if r == 43 && cc == 6
                    @rate_adjustment["RefinanceOption/LoanType/Term/State/LTV"]["Cash Out"]["Fixed"][30]["non-ca"] = {}
                  end
                  if r == 43 && cc >= 10 && cc <= 16
                    cltv_key = get_value @cltv_data[cc-1]
                    @rate_adjustment["RefinanceOption/LoanType/Term/State/LTV"]["Cash Out"]["Fixed"][30]["non-ca"][cltv_key] = {}
                    @rate_adjustment["RefinanceOption/LoanType/Term/State/LTV"]["Cash Out"]["Fixed"][30]["non-ca"][cltv_key] = value
                  end
                  if r == 44 && cc == 6
                    @rate_adjustment["RefinanceOption/LoanType/Term/State/LTV"]["Cash Out"]["Fixed"][30]["CA"] = {}
                  end
                  if r == 44 && cc >= 10 && cc <= 16
                    cltv_key = get_value @cltv_data[cc-1]
                    @rate_adjustment["RefinanceOption/LoanType/Term/State/LTV"]["Cash Out"]["Fixed"][30]["CA"][cltv_key] = {}
                    @rate_adjustment["RefinanceOption/LoanType/Term/State/LTV"]["Cash Out"]["Fixed"][30]["CA"][cltv_key] = value
                  end
                  if r == 45 && cc == 6
                    @rate_adjustment["RefinanceOption/MiscAdjuster/State/LTV"] = {}
                    @rate_adjustment["RefinanceOption/MiscAdjuster/State/LTV"]["Cash Out"] = {}
                    @rate_adjustment["RefinanceOption/MiscAdjuster/State/LTV"]["Cash Out"]["Escrow Waiver"] = {}
                    @rate_adjustment["RefinanceOption/MiscAdjuster/State/LTV"]["Cash Out"]["Escrow Waiver"]["non-ny"] = {}
                  end
                  if r == 45 && cc >= 10 && cc <= 16
                    cltv_key = get_value @cltv_data[cc-1]
                    @rate_adjustment["RefinanceOption/MiscAdjuster/State/LTV"]["Cash Out"]["Escrow Waiver"]["non-ny"][cltv_key] = {}
                    @rate_adjustment["RefinanceOption/MiscAdjuster/State/LTV"]["Cash Out"]["Escrow Waiver"]["non-ny"][cltv_key] = value
                  end
                  if r == 46 && cc == 6
                    @rate_adjustment["RefinanceOption/State/LTV"] = {}
                    @rate_adjustment["RefinanceOption/State/LTV"]["Cash Out"] = {}
                    @rate_adjustment["RefinanceOption/State/LTV"]["Cash Out"]["FL"] = {}
                    @rate_adjustment["RefinanceOption/State/LTV"]["Cash Out"]["NV"] = {}
                  end
                  if r == 46 && cc >= 10 && cc <= 16
                    cltv_key = get_value @cltv_data[cc-1]
                    @rate_adjustment["RefinanceOption/State/LTV"]["Cash Out"]["FL"][cltv_key] = {}
                    @rate_adjustment["RefinanceOption/State/LTV"]["Cash Out"]["NV"][cltv_key] = {}
                    @rate_adjustment["RefinanceOption/State/LTV"]["Cash Out"]["FL"][cltv_key] = value
                    @rate_adjustment["RefinanceOption/State/LTV"]["Cash Out"]["NV"][cltv_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end

            (1..4).each do |cc|
              value = sheet_data.cell(r,cc)
              begin
                if value.present?
                  # MISCELLANEOUS
                  if r == 25 && cc == 1
                    m_key = "MiscAdjuster/State"
                    @other_adjustment[m_key] = {}
                    @other_adjustment[m_key]["Miscellaneous"] = {}
                    @other_adjustment[m_key]["Miscellaneous"]["NY"] = {}
                  end
                  if r == 25 && cc == 4
                    @other_adjustment[m_key]["Miscellaneous"]["NY"] = value
                  end
                  # MAX PRICE AFTER ADJUSTMENTS
                  if r == 29 && cc == 1
                    @other_adjustment["LoanAmount/LoanType/Term"] = {}
                    @other_adjustment["LoanAmount/LoanType/Term"]["0-1000000"] = {}
                    @other_adjustment["LoanAmount/LoanType/Term"]["0-1000000"]["Fixed"] = {}
                    @other_adjustment["LoanAmount/LoanType/Term"]["0-1000000"]["Fixed"][30] = {}
                  end
                  if r == 29 && cc == 4
                    @other_adjustment["LoanAmount/LoanType/Term"]["0-1000000"]["Fixed"][30] = value
                  end
                  if r == 30 && cc == 1
                    @other_adjustment["LoanAmount/LoanType/Term"]["1000000-Inf"] = {}
                    @other_adjustment["LoanAmount/LoanType/Term"]["1000000-Inf"]["Fixed"] = {}
                    @other_adjustment["LoanAmount/LoanType/Term"]["1000000-Inf"]["Fixed"][30] = {}
                  end
                  if r == 30 && cc == 4
                    @other_adjustment["LoanAmount/LoanType/Term"]["1000000-Inf"]["Fixed"][30] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        
        adjustment = [@purchase_adjustment,@rate_adjustment,@other_adjustment]
        make_adjust(adjustment,sheet)
        (56..77).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(59)
          if row.compact.count >= 1
            (10..16).each do |cc|
              value = sheet_data.cell(r,cc)
              begin
                if value.present?
                  if value == "Purchase Transaction"
                    primary_key = "LoanSize/LoanPurpose/FICO/LTV"
                    @jumbo_purchase_adjustment[primary_key] = {}
                    @jumbo_purchase_adjustment[primary_key]["Jumbo"] = {}
                    @jumbo_purchase_adjustment[primary_key]["Jumbo"]["Purchase"] = {}
                  elsif value == "Rate/Term Transaction"
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/FICO/LTV"] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"]["Rate and Term"] = {}
                  elsif value == "MISCELLANEOUS"
                    primary_key = "Jumbo/NY/FICO/LTV"
                    @jumbo_other_adjustment[primary_key] = {}
                  end
                  # Purchase Transaction Adjustment
                  if r >= 60 && r <= 63 && cc == 10
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @jumbo_purchase_adjustment[primary_key]["Jumbo"]["Purchase"][secondary_key] = {}
                  end
                  if r >= 60 && r <= 63 && cc >= 15 && cc <= 16
                    ltv_key = get_value @ltv_data[cc-1]
                    @jumbo_purchase_adjustment[primary_key]["Jumbo"]["Purchase"][secondary_key][ltv_key] = {}
                    @jumbo_purchase_adjustment[primary_key]["Jumbo"]["Purchase"][secondary_key][ltv_key] = value
                  end

                  # Rate/Term Transaction Adjustment
                  if r >= 66 && r <= 69 && cc == 10
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"]["Rate and Term"][secondary_key] = {}
                  end
                  if r >= 66 && r <= 69 && cc >= 15 && cc <= 16
                    ltv_key = get_value @ltv_data[cc-1]
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"]["Rate and Term"][secondary_key][ltv_key] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/FICO/LTV"]["Jumbo"]["Rate and Term"][secondary_key][ltv_key] = value
                  end
                  if r == 70 && cc == 10
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/LoanAmount/LTV"] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"]["Rate and Term"] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"]["Rate and Term"]["0-1000000"] = {}
                  end
                  if r == 70 && cc >= 15 && cc <= 16
                    ltv_key = get_value @ltv_data[cc-1]
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"]["Rate and Term"]["0-1000000"][ltv_key] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"]["Rate and Term"]["0-1000000"][ltv_key] = value
                  end
                  if r == 71 && cc == 10
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"]["Rate and Term"]["1000000-Inf"] = {}
                  end
                  if r == 71 && cc >= 15 && cc <= 16
                    ltv_key = get_value @ltv_data[cc-1]
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"]["Rate and Term"]["1000000-Inf"][ltv_key] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/LoanAmount/LTV"]["Jumbo"]["Rate and Term"]["1000000-Inf"][ltv_key] = value
                  end
                  if r == 72 && cc == 10
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"]["Jumbo"] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"]["Jumbo"]["Rate and Term"] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"]["Jumbo"]["Rate and Term"]["FL"] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"]["Jumbo"]["Rate and Term"]["NV"] = {}
                  end
                  if r == 72 && cc >= 15 && cc <= 16
                    ltv_key = get_value @ltv_data[cc-1]
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"]["Jumbo"]["Rate and Term"]["FL"][ltv_key] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"]["Jumbo"]["Rate and Term"]["NV"][ltv_key] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"]["Jumbo"]["Rate and Term"]["FL"][ltv_key] = value
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"]["Jumbo"]["Rate and Term"]["NV"][ltv_key] = value
                  end
                  if r == 73 && cc == 10
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"]["Jumbo"]["Rate and Term"]["CA"] = {}
                  end
                  if r == 73 && cc >= 15 && cc <= 16
                    ltv_key = get_value @ltv_data[cc-1]
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"]["Jumbo"]["Rate and Term"]["CA"][ltv_key] = {}
                    @jumbo_rate_adjustment["LoanSize/RefinanceOption/State/LTV"]["Jumbo"]["Rate and Term"]["CA"][ltv_key] = value
                  end
                  if r == 74 && cc == 10
                    @jumbo_rate_adjustment["LoanSize/MiscAdjuster/LTV"] = {}
                    @jumbo_rate_adjustment["LoanSize/MiscAdjuster/LTV"]["Jumbo"] = {}
                    @jumbo_rate_adjustment["LoanSize/MiscAdjuster/LTV"]["Jumbo"]["Escrow Waiver"] = {}
                  end
                  if r == 74 && cc >= 15 && cc <= 16
                    ltv_key = get_value @ltv_data[cc-1]
                    @jumbo_rate_adjustment["LoanSize/MiscAdjuster/LTV"]["Jumbo"]["Escrow Waiver"][ltv_key] = {}
                    @jumbo_rate_adjustment["LoanSize/MiscAdjuster/LTV"]["Jumbo"]["Escrow Waiver"][ltv_key] = value
                  end
                  if r == 77 && cc == 10
                    @jumbo_rate_adjustment["LoanSize/MiscAdjuster/LTV"]["Jumbo"]["Miscellaneous"] = {}
                  end
                  if r == 77 && cc >= 16
                    @jumbo_rate_adjustment["LoanSize/MiscAdjuster/LTV"]["Jumbo"]["Miscellaneous"] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
            (0..3).each do |cc|
              value = sheet_data.cell(r,cc)
              if value.present?
                if r == 71 && cc == 1
                  @jumbo_other_adjustment["LoanSize/LoanAmount"] = {}
                  @jumbo_other_adjustment["LoanSize/LoanAmount"]["Jumbo"] = {}
                  @jumbo_other_adjustment["LoanSize/LoanAmount"]["Jumbo"]["0-1000000"] = {}
                end
                if r == 71 && cc == 3
                  @jumbo_other_adjustment["LoanSize/LoanAmount"]["Jumbo"]["0-1000000"] = value
                end
                if r == 72 && cc == 1
                  @jumbo_other_adjustment["LoanSize/LoanAmount"]["Jumbo"]["1000000-Inf"] = {}
                end
                if r == 72 && cc == 3
                  @jumbo_other_adjustment["LoanSize/LoanAmount"]["Jumbo"]["1000000-Inf"] = value
                end
              end
            end
          end
        end
        adjustment = [@jumbo_purchase_adjustment,@jumbo_rate_adjustment,@jumbo_other_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
        end
      end
    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def jumbo_6600
    @programs_ids = []
    @purchase_adjustment = {}
    @rate_adjustment = {}
    @adjustment_hash = {}
    @other_adjustment = {}
    primary_key = ''
    secondary_key = ''
    cltv_key = ''
    key = ''
    adj_key = ''
    @xlsx.sheets.each do |sheet|
      if (sheet == "JUMBO 6600")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        (10..35).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_property sheet
                @programs_ids << @program.id
                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..3).each_with_index do |index, c_i|
                    rrr = rr + max_row -1
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      elsif (c_i == 1)
                        @block_hash[key][21] = value
                      elsif (c_i == 2)
                        @block_hash[key][30] = value
                      elsif (c_i == 3)
                        @block_hash[key][45] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # adjustments
        (39..84).each do |r|
          row = sheet_data.row(r)
          @cltv_data = sheet_data.row(40)
          @max_data = sheet_data.row(82)
          if row.compact.count >= 1
            (0..14).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Purchase Transaction"
                    @purchase_adjustment["LoanPurpose/FICO/LTV"] = {}
                    @purchase_adjustment["LoanPurpose/FICO/LTV"]["Purchase"] = {}
                  elsif value == "Rate/Term Transaction"
                    @rate_adjustment["RefinanceOption/FICO/LTV"] = {}
                    @rate_adjustment["RefinanceOption/FICO/LTV"]["Rate and Term"] = {}
                  elsif value == "Cash Out Transaction"
                    @adjustment_hash["RefinanceOption/FICO/LTV"] = {}
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                    @adjustment_hash["RefinanceOption/LoanAmount/LTV"] = {}
                    @adjustment_hash["RefinanceOption/LoanAmount/LTV"]["Cash Out"] = {}
                    @adjustment_hash["RefinanceOption/PropertyType/LTV"] = {}
                    @adjustment_hash["RefinanceOption/PropertyType/LTV"]["Cash Out"] = {}
                  elsif value == "MISCELLANEOUS"
                    @other_adjustment["MiscAdjuster/State"] = {}
                    @other_adjustment["MiscAdjuster/State"]["Miscellaneous"] = {}
                    @other_adjustment["MiscAdjuster/State"]["Miscellaneous"]["NY"] = {}
                  elsif value == "MAX PRICE AFTER ADJUSTMENTS"
                    @other_adjustment["LoanAmount/Term"] = {}
                  end
                  # Purchase Transaction Adjustment
                  if r >= 41 && r <= 47 && cc == 1
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @purchase_adjustment["LoanPurpose/FICO/LTV"]["Purchase"][secondary_key] = {}
                  end
                  if r >= 41 && r <= 47 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @purchase_adjustment["LoanPurpose/FICO/LTV"]["Purchase"][secondary_key][cltv_key] = {}
                    @purchase_adjustment["LoanPurpose/FICO/LTV"]["Purchase"][secondary_key][cltv_key] = value
                  end

                  # Rate/Term Transaction Adjustment
                  if r >= 50 && r <= 56 && cc == 1
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @rate_adjustment["RefinanceOption/FICO/LTV"]["Rate and Term"][secondary_key] = {}
                  end
                  if r >= 50 && r <= 56 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @rate_adjustment["RefinanceOption/FICO/LTV"]["Rate and Term"][secondary_key][cltv_key] = {}
                    @rate_adjustment["RefinanceOption/FICO/LTV"]["Rate and Term"][secondary_key][cltv_key] = value
                  end

                  # Cash Out Transaction Adjustment
                  if r >= 59 && r <= 65 && cc == 1
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 59 && r <= 65 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][cltv_key] = value
                  end
                  if r >= 66 && r <= 68 && cc == 1
                    if value.include?("-")
                      secondary_key = value.tr('A-Za-z$ ','')
                    else
                      secondary_key = get_value value
                    end
                    @adjustment_hash["RefinanceOption/LoanAmount/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 66 && r <= 68 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @adjustment_hash["RefinanceOption/LoanAmount/LTV"]["Cash Out"][secondary_key][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/LoanAmount/LTV"]["Cash Out"][secondary_key][cltv_key] = value
                  end
                  if r >= 69 && r <= 74 && cc == 1
                    if value.downcase.include?('units')
                      secondary_key = value.split("s").first
                    else
                      secondary_key = value
                    end 
                    @adjustment_hash["RefinanceOption/PropertyType/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 69 && r <= 74 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @adjustment_hash["RefinanceOption/PropertyType/LTV"]["Cash Out"][secondary_key][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/PropertyType/LTV"]["Cash Out"][secondary_key][cltv_key] = value
                  end
                  if r == 75 && cc == 1
                    @adjustment_hash["RefinanceOption/MiscAdjuster/LTV"] = {}
                    @adjustment_hash["RefinanceOption/MiscAdjuster/LTV"]["Cash Out"] = {}
                    @adjustment_hash["RefinanceOption/MiscAdjuster/LTV"]["Cash Out"]["Escrow Waiver"] = {}
                  end
                  if r == 75 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @adjustment_hash["RefinanceOption/MiscAdjuster/LTV"]["Cash Out"]["Escrow Waiver"][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/MiscAdjuster/LTV"]["Cash Out"]["Escrow Waiver"][cltv_key] = value
                  end
                  if r == 76 && cc == 1
                    @adjustment_hash["RefinanceOption/State/LTV"] = {}
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"] = {}
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["FL"] = {}
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["NV"] = {}
                  end
                  if r == 76 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["FL"][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["NV"][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["FL"][cltv_key] = value
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["NV"][cltv_key] = value
                  end
                  # Other Adjustments
                  if r == 79 && cc == 4
                    @other_adjustment["MiscAdjuster/State"]["Miscellaneous"]["NY"] = value
                  end
                  if r == 83 && cc == 1
                    @other_adjustment["LoanAmount/Term"] = {}
                    @other_adjustment["LoanAmount/Term"]["0-1000000"] = {}
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["30"] = {}
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["15"] = {}
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["ARM"] = {}
                  end
                  if r == 83 && cc == 2
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["30"] = value
                  end
                  if r == 83 && cc == 3
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["15"] = value
                  end
                  if r == 83 && cc == 4
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["ARM"] = value
                  end
                  if r == 84 && cc == 1
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"] = {}
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["30"] = {}
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["15"] = {}
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["ARM"] = {}
                  end
                  if r == 84 && cc == 2
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["30"] = value
                  end
                  if r == 84 && cc == 3
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["15"] = value
                  end
                  if r == 84 && cc == 4
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["ARM"] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@purchase_adjustment,@rate_adjustment,@adjustment_hash,@other_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def jumbo_7600
    @programs_ids = []
    @purchase_adjustment = {}
    @rate_adjustment = {}
    @adjustment_hash = {}
    @other_adjustment = {}
    primary_key = ''
    secondary_key = ''
    cltv_key = ''
    key = ''
    adj_key = ''
    @xlsx.sheets.each do |sheet|
      if (sheet == "JUMBO 7600")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        (10..36).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_property sheet
                @programs_ids << @program.id
                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..3).each_with_index do |index, c_i|
                    rrr = rr + max_row -1
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      elsif (c_i == 1)
                        @block_hash[key][21] = value
                      elsif (c_i == 2)
                        @block_hash[key][30] = value
                      elsif (c_i == 3)
                        @block_hash[key][45] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # adjustments
        (40..85).each do |r|
          row = sheet_data.row(r)
          @cltv_data = sheet_data.row(41)
          @max_data = sheet_data.row(83)
          if row.compact.count >= 1
            (0..14).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Purchase Transaction"
                    @purchase_adjustment["LoanPurpose/FICO/LTV"] = {}
                    @purchase_adjustment["LoanPurpose/FICO/LTV"]["Purchase"] = {}
                  elsif value == "Rate/Term Transaction"
                    @rate_adjustment["RefinanceOption/FICO/LTV"] = {}
                    @rate_adjustment["RefinanceOption/FICO/LTV"]["Rate and Term"] = {}
                  elsif value == "Cash Out Transaction"
                    @adjustment_hash["RefinanceOption/FICO/LTV"] = {}
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                    @adjustment_hash["RefinanceOption/LoanAmount/LTV"] = {}
                    @adjustment_hash["RefinanceOption/LoanAmount/LTV"]["Cash Out"] = {}
                    @adjustment_hash["RefinanceOption/PropertyType/LTV"] = {}
                    @adjustment_hash["RefinanceOption/PropertyType/LTV"]["Cash Out"] = {}
                  elsif value == "MISCELLANEOUS"
                    @other_adjustment["MiscAdjuster/State"] = {}
                    @other_adjustment["MiscAdjuster/State"]["Miscellaneous"] = {}
                    @other_adjustment["MiscAdjuster/State"]["Miscellaneous"]["NY"] = {}
                  end
                  # Purchase Transaction Adjustment
                  if r >= 42 && r <= 48 && cc == 1
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @purchase_adjustment["LoanPurpose/FICO/LTV"]["Purchase"][secondary_key] = {}
                  end
                  if r >= 42 && r <= 48 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @purchase_adjustment["LoanPurpose/FICO/LTV"]["Purchase"][secondary_key][cltv_key] = {}
                    @purchase_adjustment["LoanPurpose/FICO/LTV"]["Purchase"][secondary_key][cltv_key] = value
                  end

                  # Rate/Term Transaction Adjustment
                  if r >= 51 && r <= 57 && cc == 1
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @rate_adjustment["RefinanceOption/FICO/LTV"]["Rate and Term"][secondary_key] = {}
                  end
                  if r >= 51 && r <= 57 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @rate_adjustment["RefinanceOption/FICO/LTV"]["Rate and Term"][secondary_key][cltv_key] = {}
                    @rate_adjustment["RefinanceOption/FICO/LTV"]["Rate and Term"][secondary_key][cltv_key] = value
                  end

                  # Cash Out Transaction Adjustment
                  if r >= 60 && r <= 66 && cc == 1
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 60 && r <= 66 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][cltv_key] = value
                  end
                  if r >= 67 && r <= 69 && cc == 1
                    if value.include?("-")
                      secondary_key = value.tr('A-Za-z$ ','')
                    else
                      secondary_key = get_value value
                    end
                    @adjustment_hash["RefinanceOption/LoanAmount/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 67 && r <= 69 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @adjustment_hash["RefinanceOption/LoanAmount/LTV"]["Cash Out"][secondary_key][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/LoanAmount/LTV"]["Cash Out"][secondary_key][cltv_key] = value
                  end
                  if r >= 70 && r <= 75 && cc == 1
                    secondary_key = value
                    @adjustment_hash["RefinanceOption/PropertyType/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 70 && r <= 75 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @adjustment_hash["RefinanceOption/PropertyType/LTV"]["Cash Out"][secondary_key][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/PropertyType/LTV"]["Cash Out"][secondary_key][cltv_key] = value
                  end
                  if r == 76 && cc == 1
                    @adjustment_hash["RefinanceOption/MiscAdjuster/LTV"] = {}
                    @adjustment_hash["RefinanceOption/MiscAdjuster/LTV"]["Cash Out"] = {}
                    @adjustment_hash["RefinanceOption/MiscAdjuster/LTV"]["Cash Out"]["Escrow Waiver"] = {}
                  end
                  if r == 76 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @adjustment_hash["RefinanceOption/MiscAdjuster/LTV"]["Cash Out"]["Escrow Waiver"][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/MiscAdjuster/LTV"]["Cash Out"]["Escrow Waiver"][cltv_key] = value
                  end
                  if r == 77 && cc == 1
                    @adjustment_hash["RefinanceOption/State/LTV"] = {}
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"] = {}
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["FL"] = {}
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["NV"] = {}
                  end
                  if r == 77 && cc >= 6 && cc <= 14
                    cltv_key = get_value @cltv_data[cc-1]
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["FL"][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["NV"][cltv_key] = {}
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["FL"][cltv_key] = value
                    @adjustment_hash["RefinanceOption/State/LTV"]["Cash Out"]["NV"][cltv_key] = value
                  end

                  # Other Adjustments
                  if r == 80 && cc == 4
                    @other_adjustment["MiscAdjuster/State"]["Miscellaneous"]["NY"] = value
                  end
                  if r == 84 && cc == 1
                    @other_adjustment["LoanAmount/Term"] = {}
                    @other_adjustment["LoanAmount/Term"]["0-1000000"] = {}
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["30"] = {}
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["15"] = {}
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["ARM"] = {}
                  end
                  if r == 84 && cc == 2
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["30"] = value
                  end
                  if r == 84 && cc == 3
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["15"] = value
                  end
                  if r == 84 && cc == 4
                    @other_adjustment["LoanAmount/Term"]["0-1000000"]["ARM"] = value
                  end
                  if r == 85 && cc == 1
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"] = {}
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["30"] = {}
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["15"] = {}
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["ARM"] = {}
                  end
                  if r == 85 && cc == 2
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["30"] = value
                  end
                  if r == 85 && cc == 3
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["15"] = value
                  end
                  if r == 85 && cc == 4
                    @other_adjustment["LoanAmount/Term"]["1000000-Inf"]["ARM"] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: rr, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@purchase_adjustment,@rate_adjustment,@adjustment_hash,@other_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    # redirect_to programs_import_file_path(@bank)
    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def jumbo_6400
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "JUMBO 6400")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @flex_hash = {}
        @jumbo_flex_hash = {}
        primary_key = ''
        secondary_key = ''
        @cltv_data = []
        (10..41).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && cc < 9
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  program_property sheet
                  @programs_ids << @program.id
                  # @program.adjustments.destroy_all

                  @block_hash = {}
                  key = ''
                  (1..50).each do |max_row|
                    @data = []
                    (0..3).each_with_index do |index, c_i|
                      rrr = rr + max_row -1
                      ccc = cc + c_i
                      value = sheet_data.cell(rrr,ccc)
                      if value.present?
                        if (c_i == 0)
                          key = value
                          @block_hash[key] = {}
                        elsif (c_i == 1)
                          @block_hash[key][21] = value
                        elsif (c_i == 2)
                          @block_hash[key][30] = value
                        elsif (c_i == 3)
                          @block_hash[key][45] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                end
                if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                  @block_hash.shift
                end
                @program.update(base_rate: @block_hash)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        (44..58).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                if cc < 5 && @title == "10/1 ARM - 6410"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  program_property sheet
                  @programs_ids << @program.id
                end
                if @title.present? && cc < 9 && @title == "10/1 ARM - 6410"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  program_property sheet
                  @programs_ids << @program.id
                  @program.adjustments.destroy_all

                  @block_hash = {}
                  key = ''
                    (1..50).each do |max_row|
                      @data = []
                      (0..3).each_with_index do |index, c_i|
                        rrr = rr + max_row -1
                        ccc = cc + c_i
                        value = sheet_data.cell(rrr,ccc)
                        if value.present?
                          if (c_i == 0)
                            key = value
                            @block_hash[key] = {}
                          elsif (c_i == 1)
                            @block_hash[key][21] = value
                          elsif (c_i == 2)
                            @block_hash[key][30] = value
                          elsif (c_i == 3)
                            @block_hash[key][45] = value
                          end
                          @data << value
                        end
                      end
                      if @data.compact.reject { |c| c.blank? }.length == 0
                        break # terminate the loop
                      end
                    end
                  end
                  if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                    @block_hash.shift
                  end
                @program.update(base_rate: @block_hash)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        #Adjustments
        (10..19).each do |r|
          row = sheet_data.row(r)
          @cltv_data = sheet_data.row(13)
          if row.compact.count >= 1
            (10..16).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "FLEX JUMBO 6400 SERIES ADJUSTMENTS"
                    @flex_hash["Jumbo/FICO/LTV"] = {}
                    @flex_hash["Jumbo/FICO/LTV"]["true"] = {}
                  end
                  if r >= 14 && r <= 19 && cc == 10
                    if value.include?("-")
                      secondary_key = value.tr('A-Z ','')
                    else
                      secondary_key = get_value value
                    end
                    @flex_hash["Jumbo/FICO/LTV"]["true"][secondary_key] = {}
                  end
                  if r >= 14 && r <= 19 && cc >= 12 && cc <= 16
                    cltv_key = get_value @cltv_data[cc-1]
                    @flex_hash["Jumbo/FICO/LTV"]["true"][secondary_key][cltv_key] = {}
                    @flex_hash["Jumbo/FICO/LTV"]["true"][secondary_key][cltv_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@flex_hash]
        make_adjust(adjustment,sheet)

        (21..38).each do |r|
          row = sheet_data.row(r)
          @cltv_data = sheet_data.row(13)
          if row.compact.count >= 1
            (10..16).each do |cc|
              value = sheet_data.cell(r,cc)
              begin
                if value.present?
                  if value == "FLEX JUMBO 6400 SERIES ADJUSTMENTS"
                    @jumbo_flex_hash["LoanSize/LoanAmount"] = {}
                    @jumbo_flex_hash["LoanSize/LoanAmount"]["Jumbo"] = {}
                    @jumbo_flex_hash["LoanSize/PropertyType"] = {}
                    @jumbo_flex_hash["LoanSize/PropertyType"]["Jumbo"] = {}
                  end
                  if r >= 23 && r <= 24 && cc == 10
                    if value.include?("-")
                      secondary_key = value.tr('A-Za-z$, ','')
                    else
                      secondary_key = get_value value
                    end
                    @jumbo_flex_hash["LoanSize/LoanAmount"]["Jumbo"][secondary_key] = {}
                  end
                  if r >= 23 && r <= 24 && cc == 16
                    @jumbo_flex_hash["LoanSize/LoanAmount"]["Jumbo"][secondary_key] = value
                  end
                  if r >= 25 && r <= 31 && cc == 10
                    if value.include?("(N/A for Investment Properties)")
                      secondary_key = value.split("s (N/A for Investment Properties)").first
                    else
                      secondary_key = value
                    end
                    @jumbo_flex_hash["LoanSize/PropertyType"]["Jumbo"][secondary_key] = {}
                  end
                  if r >= 25 && r <= 31 && cc == 16
                    @jumbo_flex_hash["LoanSize/PropertyType"]["Jumbo"][secondary_key] = value
                  end
                  if r == 32 && cc == 10
                    @jumbo_flex_hash["LoanSize/PropertyType"]["Jumbo"]["Fully Warrantable Condo NYC"] = {}
                  end
                  if r == 32 && cc == 16
                    @jumbo_flex_hash["LoanSize/PropertyType"]["Jumbo"]["Fully Warrantable Condo NYC"] = value
                  end
                  if r == 33 && cc == 10
                    @jumbo_flex_hash["LoanSize/PropertyType"]["Jumbo"]["Fully Warrantable Condo"] = {}
                  end
                  if r == 33 && cc == 16
                    @jumbo_flex_hash["LoanSize/PropertyType"]["Jumbo"]["Fully Warrantable Condo"] = value
                  end
                  if r == 34 && cc == 10
                    @jumbo_flex_hash["LoanSize/PropertyType"]["Jumbo"]["Non-Warrantable Condo"] = {}
                  end
                  if r == 34 && cc == 16
                    @jumbo_flex_hash["LoanSize/PropertyType"]["Jumbo"]["Non-Warrantable Condo"] = value
                  end
                  if r == 35 && cc == 10
                    @jumbo_flex_hash["LoanSize/PropertyType"]["Jumbo"]["Special Approval Condo"] = {}
                  end
                  if r == 35 && cc == 16
                    @jumbo_flex_hash["LoanSize/PropertyType"]["Jumbo"]["Special Approval Condo"] = value
                  end
                  if r == 36 && cc == 10
                    @jumbo_flex_hash["LoanSize/State"] = {}
                    @jumbo_flex_hash["LoanSize/State"]["Jumbo"] = {}
                    @jumbo_flex_hash["LoanSize/State"]["Jumbo"]["CA"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @jumbo_flex_hash["LoanSize/State"]["Jumbo"]["CA"] = new_val
                  end
                  if r == 37 && cc == 10
                    @jumbo_flex_hash["LoanSize/State"]["Jumbo"]["NY"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @jumbo_flex_hash["LoanSize/State"]["Jumbo"]["NY"] = new_val
                  end
                  if r == 38 && cc == 10
                    @jumbo_flex_hash["LoanSize/State"]["Jumbo"]["NJ"] = {}
                    @jumbo_flex_hash["LoanSize/State"]["Jumbo"]["FL"] = {}
                    @jumbo_flex_hash["LoanSize/State"]["Jumbo"]["CT"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @jumbo_flex_hash["LoanSize/State"]["Jumbo"]["NJ"] = new_val
                    @jumbo_flex_hash["LoanSize/State"]["Jumbo"]["FL"] = new_val
                    @jumbo_flex_hash["LoanSize/State"]["Jumbo"]["CT"] = new_val
                  end
                  if r == 41 && cc == 10
                    @jumbo_flex_hash["MiscAdjuster/State"] = {}
                    @jumbo_flex_hash["MiscAdjuster/State"]["Miscellaneous"] = {}
                    @jumbo_flex_hash["MiscAdjuster/State"]["Miscellaneous"]["NY"] = {}
                    cc = cc + 6
                    new_val = sheet_data.cell(r,cc)
                    @jumbo_flex_hash["MiscAdjuster/State"]["Miscellaneous"]["NY"] = new_val
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@jumbo_flex_hash]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    # redirect_to programs_import_file_path(@bank)
    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def jumbo_6800
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "JUMBO 6800")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        primary_key = ''
        first_key = ''
        cltv_key = ''
        c_val = ''
        @block_adjustment = {}
        @misc_adjustment = {}
        (10..37).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              @title = sheet_data.cell(r,cc)
              @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
              program_property sheet
              @programs_ids << @program.id
              # @program.adjustments.destroy_all
              @block_hash = {}
              key = ''
              (1..50).each do |max_row|
                @data = []
                (0..3).each_with_index do |index, c_i|
                  rrr = rr + max_row -1
                  ccc = cc + c_i
                  value = sheet_data.cell(rrr,ccc)
                  if value.present?
                    if (c_i == 0)
                      key = value
                      @block_hash[key] = {}
                    elsif (c_i == 1)
                      @block_hash[key][21] = value
                    elsif (c_i == 2)
                      @block_hash[key][30] = value
                    elsif (c_i == 3)
                      @block_hash[key][45] = value
                    end
                    @data << value
                  end
                end
                if @data.compact.reject { |c| c.blank? }.length == 0
                  break # terminate the loop
                end
              end
              if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                @block_hash.shift
              end
              @program.update(base_rate: @block_hash)
            end
          end
        end

        #Adjustment
        (40..50).each do |r|
          row = sheet_data.row(r)
          @key_data = sheet_data.row(42)
          if (row.compact.count >= 1)
            #Higher of LTV/CLTV Adjustment
            (0..11).each do |max_column|
              cc = max_column
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == "PRIME JUMBO 6800 SERIES ADJUSTMENTS"
                  @block_adjustment["LoanSize/FICO/LTV"] = {}
                  @block_adjustment["LoanSize/FICO/LTV"]["Jumbo"] = {}
                end

                if r >= 43 && r <= 47 && cc == 1
                  if value.include?("-")
                    cltv_key = value.tr('A-Z ','')
                  else
                    cltv_key = get_value value
                  end
                  @block_adjustment["LoanSize/FICO/LTV"]["Jumbo"][cltv_key] = {}
                end
                if r >= 43 && r <= 47 && cc >= 4 && cc <= 11
                  key_val = get_value @key_data[cc-1]
                  @block_adjustment["LoanSize/FICO/LTV"]["Jumbo"][cltv_key][key_val] = value
                end
                if r == 48 && cc == 1
                  @block_adjustment["RefinanceOption/LTV"] = {}
                  @block_adjustment["RefinanceOption/LTV"]["Cash Out"] = {}
                end
                if r == 48 &&  cc >= 4 && cc <= 11
                  key_val = get_value @key_data[cc-1]
                  @block_adjustment["RefinanceOption/LTV"]["Cash Out"][key_val] = value
                end
                if r == 49 && cc == 1
                  @block_adjustment["LoanPurpose/LTV"] = {}
                  @block_adjustment["LoanPurpose/LTV"]["Purchase"] = {}
                end
                if r == 49 &&  cc >= 4 && cc <= 11
                  key_val = get_value @key_data[cc-1]
                  @block_adjustment["LoanPurpose/LTV"]["Purchase"][key_val] = value
                end
                if r == 50 && cc == 1
                  @block_adjustment["PropertyType/LTV"] = {}
                  @block_adjustment["PropertyType/LTV"]["Investment Property"] = {}
                end
                if r == 50 &&  cc >= 4 && cc <= 11
                  key_val = get_value @key_data[cc-1]
                  @block_adjustment["PropertyType/LTV"]["Investment Property"][key_val] = value
                end
              end
            end

            #MISCELLANEOUS Adjustment
            (13..16).each do |max_column|
              cc = max_column
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == "MISCELLANEOUS"
                  @misc_adjustment["MiscAdjuster/State"] = {}
                  @misc_adjustment["MiscAdjuster/State"]["Miscellaneous"] = {}
                end

                if r >= 43 && r <= 44 && cc == 13
                  @misc_adjustment["MiscAdjuster/State"]["Miscellaneous"]["NY"] = {}
                  @misc_adjustment["MiscAdjuster/State"]["Miscellaneous"]["CA"] = {}
                  ccc = cc + 3
                  c_val = sheet_data.cell(r,ccc)
                  @misc_adjustment["MiscAdjuster/State"]["Miscellaneous"]["NY"] = c_val
                  @misc_adjustment["MiscAdjuster/State"]["Miscellaneous"]["CA"] = c_val
                end
              end
            end
          end
        end
        adjustment = [@misc_adjustment,@block_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end

    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def jumbo_6900_7900
    @programs_ids = []
    @xlsx.sheets.each do |sheet|
      if (sheet == "JUMBO 6900 & 7900")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @cltv_data = []
        @other_data = []
        @jumbo_data = []
        @jumbo_other_data = []
        @adjustment_hash = {}
        @other_adjustment = {}
        @jumbo_adjustment_hash = {}
        @jumbo_other_adjustment = {}
        primary_key = ''
        secondary_key = ''
        max_key = ''
        key = ''
        cltv_key = ''
        (10..23).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1

              @title = sheet_data.cell(r,cc)
              @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
              program_property sheet
              @programs_ids << @program.id
              if @title.present?
                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..3).each_with_index do |index, c_i|
                    rrr = rr + max_row -1
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      elsif (c_i == 1)
                        @block_hash[key][21] = value
                      elsif (c_i == 2)
                        @block_hash[key][30] = value
                      elsif (c_i == 3)
                        @block_hash[key][45] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
              end
              if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                @block_hash.shift
              end
              @program.update(base_rate: @block_hash)
            end
          end
        end
        (51..64).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count > 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1

              @title = sheet_data.cell(r,cc)
                @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                program_property sheet
                @programs_ids << @program.id
              if @title.present?
                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..50).each do |max_row|
                  @data = []
                  (0..3).each_with_index do |index, c_i|
                    rrr = rr + max_row -1
                    ccc = cc + c_i
                    value = sheet_data.cell(rrr,ccc)
                    if value.present?
                      if (c_i == 0)
                        key = value
                        @block_hash[key] = {}
                      elsif (c_i == 1)
                        @block_hash[key][21] = value
                      elsif (c_i == 2)
                        @block_hash[key][30] = value
                      elsif (c_i == 3)
                        @block_hash[key][45] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
              end
              if @block_hash.keys.first.nil?|| @block_hash.keys.first == "Rate"
                @block_hash.shift
              end
              @program.update(base_rate: @block_hash)
            end
          end
        end
        # Adjustment
        (26..44).each do |r|
          row = sheet_data.row(r)
          @cltv_data = sheet_data.row(28)
          if row.compact.count >= 1
            (1..11).each do |cc|
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == "RENEW JUMBO QM 6900 SERIES ADJUSTMENTS"
                  @adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"]["Jumbo"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"]["Jumbo"]["6900"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"]["Jumbo"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"]["Jumbo"]["6900"] = {}
                end

                # Purchase Transaction Adjustment
                if r >= 29 && r <= 36 && cc == 1
                  if value.include?("-")
                    secondary_key = value.tr('A-Z ','')
                  else
                    secondary_key = get_value value
                  end
                  @adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"]["Jumbo"]["6900"][secondary_key] = {}
                end
                if r >= 29 && r <= 36 && cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"]["Jumbo"]["6900"][secondary_key][cltv_key] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"]["Jumbo"]["6900"][secondary_key][cltv_key] = value
                end
                if r >= 37 && r <= 40 && cc == 1
                  if value.include?("-")
                    secondary_key = value.tr('A-Za-z$, ','')
                  else
                    secondary_key = get_value value
                  end
                  @adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"]["Jumbo"]["6900"][secondary_key] = {}
                end
                if r >= 37 && r <= 40 && cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"]["Jumbo"]["6900"][secondary_key][cltv_key] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"]["Jumbo"]["6900"][secondary_key][cltv_key] = value
                end
                if r == 41 && cc == 1
                  @adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"]["Jumbo"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"]["Jumbo"]["6900"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"]["Jumbo"]["6900"]["Purchase"] = {}
                end
                if r == 41 &&  cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"]["Jumbo"]["6900"]["Purchase"][cltv_key] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"]["Jumbo"]["6900"]["Purchase"][cltv_key] = value
                end
                if r == 42 && cc == 1
                  @adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"]["Jumbo"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"]["Jumbo"]["6900"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"]["Jumbo"]["6900"]["Cash Out"] = {}
                end
                if r == 42 &&  cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"]["Jumbo"]["6900"]["Cash Out"][cltv_key] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"]["Jumbo"]["6900"]["Cash Out"][cltv_key] = value
                end
                if r == 43 && cc == 1
                  @adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"]["Jumbo"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"]["Jumbo"]["6900"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"]["Jumbo"]["6900"]["Condo"] = {}
                end
                if r == 43 &&  cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"]["Jumbo"]["6900"]["Condo"][cltv_key] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"]["Jumbo"]["6900"]["Condo"][cltv_key] = value
                end
                if r == 44 && cc == 1
                  @adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"]["6900"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"]["6900"]["Escrow Waiver"] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"]["6900"]["Escrow Waiver"]["NY"] = {}
                end
                if r == 44 && cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"]["6900"]["Escrow Waiver"]["NY"][cltv_key] = {}
                  @adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"]["6900"]["Escrow Waiver"]["NY"][cltv_key] = value
                end
              end
            end
            #other adjustment
            (13..16).each do |cc|
              value = sheet_data.cell(r,cc)
              @other_data = sheet_data.row(r) if r == 32
              if value.present?
                if r == 33 && cc == 13
                  @other_adjustment["ProgramCategory/LoanAmount/Term"] = {}
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"] = {}
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["0-1000000"] = {}
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["0-1000000"]["30"] = {}
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["0-1000000"]["15"] = {}
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["0-1000000"]["ARM"] = {}
                end
                if r == 33 && cc == 14
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["0-1000000"]["30"] = value
                end
                if r == 33 && cc == 15
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["0-1000000"]["15"] = value
                end
                if r == 33 && cc == 16
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["0-1000000"]["ARM"] = value
                end
                if r == 34 && cc == 13
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["1000000-Inf"] = {}
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["1000000-Inf"]["30"] = {}
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["1000000-Inf"]["15"] = {}
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["1000000-Inf"]["ARM"] = {}
                end
                if r == 34 && cc == 14
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["1000000-Inf"]["30"] = value
                end
                if r == 34 && cc == 15
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["1000000-Inf"]["15"] = value
                end
                if r == 34 && cc == 16
                  @other_adjustment["ProgramCategory/LoanAmount/Term"]["6900"]["1000000-Inf"]["ARM"] = value
                end
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@other_adjustment]
        make_adjust(adjustment,sheet)

        #second adjustment
        (67..85).each do |r|
          row = sheet_data.row(r)
          @jumbo_data = sheet_data.row(69)
          if row.compact.count >= 1
            (1..11).each do |cc|
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == "RENEW JUMBO NON-QM 7900 SERIES ADJUSTMENTS"
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"]["Jumbo"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"]["Jumbo"]["7900"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"]["Jumbo"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"]["Jumbo"]["7900"] = {}
                end

                # Purchase Transaction Adjustment
                if r >= 70 && r <= 77 && cc == 1
                  if value.include?("-")
                    secondary_key = value.tr('A-Z ','')
                  else
                    secondary_key = get_value value
                  end
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"]["Jumbo"]["7900"][secondary_key] = {}
                end
                if r >= 70 && r <= 77 && cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"]["Jumbo"]["7900"][secondary_key][cltv_key] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/FICO/LTV"]["Jumbo"]["7900"][secondary_key][cltv_key] = value
                end
                if r >= 78 && r <= 81 && cc == 1
                  if value.include?("-")
                    secondary_key = value.tr('A-Za-z$, ','')
                  else
                    secondary_key = get_value value
                  end
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"]["Jumbo"]["7900"][secondary_key] = {}
                end
                if r >= 78 && r <= 81 && cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"]["Jumbo"]["7900"][secondary_key][cltv_key] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanAmount/LTV"]["Jumbo"]["7900"][secondary_key][cltv_key] = value
                end
                if r == 82 && cc == 1
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"]["Jumbo"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"]["Jumbo"]["7900"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"]["Jumbo"]["7900"]["Purchase"] = {}
                end
                if r == 82 &&  cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"]["Jumbo"]["7900"]["Purchase"][cltv_key] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/LoanPurpose/LTV"]["Jumbo"]["7900"]["Purchase"][cltv_key] = value
                end
                if r == 83 && cc == 1
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"]["Jumbo"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"]["Jumbo"]["6900"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"]["Jumbo"]["6900"]["Cash Out"] = {}
                end
                if r == 83 &&  cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"]["Jumbo"]["6900"]["Cash Out"][cltv_key] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/RefinanceOption/LTV"]["Jumbo"]["6900"]["Cash Out"][cltv_key] = value
                end
                if r == 84 && cc == 1
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"]["Jumbo"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"]["Jumbo"]["6900"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"]["Jumbo"]["6900"]["Condo"] = {}
                end
                if r == 84 &&  cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"]["Jumbo"]["6900"]["Condo"][cltv_key] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/PropertyType/LTV"]["Jumbo"]["6900"]["Condo"][cltv_key] = value
                end
                if r == 85 && cc == 1
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"]["7900"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"]["7900"]["Escrow Waiver"] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"]["7900"]["Escrow Waiver"]["NY"] = {}
                end
                if r == 85 && cc >= 5 && cc <= 11
                  cltv_key = get_value @cltv_data[cc-1]
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"]["7900"]["Escrow Waiver"]["NY"][cltv_key] = {}
                  @jumbo_adjustment_hash["LoanSize/ProgramCategory/MiscAdjuster/State/LTV"]["Jumbo"]["7900"]["Escrow Waiver"]["NY"][cltv_key] = value
                end
              end
            end

            #other adjustment
            (13..16).each do |cc|
              value = sheet_data.cell(r,cc)
              @jumbo_other_data = sheet_data.row(r) if r == 73
              if value.present?
                if r == 74 && cc == 13
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"] = {}
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"] = {}
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["0-1000000"] = {}
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["0-1000000"]["30"] = {}
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["0-1000000"]["15"] = {}
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["0-1000000"]["ARM"] = {}
                end
                if r == 74 && cc == 14
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["0-1000000"]["30"] = value
                end
                if r == 74 && cc == 15
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["0-1000000"]["15"] = value
                end
                if r == 74 && cc == 16
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["0-1000000"]["ARM"] = value
                end
                if r == 75 && cc == 13
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["1000000-Inf"] = {}
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["1000000-Inf"]["30"] = {}
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["1000000-Inf"]["15"] = {}
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["1000000-Inf"]["ARM"] = {}
                end
                if r == 75 && cc == 14
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["1000000-Inf"]["30"] = value
                end
                if r == 75 && cc == 15
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["1000000-Inf"]["15"] = value
                end
                if r == 75 && cc == 16
                  @jumbo_other_adjustment["ProgramCategory/LoanAmount/Term"]["7900"]["1000000-Inf"]["ARM"] = value
                end
              end
            end
          end
        end
        adjustment = [@jumbo_adjustment_hash,@jumbo_other_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    # redirect_to programs_import_file_path(@bank)
    redirect_to programs_ob_cmg_wholesale_path(@sheet_obj)
  end

  def get_value value1
    if value1.present?
      if value1.include?("<=") || value1.include?("<")
        value1 = "0-"+value1.split("<=").last.tr('A-Za-z%$><=, ','')
        value1 = value1.tr('–','-')
      elsif value1.include?(">")
        value1 = value1.split(">").last.tr('A-Za-z%$><=, ', '')+"-Inf"
        value1 = value1.tr('–','-')
      elsif value1.include?("+")
        value1.split("+")[0] + "-Inf"
        value1 = value1.tr('–','-')
      elsif value1.include?("%")
        value1.gsub("%", "")
        value1 = value1.tr('–','-')
      else
        value1 = value1.tr('A-Za-z&$, ','')
        value1 = value1.tr('–','-')
      end
    end
  end

  def programs
    @programs = @sheet_obj.programs
  end

  def single_program
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

  def read_sheet
  	file = File.join(Rails.root + "other_sheets", 'OB_CMG_Wholesale7575.xls')
    @xlsx = Roo::Spreadsheet.open(file)
  end

  def get_program
    @program = Program.find(params[:id])
  end

  def program_property sheet
    # term
    term = nil
    loan_size = nil
    loan_type = nil
    program_category = nil
    fha = false
    va = false
    usda = false
    streamline = false
    jumbo = false
    high_balance = false

    if (@program.program_name.split("Year").count > 1)
      term = @program.program_name.split("Year").first.tr('^0-9><%', '')
    elsif (@program.program_name.split("Yr").count > 1)
      term = @program.program_name.split("Yr").first.tr('^0-9><%', '')
    end
    # Arm Basic
    if @program.program_name.split("ARM").count > 1
      arm_basic = @program.program_name.split("ARM").first.split("/").first
    end
      # loan type
    if @program.program_name.downcase.include?("fixed") || sheet.downcase.include?("fixed")
      loan_type = "Fixed"
    elsif @program.program_name.downcase.include?("arm") || sheet.downcase.include?("arm") 
      loan_type = "ARM"
      arm_benchmark = "LIBOR"
      arm_margin = 0
    elsif @program.program_name.downcase.include?("floating") || sheet.downcase.include?("floating") 
      loan_type = "Floating"
    elsif @program.program_name.downcase.include?("variable") || sheet.downcase.include?("variable")
      loan_type = "Variable"
    else
      loan_type = "Fixed"
    end
    #Set Bank Name
    bank_name = @sheet_obj.bank.name

    # streamline
    if @program.program_name.downcase.include?("fha") || sheet.downcase.include?("fha")
      fha = true
    end
    if @program.program_name.downcase.include?("va") || sheet.downcase.include?("va")
      va = true
    end
    if @program.program_name.downcase.include?("usda") || sheet.downcase.include?("usda")
      usda = true
    end
    if @program.program_name.downcase.include?("streamline") || sheet.downcase.include?("streamline")
      streamline = true
    end
    # High-Balance
    high_balance = false
    jumbo = false
    if @program.program_name.downcase.include?("high bal") || @program.program_name.downcase.include?("high balance") || sheet.downcase.include?("high balance") || sheet.downcase.include?("high bal")
      high_balance = true
    end
     # Fannie mae Product
    if @program.program_name.downcase.include?("homeready") || sheet.downcase.include?("homeready")
      fannie_mae_product = "HomeReady"
    end
    # Freddie mac product
    if @program.program_name.downcase.include?("home possible") || sheet.downcase.include?("home possible")
      freddie_mac_product = "Home Possible"
    end
    # Program Property
    if @program.program_name.split("-").count > 1
      program_category = @program.program_name.split("-").last
      program_category = program_category.squish
    end
       # Loan Limit Type
    if @program.program_name.downcase.include?("non-conforming") || @program.program_name.downcase.include?("non conforming") || sheet.downcase.include?("non-conforming") || sheet.downcase.include?("non conforming")
      loan_size = "Non-Conforming"
    elsif @program.program_name.downcase.include?("conforming") || sheet.downcase.include?("conforming")
      loan_size = "Conforming"
    elsif @program.program_name.downcase.include?("jumbo") || sheet.downcase.include?("jumbo")
      loan_size = "Jumbo"
      jumbo = true
    elsif @program.program_name.downcase.include?("high-Balance") || @program.program_name.downcase.include?("high bal") || sheet.downcase.include?("high-Balance") || sheet.downcase.include?("high bal")
      loan_size = "High-Balance"
      high_balance = true
    else
      loan_size = "Conforming"
    end
    # loan_purpose
    if @program.program_name.downcase.include?('refinance') || @program.program_name.downcase.include?('refi') || sheet.downcase.include?('refinance') || sheet.downcase.include?('refi')
      loan_purpose = "Refinance"
    else
      loan_purpose = "Purchase"
    end
    # lp and du
    if @program.program_name.downcase.include?('du ') || sheet.downcase.include?('du ')
      du = true
    end
    if @program.program_name.downcase.include?('lp ') || sheet.downcase.include?('lp ')
      lp = true
    end
    @program.update(term: term,loan_type: loan_type,program_category: program_category, streamline: streamline,fha: fha, va: va, usda: usda, arm_basic: arm_basic, loan_category: sheet, fannie_mae_product: fannie_mae_product,freddie_mac_product: freddie_mac_product, loan_size: loan_size, bank_name: bank_name,loan_purpose: loan_purpose, du: du, lp: lp, arm_benchmark: arm_benchmark, arm_margin: arm_margin)
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
end
# Program.all.collect{|p| hash[p.program_name] = p.term, p.loan_type, p.program_category, p.streamline, p.fha, p.va, p.usda, p.arm_basic, p.sheet, p.fannie_mae_product, p.freddie_mac_product, p.loan_size, p.bank_name, p.loan_purpose, p.du, p.lp}
