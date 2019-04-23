class RateSheetExtractor::ObUnitedWholesaleMortgage4892Controller < RateSheetExtractor::ApplicationController
  before_action :read_sheet, only: [:conv, :govt, :govt_arms, :non_conf, :harp]
  before_action :get_sheet, only: [:programs, :conv, :govt, :govt_arms, :non_conf, :harp]
  before_action :get_program, only: [:single_program, :program_property]

  def index
    file = File.join(Rails.root,'OB_United_Wholesale_Mortgage4892.xls')
    xlsx = Roo::Spreadsheet.open(file)
    begin
      xlsx.sheets.each do |sheet|
        if (sheet == "Conv")
          # headers = ["Phone", "General Contacts", "Mortgagee Clause (Wholesale)"]
          @name = "UWM United Wholesale Mortgage"
          @bank = Bank.find_or_create_by(name: @name)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
      end
    rescue
      # the required headers are not all present
    end
  end

  def conv
    @xlsx.sheets.each do |sheet|
      if (sheet == "Conv")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        start_range = 13
        end_range = 103
        row_count = 15
        column_count = 3
        num1 = 2
        num2 = 4
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, sheet
      end
      # adjustments
      if (sheet == "Conv Adjustments")
        @sheet_name = "Conv"
        sheet_data = @xlsx.sheet(sheet)
        @adjustment_hash = {}
        @cash_out = {}
        @other_adjustment = {}
        @loan_amount = {}
        secondary_key = ''
        ltv_key = ''
        (8..56).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(8)
          if row.compact.count > 1
            (0..17).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Credit Score / LTV"
                    @adjustment_hash["Term/FICO/LTV"] = {}
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"] = {}
                  end
                  if value == "Cash Out       All Loan Terms     "
                    @cash_out["RefinanceOption/FICO/LTV"] = {}
                    @cash_out["RefinanceOption/FICO/LTV"]["Cash Out"] = {}
                  end

                  # Credit Score
                  if r >= 9 && r <= 14 && cc == 1
                    secondary_key = get_value value
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"][secondary_key] = {}
                  end
                  if r >= 9 && r <= 14 && cc >= 9 && cc <= 17
                    ltv_key = get_value @ltv_data[cc-1]
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = {}
                    @adjustment_hash["Term/FICO/LTV"]["15-Inf"][secondary_key][ltv_key] = value
                  end
                  # Cash Out
                  if r >= 16 && r <= 21 && cc == 1
                    secondary_key = get_value value
                    @cash_out["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key] = {}
                  end
                  if r >= 16 && r <= 21 && cc >= 9 && cc <= 17
                    ltv_key = get_value @ltv_data[cc-1]
                    @cash_out["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][ltv_key] = {}
                    @cash_out["RefinanceOption/FICO/LTV"]["Cash Out"][secondary_key][ltv_key] = value
                  end
                  # @adj_hash
                  if r == 23 && cc == 1
                    @adjustment_hash["LoanPurpose/LoanSize/RefinanceOption"] = {}
                    @adjustment_hash["LoanPurpose/LoanSize/RefinanceOption"]["Purchase"] = {}
                    @adjustment_hash["LoanPurpose/LoanSize/RefinanceOption"]["Purchase"]["High Balance"] = {}
                    @adjustment_hash["LoanPurpose/LoanSize/RefinanceOption"]["Purchase"]["High Balance"]["Rate and Term"] = {}
                  end
                  if r == 23 && cc >= 9 && cc <= 17
                    ltv_key = get_value @ltv_data[cc-1]
                    @adjustment_hash["LoanPurpose/LoanSize/RefinanceOption"]["Purchase"]["High Balance"]["Rate and Term"][ltv_key] = {}
                    @adjustment_hash["LoanPurpose/LoanSize/RefinanceOption"]["Purchase"]["High Balance"]["Rate and Term"][ltv_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@cash_out]
        make_adjust(adjustment,@sheet_name)
        create_program_association_with_adjustment(@sheet_name)
      end
    end
    redirect_to programs_ob_united_wholesale_mortgage4892_path(@sheet_obj)
  end

  def govt
    @xlsx.sheets.each do |sheet|
      if (sheet == "Govt")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @fico_adj = {}
        primary_key = ''
        secondary_key = ''
        start_range = 9
        end_range = 93
        row_count = 15
        column_count = 3
        num1 = 1
        num2 = 4
        # Programs
        (78..93).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 3))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present? && @title != "GOVERNMENT PRICE ADJUSTMENTS"
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id

                  @block_hash = {}
                  key = ''
                  (1..14).each do |max_row|
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
                          @block_hash[key][15*c_i] = value
                        end
                        @data << value
                      end
                    end
                    if @data.compact.reject { |c| c.blank? }.length == 0
                      break # terminate the loop
                    end
                  end
                  @program.update(base_rate: @block_hash,loan_category: sheet)
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, sheet
        # Adjustments
        (78..93).each do |r|
          row = sheet_data.row(r)
          if row.compact.count >= 1
            (9..16).each do |cc|
              value = sheet_data.cell(r,cc)
              if value.present?
                if value == "GOVERNMENT PRICE ADJUSTMENTS"
                  @adjustment_hash["LoanAmount"] = {}
                end
                if value == "Credit Score Adjustors:  (lowest middle score)"
                  primary_key = "FICO"
                  @fico_adj[primary_key] = {}
                end
                # Loan Size Adjustors
                if r >= 80 && r <= 82 && cc == 9
                  secondary_key = value.tr('A-Za-z<:$, ','')
                  @adjustment_hash["LoanAmount"][secondary_key] = {}
                end
                if r >= 80 && r <= 82 && cc == 16
                  @adjustment_hash["LoanAmount"][secondary_key] = value
                end
                # Credit Score Adjustors
                if r >= 84 && r <= 85 && cc == 9
                  secondary_key = value.gsub(/\s+/, '')
                  @fico_adj[primary_key][secondary_key] = {}
                end
                if r >= 84 && r <= 85 && cc == 16
                  @fico_adj[primary_key][secondary_key] = value
                end
                # if r == 86 && cc == 9
                #   primary_key = "0<$125,000"
                #   @fico_adj[primary_key] = {}
                # end
                # if r == 86 && cc == 16
                #   @fico_adj[primary_key] = value
                # end
                # if r == 87 && cc == 9
                #   primary_key = "LoanPurpose/LockDay"
                #   @fico_adj[primary_key] = {}
                # end
                # if r == 87 && cc == 16
                #   @fico_adj[primary_key] = value
                # end
                # if r == 89 && cc == 9
                #   primary_key = "LoanType/Term"
                #   @fico_adj[primary_key] = {}
                #   if @fico_adj[primary_key] = {}
                #     cc = cc + 7
                #     new_value = sheet_data.cell(r,cc)
                #     @fico_adj[primary_key] = new_value
                #   end
                # end
                # if r == 90 && cc == 9
                #   primary_key = "Term"
                #   @fico_adj[primary_key] = {}
                #   if @fico_adj[primary_key] = {}
                #     cc = cc + 7
                #     new_value = sheet_data.cell(r,cc)
                #     @fico_adj[primary_key] = new_value
                #   end
                # end
                # if r == 91 && cc == 9
                #   primary_key = "Streamline"
                #   @fico_adj[primary_key] = {}
                #   if @fico_adj[primary_key] = {}
                #     cc = cc + 7
                #     new_value = sheet_data.cell(r,cc)
                #     @fico_adj[primary_key] = new_value
                #   end
                # end
                # if r == 92 && cc == 9
                #   primary_key = "LoanType/RefinanceOption/VA"
                #   secondary_key = "115.01-125%"
                #   @fico_adj[primary_key] = {}
                #   @fico_adj[primary_key][secondary_key] = {}
                #   if @fico_adj[primary_key][secondary_key] = {}
                #     cc = cc + 7
                #     new_value = sheet_data.cell(r,cc)
                #     @fico_adj[primary_key][secondary_key] = new_value
                #   end
                # end
                # if r == 93 && cc == 9
                #   secondary_key = "125.01-150%"
                #   @fico_adj[primary_key][secondary_key] = {}
                #   if @fico_adj[primary_key][secondary_key] = {}
                #     cc = cc + 7
                #     new_value = sheet_data.cell(r,cc)
                #     @fico_adj[primary_key][secondary_key] = new_value
                #   end
                # end
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@fico_adj]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_united_wholesale_mortgage4892_path(@sheet_obj)
  end

  def govt_arms
    @xlsx.sheets.each do |sheet|
      if (sheet == "Govt ARMS")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @loan_amount = {}
        primary_key = ''
        secondary_key = ''
        #program
        (9..14).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1 # 3 / 7 / 11
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                end
                @block_hash = {}
                key = ''
                (1..4).each do |max_row|
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
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        (15..28).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1 # 3 / 7 / 11
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                end
                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..11).each do |max_row|
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
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        (30..35).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1 # 3 / 7 / 11
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                end
                @block_hash = {}
                key = ''
                (1..4).each do |max_row|
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
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        (36..49).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 1 # 3 / 7 / 11
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                end
                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..11).each do |max_row|
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
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # adjustments
        (51..66).each do |r|
          row = sheet_data.row(r)
          if row.compact.count >= 1
            (0..13).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "GOVERNMENT PRICE ADJUSTMENTS"
                    primary_key = "LoanAmount"
                    @adjustment_hash[primary_key] = {}
                  end
                  if value == "Credit Score Adjustors:  (lowest middle score)"
                    primary_key = "FICO"
                    @loan_amount[primary_key] = {}
                  end
                  # Loan Size Adjustors
                  if r >= 53 && r <= 55 && cc == 4
                    secondary_key = get_value value
                    @adjustment_hash[primary_key][secondary_key] = {}
                  end
                  if r >= 53 && r <= 55 && cc == 13
                    @adjustment_hash[primary_key][secondary_key] = value
                  end
                  # Credit Score Adjustors
                  if r >= 57 && r <= 58 && cc == 4
                    secondary_key = get_value value
                    @loan_amount[primary_key][secondary_key] = {}
                  end
                  if r >= 57 && r <= 58 && cc == 13
                    @loan_amount[primary_key][secondary_key] = value
                  end
                  # if r == 59 && cc == 4
                  #   primary_key = "0<$125,000"
                  #   @loan_amount[primary_key] = {}
                  # end
                  # if r == 59 && cc == 13
                  #   @loan_amount[primary_key] = value
                  # end
                  if r == 60 && cc == 4
                    @loan_amount["LoanPurpose/LockDay"] = {}
                    @loan_amount["LoanPurpose/LockDay"]["Purchase"] = {}
                    @loan_amount["LoanPurpose/LockDay"]["Purchase"]["45"] = {}
                    cc = cc + 9
                    new_val = sheet_data.cell(r,cc)
                    @loan_amount["LoanPurpose/LockDay"]["Purchase"]["45"] = new_val
                  end
                  # if r == 60 && cc == 13
                  #   @loan_amount[primary_key] = value
                  # end
                  # if r == 62 && cc == 4
                  #   primary_key = "LoanType/Term"
                  #   @loan_amount[primary_key] = {}
                  #   if @loan_amount[primary_key] = {}
                  #     cc = cc + 9
                  #     new_value = sheet_data.cell(r,cc)
                  #     @loan_amount[primary_key] = new_value
                  #   end
                  # end
                  # if r == 63 && cc == 4
                  #   primary_key = "Term"
                  #   @loan_amount[primary_key] = {}
                  #   if @loan_amount[primary_key] = {}
                  #     cc = cc + 9
                  #     new_value = sheet_data.cell(r,cc)
                  #     @loan_amount[primary_key] = new_value
                  #   end
                  # end
                  # if r == 64 && cc == 4
                  #   primary_key = "Streamline"
                  #   @loan_amount[primary_key] = {}
                  #   if @loan_amount[primary_key] = {}
                  #     cc = cc + 9
                  #     new_value = sheet_data.cell(r,cc)
                  #     @loan_amount[primary_key] = new_value
                  #   end
                  # end
                  # if r == 65 && cc == 4
                  #   primary_key = "VA/LoanType/RefinanceOption"
                  #   secondary_key = "115.01-125%"
                  #   @loan_amount[primary_key] = {}
                  #   @loan_amount[primary_key][secondary_key] = {}
                  #   if @loan_amount[primary_key][secondary_key] = {}
                  #     cc = cc + 9
                  #     new_value = sheet_data.cell(r,cc)
                  #     @loan_amount[primary_key][secondary_key] = new_value
                  #   end
                  # end
                  # if r == 66 && cc == 4
                  #   secondary_key = "125.01-150%"
                  #   @loan_amount[primary_key][secondary_key] = {}
                  #   if @loan_amount[primary_key][secondary_key] = {}
                  #     cc = cc + 9
                  #     new_value = sheet_data.cell(r,cc)
                  #     @loan_amount[primary_key][secondary_key] = new_value
                  #   end
                  # end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@loan_amount]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_united_wholesale_mortgage4892_path(@sheet_obj)
  end

  def non_conf
    @xlsx.sheets.each do |sheet|
      if (sheet == "Non-Conf")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @loan_amount = {}
        @other_adjustment = {}
        primary_key = ''
        secondary_key = ''
        ltv_key = ''
        #program
        (12..38).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 3)) && (!row.compact.include?("ELITE PROGRAM IS DESIGNED FOR BORROWERS WITH 700+ CREDIT SCORES"))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 3 # 3 / 7 / 11
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                end
                @block_hash = {}
                key = ''
                (1..11).each do |max_row|
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
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        (41..53).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 2))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 5 # 3 / 7 / 11
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                end

                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..11).each do |max_row|
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
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        (54..66).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 3)) && (!row.compact.include?("ELITE PROGRAM IS DESIGNED FOR BORROWERS WITH 700+ CREDIT SCORES"))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              cc = 4*max_column + 3 # 3 / 7 / 11
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                end

                # @program.adjustments.destroy_all
                @block_hash = {}
                key = ''
                (1..11).each do |max_row|
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
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end

        # adjustments
        (69..93).each do |r|
          row = sheet_data.row(r)
          @ltv_data = sheet_data.row(69)
          if row.compact.count > 1
            (0..14).each do |cc|
              begin
                value = sheet_data.cell(r,cc)
                if value.present?
                  if value == "Credit Score"
                    primary_key = "FICO/CLTV"
                    @adjustment_hash[primary_key] = {}
                  end
                  if value == "Loan Amount:"
                    primary_key = "LoanAmount/CLTV"
                    @loan_amount[primary_key] = {}
                  end
                  if value == "Cash Out"
                    @other_adjustment["RefinanceOption/LTV"] = {}
                    @other_adjustment["RefinanceOption/LTV"]["Cash Out"] = {}
                    @other_adjustment["PropertyType/LTV"] = {}
                  end
                  if value == "Purchase"
                    @other_adjustment["LoanPurpose/LTV"] = {}
                    @other_adjustment["LoanPurpose/LTV"]["Purchase"] = {}
                  end
                  if value == "Escrow Waiver (LTVs >80%; CA only)"
                    primary_key = value
                    @other_adjustment["MiscAdjuster/State/LTV/CLTV"] = {}
                    @other_adjustment["MiscAdjuster/State/LTV/CLTV"][primary_key] = {}
                    @other_adjustment["MiscAdjuster/State/LTV/CLTV"][primary_key]["CA"] = {}
                    @other_adjustment["MiscAdjuster/State/LTV/CLTV"][primary_key]["CA"]["80-Inf"] = {}
                  end
                  # Credit Score
                  if r >= 70 && r <= 75 && cc == 5
                    secondary_key = get_value value
                    @adjustment_hash[primary_key][secondary_key] = {}
                  end
                  if r >= 70 && r <= 75 && cc >= 8 && cc <= 14
                    ltv_key = get_value @ltv_data[cc-1]
                    @adjustment_hash[primary_key][secondary_key][ltv_key] = {}
                    @adjustment_hash[primary_key][secondary_key][ltv_key] = value
                  end
                  # Loan Amount:
                  if r >= 76 && r <= 82 && cc == 5
                    secondary_key = get_value value
                    @loan_amount[primary_key][secondary_key] = {}
                  end
                  if r >= 76 && r <= 82 && cc >= 8 && cc <= 14
                    ltv_key = get_value @ltv_data[cc-1]
                    @loan_amount[primary_key][secondary_key][ltv_key] = {}
                    @loan_amount[primary_key][secondary_key][ltv_key] = value
                  end
                  # Other Adjustment
                  if r == 83 && cc >= 8 && cc <= 14
                    ltv_key = get_value @ltv_data[cc-1]
                    @other_adjustment["RefinanceOption/LTV"]["Cash Out"][ltv_key] = {}
                    @other_adjustment["RefinanceOption/LTV"]["Cash Out"][ltv_key] = value
                  end
                  if r >= 84 && r <= 88 && cc == 3
                    if value.include?("Units")
                      primary_key = value.tr('s','')
                    elsif value.include?("Investment")
                      primary_key = "Investment Property"
                    else
                      primary_key = value
                    end
                    @other_adjustment["PropertyType/LTV"][primary_key] = {}
                  end
                  if r >= 84 && r <= 88 && cc >= 8 && cc <= 14
                    ltv_key = get_value @ltv_data[cc-1]
                    @other_adjustment["PropertyType/LTV"][primary_key][ltv_key] = {}
                    @other_adjustment["PropertyType/LTV"][primary_key][ltv_key] = value
                  end
                  if r == 89 && cc >= 8 && cc <= 14
                    ltv_key = get_value @ltv_data[cc-1]
                    @other_adjustment["LoanPurpose/LTV"]["Purchase"][ltv_key] = {}
                    @other_adjustment["LoanPurpose/LTV"]["Purchase"][ltv_key] = value
                  end
                  if r == 90 && cc >= 8 && cc <= 14
                    ltv_key = get_value @ltv_data[cc-1]
                    @other_adjustment["MiscAdjuster/State/LTV/CLTV"][primary_key]["CA"]["80-Inf"][ltv_key] = {}
                    @other_adjustment["MiscAdjuster/State/LTV/CLTV"][primary_key]["CA"]["80-Inf"][ltv_key] = value
                  end
                  if r == 91 && cc == 3
                    @other_adjustment["ArmBasic/LTV"] = {}
                    @other_adjustment["ArmBasic/LTV"]["5/1"] = {}
                    @other_adjustment["ArmBasic/LTV"]["7/1"] = {}
                    @other_adjustment["ArmBasic/LTV"]["10/1"] = {}
                  end
                  if r == 91 && cc >= 8 && cc <= 14
                    ltv_key = get_value @ltv_data[cc-1]
                    @other_adjustment["ArmBasic/LTV"]["5/1"][ltv_key] = {}
                    @other_adjustment["ArmBasic/LTV"]["7/1"][ltv_key] = {}
                    @other_adjustment["ArmBasic/LTV"]["10/1"][ltv_key] = {}
                    @other_adjustment["ArmBasic/LTV"]["5/1"][ltv_key] = value
                    @other_adjustment["ArmBasic/LTV"]["7/1"][ltv_key] = value
                    @other_adjustment["ArmBasic/LTV"]["10/1"][ltv_key] = value
                  end
                end
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
        adjustment = [@adjustment_hash,@loan_amount,@other_adjustment]
        make_adjust(adjustment,sheet)
        create_program_association_with_adjustment(sheet)
      end
    end
    redirect_to programs_ob_united_wholesale_mortgage4892_path(@sheet_obj)
  end

  def harp
    @xlsx.sheets.each do |sheet|
      if (sheet == "HARP")
        sheet_data = @xlsx.sheet(sheet)
        @programs_ids = []
        @adjustment_hash = {}
        @loan_amount = {}
        @other_adjustment = {}
        primary_key = ''
        secondary_key = ''
        ltv_key = ''
        #program
        (12..67).each do |r|
          row = sheet_data.row(r)
          if ((row.compact.count >= 1) && (row.compact.count <= 4))
            rr = r + 1
            max_column_section = row.compact.count - 1
            (0..max_column_section).each do |max_column|
              if max_column == 2
                cc = 11
              elsif max_column == 3
                cc = 15
              else
                cc = 4*max_column + 1
              end
              begin
                @title = sheet_data.cell(r,cc)
                if @title.present?
                  @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
                  p_name = @title + " " + sheet
                  @program.update_fields p_name
                  program_property @title
                  @programs_ids << @program.id
                end
                @block_hash = {}
                key = ''
                (1..12).each do |max_row|
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
                        @block_hash[key][15*c_i] = value
                      end
                      @data << value
                    end
                  end
                  if @data.compact.reject { |c| c.blank? }.length == 0
                    break # terminate the loop
                  end
                end
                @program.update(base_rate: @block_hash,loan_category: sheet)
              rescue Exception => e
                error_log = ErrorLog.new(details: e.backtrace_locations[0], row: r, column: cc, loan_category: sheet, error_detail: e.message)
                error_log.save
              end
            end
          end
        end
      end
    end
    redirect_to programs_ob_united_wholesale_mortgage4892_path(@sheet_obj)
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

  def get_value value1
    if value1.present?
      if value1.include?("<=") || value1.include?("<")
        value1 = "0-"+value1.split("<=").last.tr('A-Za-z%$><=,: ','')
        value1 = value1.tr('–','-')
      elsif value1.include?(">") || value1.include?("+")
        value1 = value1.split(">").last.tr('^0-9, ', '')+"-Inf"
        value1 = value1.tr('–','-')
      else
        value1.tr('A-Za-z:$, ','')
        value1 = value1.tr('–','-')
      end
    end
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

  def read_sheet
  	file = File.join(Rails.root + "other_sheets", 'OB_United_Wholesale_Mortgage4892.xls')
    @xlsx = Roo::Spreadsheet.open(file)
  end

  def program_property title
    if (title.downcase.include?("year") || title.downcase.include?("yr") || title.downcase.include?("y")) && title.downcase.exclude?('arm')
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
    # Arm Advanced
    @arm_advanced = nil
    if title.downcase.include?("arm")
        title.split.each do |arm|
          if arm.tr('1-9A-Za-z(|.% ','') == "//"
            @arm_advanced = arm.tr('A-Za-z()|.% , ','')[0,5]
          elsif arm.split('/').last == "5"
            arm_advanced = arm.tr('A-Za-z()|.% , ','')[0,3]
            @arm_advanced = arm_advanced.tr('/','-')
          elsif arm == "2-2-5"
              @arm_advanced = "2-2-5"
          end
        end
      end
    @program.update(term: term,arm_basic: arm_basic, arm_advanced: @arm_advanced)
  #   if @program.program_name.include?("30") || @program.program_name.include?("30/25 Year")
  #     term = 30
  #   elsif @program.program_name.include?("20")
  #     term = 20
  #   elsif @program.program_name.include?("15")
  #     term = 15
  #   elsif @program.program_name.include?("10 Year")
  #     term = 10
  #   else
  #     term = nil
  #   end

  #   # Loan-Type
  #   if @program.program_name.include?("Fixed") || @program.program_name.include?("FIXED")
  #     loan_type = "Fixed"
  #   elsif @program.program_name.include?("ARM")
  #     loan_type = "ARM"
  #   elsif @program.program_name.include?("Floating")
  #     loan_type = "Floating"
  #   elsif @program.program_name.include?("Variable")
  #     loan_type = "Variable"
  #   else
  #     loan_type = nil
  #   end

  #   # Streamline Vha, Fha, Usda
  #   fha = false
  #   va = false
  #   usda = false
  #   streamline = false
  #   full_doc = false
  #   if @program.program_name.include?("FHA")
  #     streamline = true
  #     fha = true
  #     full_doc = true
  #   elsif @program.program_name.include?("VA")
  #     streamline = true
  #     va = true
  #     full_doc = true
  #   elsif @program.program_name.include?("USDA")
  #     streamline = true
  #     usda = true
  #     full_doc = true
  #   end

  #   # High Balance
  #   jumbo_high_balance = false
  #   if @program.program_name.include?("High Bal") || @program.program_name.include?("High Balance")
  #     jumbo_high_balance = true
  #   end

  #   # Arm Advanced
  #   if @program.program_name.include?("2-2-5 ")
  #     arm_advanced = "2-2-5"
  #   end
  #   # Loan Limit Type
  #   if @program.program_name.include?("Non-Conforming")
  #     @program.loan_limit_type << "Non-Conforming"
  #   end
  #   if @program.program_name.include?("Conforming")
  #     @program.loan_limit_type << "Conforming"
  #   end
  #   if @program.program_name.include?("Jumbo")
  #     @program.loan_limit_type << "Jumbo"
  #   end
  #   if @program.program_name.include?("High Balance")
  #     @program.loan_limit_type << "High Balance"
  #   end
  #   @program.save
  #   @program.update(term: term, loan_type: loan_type, fha: fha, va: va, usda: usda, full_doc: full_doc, streamline: streamline, jumbo_high_balance: jumbo_high_balance, arm_basic: arm_basic, arm_advanced: arm_advanced)
  end

  # create programs
  def make_program start_range, end_range, sheet_data, row_count, column_count, num1, num2, sheet
    (start_range..end_range).each do |r|
      row = sheet_data.row(r)
      if ((row.compact.count > 1) && (row.compact.count <= 4)) && (!row.compact.include?("GOVERNMENT PRICE ADJUSTMENTS"))
        rr = r + 1
        max_column_section = row.compact.count - 1
        (0..max_column_section).each do |max_column|
          cc = num1 + max_column*num2
          begin
            @title = sheet_data.cell(r,cc)
            if @title.present?
              @program = @sheet_obj.programs.find_or_create_by(program_name: @title)
              p_name = @title + " " + sheet
                  @program.update_fields p_name
              program_property @title
              @programs_ids << @program.id
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
                      @block_hash[key][15*c_i] = value
                    end
                    @data << value
                  end
                end
                if @data.compact.reject { |c| c.blank? }.length == 0
                  break # terminate the loop
                end
              end
              sheet = @program.sheet.name
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
