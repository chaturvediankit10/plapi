class SearchApi::DashboardController < ApplicationController
  layout "application"

  def index
    api_search
  end

  def set_default
    if request.base_url=="https://rate-sheet-extractor.herokuapp.com"
      @source = 1
    else
      @source = 0
    end
    @base_rate = 0.0
    @filter_data = {}
    @others_programs = []
    @interest = "4.000"
    @term = "30"
    @ltv = []
    @cltv = []
    @credit_score = []
    @flag_loan_type = false
    @lock_period ="30"
    @loan_size = "Conforming"
    @loan_type = "Fixed"
    @fannie_mae_product = "HomeReady"
    @freddie_mac_product = "Home Possible"
    @arm_basic = "5"
    @arm_advanced = "1-1-5"
    @arm_caps = "5-5"
    @program_category = "6900"
    @property_type = "1 Unit"
    @financing_type = "Subordinate Financing"
    @premium_type ="1 Unit"
    @refinance_option = "Cash Out"
    @misc_adjuster = "CA Escrow Waiver (Full or Taxes Only)"
    @state_code = "All"
    @result = []
    @loan_amount = "250000 - 299999"
    @set_ltv = params[:ltv].present? ? params[:ltv] : "65.00 - 69.99"
    @set_credit_score = params[:credit_score].present? ? params[:credit_score] : "700-719"
    @dti = "25.6%"
    @loan_purpose = "Purchase"
    @home_price = "300000"
    @down_payment = "50000"
    @coverage = "30.5%"
    @margin = "2.0"
    @ltv = (6500..6999).to_a.map{|e| e.to_f/100}
    @cltv = (7500..7999).to_a.map{|e| e.to_f/100}
    @credit_score = (700..719).to_a
    @programs_all = load_programs_all
    @default_property_tax_perc = 0.86
    @default_annual_home_insurance = 974
    @default_pmi_insurance = 100.00
    @point_mode = "Regular"
  end

  def api_search
    set_default
    @time = Benchmark.measure {
      if params["commit"].present?
        set_variable
      end
      search_programs
    }
    puts "Query Time: #{@time.real}"
  end

  private

  def add_default_loan_cat
    if @program_categories.present?
      @program_categories.prepend(["All"])
    else
      @program_categories << "No Category"
    end
  end

  def load_programs_all( filtered = 1 )
    if params[:state_code].present? && params[:state_code] != "All"
      banks = Bank.where("state@> ARRAY[?]::varchar[]", params[:state_code])
      programs = Program.where(bank_name: banks.map(&:name))
    else
      programs = Program.all
    end

    if filtered < 1
      @program_all = programs
      return;
    end

    loan_purpose = params[:loan_purpose].present? ? params[:loan_purpose] : @loan_purpose
    loan_type = params[:loan_type].present? ? params[:loan_type] : @loan_type
    arm_basic = params[:arm_basic].present? ? params[:arm_basic] : @arm_basic
    term = params[:term].present? ? params[:term] : @term

    if loan_purpose == "Purchase"
      if loan_type == "ARM"
        if arm_basic != "All"
          arm_basic = split_arm_basic(arm_basic)
          @programs_all = programs.where(loan_purpose: loan_purpose, loan_type: loan_type, arm_basic: arm_basic)
        else
          @programs_all = programs.where(loan_purpose: loan_purpose, loan_type: loan_type)
        end
      else
        if term == "All"
            @programs_all = programs.where(loan_purpose: loan_purpose, loan_type: loan_type)
        else
            term_range = programs.pluck(:term).select{|a| (a.present? && a.to_s.length > 2 && a/100 <= term.to_i && term.to_i <= a%100) }.uniq
            @programs_all = programs.where("loan_purpose = ? AND loan_type = ? AND term = ? OR term IN (?)", loan_purpose, loan_type, term.to_i, term_range)
        end
      end
    else # This is only addhoc fix. It mistakenly includes Purchase only type for refinance. Will need sheet extraction fixes later. 
      if loan_type == "ARM"
        if arm_basic != "All"
          arm_basic = split_arm_basic(arm_basic)
          @programs_all = programs.where(loan_type: loan_type, arm_basic: arm_basic)
        else
          @programs_all = programs.where(loan_type: loan_type)
        end
      else
        if term == "All"
            @programs_all = programs.where(loan_type: loan_type)
        else
            term_range = programs.pluck(:term).select{|a| (a.present? && a.to_s.length > 2 && a/100 <= term.to_i && term.to_i <= a%100) }.uniq
            @programs_all = programs.where("loan_purpose = ? AND loan_type = ? AND term = ? OR term IN (?)", loan_purpose, loan_type, term.to_i, term_range)
        end
      end
    end
  end

  def split_arm_basic(arm)
    arm.split("/").first
  end

  def modify_ltv_cltv_credit_score
    %w[ltv cltv credit_score].each do |key|
      array_data = []
      if key == "ltv" || key == "cltv"
        key_value = params[key.to_sym]
        if key_value.present?
          if key_value.include?("-")
            key_range = (key_value.split("-").first.to_f..key_value.split("-").last.to_f)
            key_range.step(0.01) { |f| array_data << f.round(2) }
            instance_variable_set("@#{key}", array_data.try(:uniq))
          else
            instance_variable_set("@#{key}", key_value)
          end
        end
      end
      if key == "credit_score"
        key_value = params[key.to_sym]
        if key_value.present?
          if key_value.include?("-")
            array_data = (key_value.split("-").first.to_i..key_value.split("-").last.to_i).to_a
            instance_variable_set("@#{key}", array_data.try(:uniq))
          else
            instance_variable_set("@#{key}", key_value)
          end
        end
      end
    end
  end

  def modify_condition
    %w[bank_name program_name pro_category loan_category term loan_size].each do |key|
      key_value = params[key.to_sym]
      if key_value.present?
        unless (key_value == "All")
          if (key == "pro_category")
            unless (key_value == "No Category")
              @filter_data[:program_category] = key_value
            end
          else
            if (key == "program_name")
              @filter_data[key.to_sym] = key_value.remove("\r")
            elsif key == "term"
              @filter_data[key.to_sym] = key_value.to_i
            else
              @filter_data[key.to_sym] = key_value
            end
          end
          if %w[pro_category loan_category loan_purpose loan_type term].include?(key)
            instance_variable_set("@#{key}", key_value)
          end
        end
      end
    end
  end

  def modify_true_condition
    %w[full_doc].each do |key|
      key_value = params[key.to_sym]
      if key_value.present?
        @filter_data[key.to_sym] = true
      end
    end
  end

  def modify_variables
    %w[state_code property_type financing_type refinance_option misc_adjuster premium_type interest lock_period loan_amount program_category payment_type dti home_price down_payment point_mode].each do |key|
      key_value = params[key.to_sym]
      if key_value.present?
        if ((key == "home_price") || (key == "down_payment"))
          key_value = key_value.present? ? key_value.tr(',', '') : nil
        end
        instance_variable_set("@#{key}", key_value) if key_value.present?
      end
    end
  end

  def set_arm_options
    %w[arm_basic arm_advanced arm_caps arm_benchmark arm_margin].each do |key|
      if params.has_key?(key)
        key_value = params[key.to_sym]
        if key_value.present? && key_value != "All"
          if key == "arm_basic"
            @filter_data[:arm_basic] = split_arm_basic(params[:arm_basic])
            @arm_basic = params[:arm_basic]
          else
            instance_variable_set("@#{key}", key_value) if key_value.present?
            @filter_data[key] = adj_key_hash_required_value
          end
        end
      end
    end
  end

  def set_loan_amount(loan_amt)
    Program::LOAN_AMOUNT.each do |loan_value|
      if loan_value.present? && loan_value.include?("-")
        lower = loan_value.split("-").first.squish.to_i
        higher = loan_value.split("-").last.squish.to_i
        if loan_amt.between?(lower, higher)
          @loan_amount = loan_value
        end
      end
    end
  end

  def set_ltv_value(ltv)
    Program::LTV_VALUES.each do |ltv_value|
      ltv_value = ltv_value[0]
      unless ltv_value.include?("+")
        lower = ltv_value.split("-").first.squish.to_f
        higher = ltv_value.split("-").last.squish.to_f
        if ltv.between?(lower, higher)
          @ltv = ((lower*100).to_i..(higher*100).to_i).to_a.map{|e| e.to_f/100}
        end
      end
    end
  end

  def set_variable
    modify_ltv_cltv_credit_score
    modify_condition
    modify_true_condition
    if params[:others].present?
      modify_others_condition2
    end
    modify_others_condition1
    modify_variables
    loan_amt = (@home_price.to_i - @down_payment.to_i)
    set_loan_amount(loan_amt) if @source == 0
    set_ltv_value(loan_amt/@home_price.to_f*100) if @source == 0
    if params[ :loan_type ] == "ARM"
      set_arm_options
    end
  end

  def modify_others_condition1
    data = {}
    %w[fha va usda streamline fannie_mae fannie_mae_du freddie_mac freddie_mac_lp fannie_mae_product freddie_mac_product ].each do |key|
      key_value = params[key.to_sym]
      if key_value.present?
        if %w[fannie_mae_product freddie_mac_product].include?(key)
          data[key.to_sym] = key_value.to_s
          instance_variable_set("@#{key}", key_value)
        else
          data[key.to_sym] = true
        end
      end
    end
    if data.present?
      filter_query = data.to_a.map{|aa| "#{aa.first} = '#{aa.last}'"}.join(' OR ')
      @programs_all = @programs_all.where(filter_query)
    else
      @programs_all = []
    end
  end

  def modify_others_condition2
    @others_programs = @programs_all - @programs_all.where('fha =? OR va =? OR usda =? OR streamline =? OR fannie_mae =? OR fannie_mae_du =? OR freddie_mac =? OR freddie_mac_lp =? OR freddie_mac_product =? OR fannie_mae_product =?', true, true, true, true, true, true, true, true, "Home Possible", "HomeReady")
  end

  def find_programs_on_term_based(programs, find_term)
    program_list = []
    programs.each do |program|
      pro_term = program.term
      if (pro_term.to_s.length <=2 )
        if (pro_term == find_term)
          program_list << program
        end
      else
        first = pro_term/100
        last = pro_term%100
        term_arr = []
        if first < last
          term_arr = (first..last).to_a
        else
          term_arr = (last..first).to_a
        end
        if term_arr.include?(find_term)
          program_list << program
        end
      end
    end
    return program_list
  end

  def process_selected_programs(programs)
    program_list = []

    if @source > 0
      programs.each do |program|
        if program.base_rate.present?
          base_rate_keys = program.base_rate.keys.map{ |k| ActionController::Base.helpers.number_with_precision(k, :precision => 3)}

          interest_rate = ActionController::Base.helpers.number_with_precision(@interest.to_f.to_s, :precision => 3)

          key_list = program.base_rate.keys

          if(base_rate_keys.include?(interest_rate))
            rate_index = base_rate_keys.index(interest_rate)
            if( program.base_rate[key_list[rate_index]].keys.include?( @lock_period )
              )
              program_list << program
            end
          end
        end
      end
    else
      program_list = programs
    end

    return program_list
  end
 
  def search_programs
    program_list = @programs_all.present? ? @programs_all.where(@filter_data.except(:term)) : []
    program_list = (program_list + @others_programs).uniq
    if (program_list.present? && (@filter_data.keys & [:loan_size]).any?)
      program_list = program_list.select{ |m| m if m.loan_size.split("&").map{ |l| l.strip }.include?(@filter_data[:loan_size]) }
    end

    if program_list.present?
      program_list = process_selected_programs(program_list)
    end
    
    @result = []
    if program_list.present?
      @result = find_adjustments_by_searched_programs(program_list, @lock_period, @arm_basic, @arm_advanced, @arm_caps, @fannie_mae_product, @freddie_mac_product, @loan_purpose, @program_category, @property_type, @financing_type, @premium_type, @refinance_option, @misc_adjuster, @state_code, @loan_type, @loan_size, @result, @interest, @loan_amount, @ltv, @cltv, @term, @credit_score, @dti )
    end
  end

  # concer code for input api
  def find_adjustments_by_searched_programs(programs, value_lock_period, value_arm_basic, value_arm_advanced, value_arm_caps, value_fannie_mae_product, value_freddie_mac_product, value_loan_purpose, value_program_category, value_property_type, value_financing_type, value_premium_type, value_refinance_option, value_misc_adjuster, value_state, value_loan_type, value_loan_size, value_result, value_interest, value_loan_amount, value_ltv, value_cltv, value_term, value_credit_score, value_dti)
    data_hash = {}
    data_hash['LockDay'] = value_lock_period
    data_hash['ArmBasic'] = value_arm_basic
    data_hash['ArmAdvanced'] = value_arm_advanced
    data_hash['ArmCaps'] = value_arm_caps
    data_hash['FannieMaeProduct'] = value_fannie_mae_product
    data_hash['FreddieMacProduct'] = value_freddie_mac_product
    data_hash['LoanPurpose'] = value_loan_purpose
    data_hash['ProgramCategory'] = value_program_category
    data_hash['PropertyType'] = value_property_type
    data_hash['FinancingType'] = value_financing_type
    data_hash['PremiumType'] = value_premium_type
    data_hash['RefinanceOption'] = value_refinance_option
    data_hash['MiscAdjuster'] = value_misc_adjuster
    data_hash['LoanType'] = value_loan_type
    data_hash['LoanAmount'] = value_loan_amount
    data_hash['LTV'] = value_ltv
    data_hash['FICO'] = value_credit_score
    data_hash['LoanSize'] = value_loan_size
    data_hash['CLTV'] = value_cltv
    data_hash['State'] = value_state
    data_hash['Term'] = value_term
    data_hash['DTI'] = value_dti
    hash_obj = {
                 :id => "", :term => nil, :air => 0.0, :conforming => "", :fannie_mae => "", :fannie_mae_home_ready => "", :freddie_mac => "", :freddie_mac_home_possible => "", :fha => "", :va => "", :usda => "", :streamline => "", :full_doc => "", :loan_category => "", :program_category => "", :bank_name => "", :program_name => "", :loan_type => "", :loan_purpose => "", :arm_basic => "", :arm_advanced => "", :arm_caps => "", :loan_size => "", :fannie_mae_product => "", :freddie_mac_product => "", :fannie_mae_du => "", :freddie_mac_lp => "", :arm_benchmark => "", :arm_margin => "", :base_rate => 0.0, :adj_points => [], :adj_primary_key => [], :final_rate => [], :cell_number=>[], :closing_cost => 0.0, :adjustment_pair => {}, :apr => 0.0, :monthly_payment => 0.0
               }

    all_adj_ids = []
    # programs.each {|p| all_adj_ids +=  p.adjustment_ids.try(:split(',')).collect{|e| e.to_i}}
    programs.each {|p| all_adj_ids +=  p.adjustment_ids.split(',').collect{|e| e.to_i} if p.adjustment_ids}
    all_adj_ids.uniq!
    all_adjustments = Adjustment.find(all_adj_ids)

    programs.each_with_index do |pro, index|
      hash_obj.except(:air, :base_rate, :adj_points, :adj_primary_key, :final_rate, :cell_number, :closing_cost, :apr, :adjustment_pair, :monthly_payment).keys.map{ |key| hash_obj[key.to_sym] = pro.send(key) }

      if pro.base_rate.present?
        base_rate_keys = pro.base_rate.keys.map{ |k| ActionController::Base.helpers.number_with_precision(k, :precision => 3)}

        interest_rate = ActionController::Base.helpers.number_with_precision(value_interest.to_f.to_s, :precision => 3)

        key_list = pro.base_rate.keys

        if(base_rate_keys.include?(interest_rate))
          rate_index = base_rate_keys.index(interest_rate)
          if(pro.base_rate[key_list[rate_index]].keys.include?(value_lock_period))
            hash_obj[:base_rate] = pro.base_rate[key_list[rate_index]][value_lock_period]
          else
            hash_obj[:base_rate] = 0.0
          end

          %w(LoanType ArmBasic ArmAdvanced ArmCaps FannieMaeProduct FreddieMacProduct LoanPurpose LoanSize).each do |key_name|
            field_name = key_name&.strip&.underscore
            data_hash[key_name] = pro.send(field_name)
          end

          pro_term = pro.term
          if (pro_term.to_s.length <=2 )
            value_term = pro_term.to_s
          else
            first = pro_term/100
            last = pro_term%100
            value_term = first.to_s+"-"+last.to_s
          end
          data_hash['Term'] = value_term
        end
      end

      if pro.adjustment_ids.present?
       # program_adjustments = pro.adjustments

        program_adjustment_ids = pro.adjustment_ids.split(',').collect{|e| e.to_i}
        program_adjustments = all_adjustments.select{|adj| program_adjustment_ids.include?(adj.id) }

        if program_adjustments.present?
          program_adjustments.each do |adj|
            first_key = adj.data.keys.first
            key_list = first_key.split("/")
            adj_key_hash = {}

            non_adjustment_input_values = %w(HighBalance Conforming FannieMae FannieMaeHomeReady FreddieMac FreddieMacHomePossible FHA VA USDA Streamline FullDoc Jumbo FHLMC LPMI EPMI FNMA)

            key_list.each_with_index do |key_name, key_index|
              if(Adjustment::INPUT_VALUES.include?(key_name))
                if (0..6).include?(key_index)
                  required_data = case key_index
                                  when 0
                                    adj.data[first_key]
                                  when 1
                                    adj.data[first_key][adj_key_hash[key_index-1]]
                                  when 2
                                    adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]]
                                  when 3
                                    adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]]
                                  when 4
                                    adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]]
                                  when 5
                                    adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]]
                                  when 6
                                    adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]]
                                  end
                  if %w(LoanAmount LTV FICO LoanSize CLTV Term DTI).include?(key_name)
                    begin
                      if required_data.present?
                        method_name_initial_word = key_name&.strip&.underscore
                        response_data = send(*["#{method_name_initial_word}_key_of_adjustment",required_data.keys, data_hash[key_name]])
                        if response_data.present?
                          adj_key_hash[key_index] = response_data
                        else
                          break
                        end
                      else
                        break
                      end
                    rescue Exception
                    end
                  elsif key_name == "State"
                    begin
                      if value_state == "All"
                        first_state_key = required_data.keys.tap{|e| e.delete("cell_number") }.first
                        if required_data[first_state_key].present?
                          adj_key_hash[key_index] = first_state_key
                        else
                          break
                        end
                      else
                        adj_key_hash_required_value = required_data[data_hash[key_name]]
                        if adj_key_hash_required_value.present?
                          adj_key_hash[key_index] = data_hash[key_name]
                        else
                          break
                        end
                      end
                    rescue Exception
                    end
                  else
                    begin
                      if (0..6).include?(key_index)
                        if required_data[data_hash[key_name]].present?
                          adj_key_hash[key_index] = data_hash[key_name]
                        else
                          break
                        end
                      end
                    rescue Exception
                    end
                  end
                end
              else
                if (0..6).include?(key_index)
                  if non_adjustment_input_values.include?(key_name)
                    adj_key_hash[key_index] = "true"
                  end
                end
              end
            end
            point = case (adj_key_hash.keys.count-1)
              when 0
                adj.data[first_key][adj_key_hash[0]]
              when 1
                adj.data[first_key][adj_key_hash[0]][adj_key_hash[1]]
              when 2
                adj.data[first_key][adj_key_hash[0]][adj_key_hash[1]][adj_key_hash[2]]
              when 3
                adj.data[first_key][adj_key_hash[0]][adj_key_hash[1]][adj_key_hash[2]][adj_key_hash[3]]
              when 4
                adj.data[first_key][adj_key_hash[0]][adj_key_hash[1]][adj_key_hash[2]][adj_key_hash[3]][adj_key_hash[4]]
              when 5
                adj.data[first_key][adj_key_hash[0]][adj_key_hash[1]][adj_key_hash[2]][adj_key_hash[3]][adj_key_hash[4]][adj_key_hash[5]]
              when 6
                adj.data[first_key][adj_key_hash[0]][adj_key_hash[1]][adj_key_hash[2]][adj_key_hash[3]][adj_key_hash[4]][adj_key_hash[5]][adj_key_hash[6]]
              end

              if (((point.is_a? Float) || (point.is_a? Integer) || (point.is_a? String)) && (point != "N/A") && (point != "n/a") && (point != "NA") && (point != "na") && (point != "-"))
                hash_obj[:adj_points] << point.to_f
                hash_obj[:final_rate] << point.to_f
                hash_obj[:adj_primary_key] << adj.data.keys.first
                hash_obj[:adjustment_pair][adj.data.keys.first] = point.to_f
                hash_obj[:cell_number] << adj.data[first_key]["cell_number"]
              end
            end
        else
          hash_obj[:adj_points] = "Adjustment Not Present"
          hash_obj[:adj_primary_key] = "Adjustment Not Present"
        end
      end

      air_and_point_value = {}
      loan_amount = (@home_price.to_i - @down_payment.to_i).to_f rescue nil
      hash_obj[:adj_points] << 0.0 unless hash_obj[:adj_points].present?
      @point = 0
      if params[:point].present?
        @point = params[:point].to_i
      end
      air_and_point_value = adjusted_interest_rate_calculate(pro, hash_obj[:adj_points], @point)

      if air_and_point_value.present?
        air = air_and_point_value['air'].try(:to_f)
        hash_obj[:air] = air
        hash_obj[:monthly_payment] = calculate_monthly_payment(loan_amount, hash_obj[:air], @term )
        hash_obj[:starting_base_point] = air_and_point_value['starting_base_point']
        hash_obj[:air_point] = air_and_point_value['air_point']
        hash_obj[:apr] = calculate_apr_value( air, @term.to_i, loan_amount, air_and_point_value['air_point'] )
        hash_obj[:monthly_breakdown] = SearchApi::Calculation.new.monthly_expenses_breakdown(loan_amount, (@term.to_i*12), hash_obj[:monthly_payment], @home_price.to_i, @default_annual_home_insurance, @default_pmi_insurance, @default_property_tax_perc, @down_payment, params)
      end

      hash_obj[:final_rate] << (hash_obj[:base_rate].to_f < 50.0 ? hash_obj[:base_rate].to_f : (100 - hash_obj[:base_rate].to_f)) rescue nil
      if air_and_point_value['air_point'].present?
        hash_obj[:closing_cost] = ((air_and_point_value['air_point'].try(:to_f)/100)*loan_amount) rescue nil
      end

      if @point_mode == "All"
        value_result << hash_obj 
      else        
        value_result << hash_obj unless (hash_obj[:air] == 0.0)
      end

      hash_obj = {
                   :id => "", :term => nil, :air => 0.0, :conforming => "", :fannie_mae => "", :fannie_mae_home_ready => "", :freddie_mac => "", :freddie_mac_home_possible => "", :fha => "", :va => "", :usda => "", :streamline => "", :full_doc => "", :loan_category => "", :program_category => "", :bank_name => "", :program_name => "", :loan_type => "", :loan_purpose => "", :arm_basic => "", :arm_advanced => "", :arm_caps => "", :loan_size => "", :fannie_mae_product => "", :freddie_mac_product => "", :fannie_mae_du => "", :freddie_mac_lp => "", :arm_benchmark => "", :arm_margin => "", :base_rate => 0.0, :adj_points => [], :adj_primary_key => [], :final_rate => [], :cell_number=>[], :closing_cost => 0.0, :adjustment_pair => {}, :apr => 0.0, :monthly_payment => 0.0
                 }
    end
    results = value_result.sort_by { |h| [ h[:air], h[:closing_cost]] } || []
    benchmark_costs = calculate_savings_benchmark( results ) if results.present?
    results.each do |result|
      result[:saving] = calculate_each_savings( benchmark_costs, result )
    end
    return results || []
  end

  def calculate_savings_benchmark(results)
    benchmark_result = results[results.count*0.8]
    return benchmark_result[:monthly_payment] * @term.to_i * 12 + benchmark_result[:closing_cost]
  end

  def calculate_each_savings(benchmark_costs, result)
    saving_amt = 0.0
    if result[:monthly_payment].present? && result[:closing_cost].present?
      current_costs = result[:monthly_payment] * @term.to_i * 12 + result[:closing_cost]
      saving_amt = benchmark_costs - current_costs
    end
    return saving_amt
  end

  def loan_size_key_of_adjustment(loan_size_keys, value_loan_size)
    loan_size_keys.delete("cell_number")
    loan_size_key2 = ''
    if (loan_size_keys & value_loan_size.split("&")).present?
      loan_size_key2 = (value_loan_size.split("&") & loan_size_keys).first
    end
    return loan_size_key2
  end

  def loan_amount_key_of_adjustment(loan_amount_keys, value_loan_amount)
    loan_amount_keys.delete("cell_number")
    loan_amount_key2 = ''
    if value_loan_amount.include?("-")
      first_range, last_range = value_loan_amount.split("-").map{ |val| val.strip.to_i }
      if loan_amount_keys.present?
        loan_amount_keys.each do |loan_amount_key|
          %w($ ,).map{ |key| loan_amount_key = loan_amount_key.tr(key, '').strip  if loan_amount_key.include?(key) }
          if (loan_amount_key.include?("Inf") || loan_amount_key.include?("Infinity"))
            loan_amount_value = loan_amount_key.split("-").first.strip.to_i
            if (loan_amount_value <= first_range)
                loan_amount_key2 = loan_amount_key
            end
          else
            if loan_amount_key.include?("-")
              first_value_range, last_value_range = loan_amount_key.split("-").map{ |val| val.strip.to_i }
              if (first_value_range.between?(first_range, ((last_range-1))) || last_value_range.between?(first_range, ((last_range-1))))
                loan_amount_key2 = loan_amount_key
              end
            end
          end
        end
      end
    else
      full_range = value_loan_amount.split("+").first.strip.to_i
      if loan_amount_keys.present?
        loan_amount_keys.each do |loan_amount_key|
          %w($ ,).map{ |key| loan_amount_key = loan_amount_key.tr(key, '').strip  if loan_amount_key.include?(key) }
          if (loan_amount_key.include?("Inf") || loan_amount_key.include?("Infinity"))
            loan_amount_value = loan_amount_key.split("-").first.strip.to_i
            if (full_range <= loan_amount_value)
                loan_amount_key2 = loan_amount_key
            end
          else
            if loan_amount_key.include?("-")
              last_value_range = loan_amount_key.split("-").last.strip.to_i

              if (last_value_range >= full_range)
                loan_amount_key2 = loan_amount_key
              end
            end
          end
        end
      end
    end
    return loan_amount_key2
  end

  def ltv_key_of_adjustment(ltv_keys, value_ltv)
    ltv_keys.delete("cell_number")
    ltv_key2 = ''
    ltv_keys.each do |ltv_key|
      if (ltv_key.include?("Any") || ltv_key.include?("All"))
        ltv_key2 = ltv_key
      end
      if ltv_key.include?("-")
        ltv_key_range =[]
        if ltv_key.include?("Inf") || ltv_key.include?("Infinity")
          first_range = ltv_key.split("-").first.strip.to_f
          if params[:ltv] && params[:ltv].include?("+")
              ltv_key2 = ltv_key
          else
            if first_range <= value_ltv.last
              ltv_key2 = ltv_key
            end
          end
        else
          first_range = ltv_key.split("-").first.strip.to_f
          last_range =  ltv_key.split("-").last.strip.to_f
          if params[:ltv].present? && params[:ltv].include?("+")
            full_range = params[:ltv] && params[:ltv].split("+").first.strip.to_f
            if (full_range >= first_range && full_range < last_range )
              ltv_key2 = ltv_key
            end
          else
            (first_range..last_range).step(0.01) { |f| ltv_key_range << f.round(2) }
            ltv_key_range = ltv_key_range.uniq
            if (ltv_key_range & value_ltv).present?
              ltv_key2 = ltv_key
            end
          end
        end
      end
    end
    return ltv_key2
  end

  def cltv_key_of_adjustment(cltv_keys, value_cltv)
    cltv_keys.delete("cell_number")
    cltv_key2 = ''
    cltv_keys.each do |cltv_key|
      if (cltv_key.include?("Any") || cltv_key.include?("All"))
        cltv_key2 = cltv_key
      end
      if cltv_key.include?("-")
        cltv_key_range =[]
        if cltv_key.include?("Inf") || cltv_key.include?("Infinity")
          first_range = cltv_key.split("-").first.strip.to_f
          if params[:cltv] && params[:cltv].include?("+")
              cltv_key2 = cltv_key
          else
            if first_range <= value_cltv.last
              cltv_key2 = cltv_key
            end
          end
        else
          first_range = cltv_key.split("-").first.strip.to_f
          last_range =  cltv_key.split("-").last.strip.to_f
          if params[:cltv] && params[:cltv].include?("+")
            full_range = params[:cltv] && params[:cltv].split("+").first.strip.to_f
            if (full_range >= first_range && full_range < last_range )
              cltv_key2 = cltv_key
            end
          else
            (first_range..last_range).step(0.01) { |f| cltv_key_range << f.round(2) }
            cltv_key_range = cltv_key_range.uniq
            if (cltv_key_range & value_cltv).present?
              cltv_key2 = cltv_key
            end
          end
        end
      end
    end
    return cltv_key2
  end

  def term_key_of_adjustment(term_keys, value_term)
    term_keys.delete("cell_number")
    term_key2 = ''
    if value_term == "All"
      term_key2 = term_keys.first
    else
      term_keys.each do |term_key|
        if term_key.include?("-")
          first_range = term_key.split("-").first.strip.to_i
          if term_key.include?("Inf") || term_key.include?("Infinite")
            if value_term.include?("-")
              # first_term = value_term.split("-").first.strip.to_i
              last_term = value_term.split("-").last.strip.to_i
              if (first_range < last_term)
                term_key2 = term_key
              end
            else
              if (first_range <= value_term.to_i)
                term_key2 = term_key
              else
                break
              end
            end
          else
            first_range = term_key.split("-").first.strip.to_i
            last_range = term_key.split("-").last.strip.to_i
              if value_term.include?("-")
                first_term = value_term.split("-").first.strip.to_i
                last_term = value_term.split("-").last.strip.to_i

                value_range = (first_term..last_term).to_a
                term_range = (first_range..last_range).to_a
                if (value_range & term_range).present?
                  term_key2 = term_key
                end
              else
                if (value_term.to_i.between?(first_range, last_range))
                  term_key2 = term_key
                else
                  break
                end
              end
          end
        else
          if value_term.include?("-")
            first_term = value_term.split("-").first.strip.to_i
            last_term = value_term.split("-").last.strip.to_i
            # value_range = (first_term..last_term).to_a
            if (term_key.to_i.between?(first_term, last_term) ).present?
              term_key2 = term_key
            end
          else
            if (term_key.to_i == value_term.to_i)
              term_key2 = term_key
            else
              break
            end
          end
        end
      end
    end
    return term_key2
  end

  def fico_key_of_adjustment(fico_keys, value_credit_score)
    fico_keys.delete("cell_number")
    fico_key2 = ''
    fico_keys.each do |fico_key|
      if (fico_key.include?("Any") || fico_key.include?("All"))
        fico_key2 = fico_key
      end
      if fico_key.include?("-")
        #fico_key_range =[]
        if fico_key.include?("Inf") || fico_key.include?("Infinity")
          first_range = fico_key.split("-").first.strip.to_i
          if params[:credit_score] && params[:credit_score].include?("+")
              fico_key2 = fico_key
          else
            if first_range <= value_credit_score.last
              fico_key2 = fico_key
            end
          end
        else
          first_range = fico_key.split("-").first.strip.to_i
          last_range =  fico_key.split("-").last.strip.to_i
          if params[:credit_score] && params[:credit_score].include?("+")
            full_range = params[:credit_score] && params[:credit_score].split("+").first.strip.to_i
            if (full_range >= first_range && full_range < last_range )
              fico_key2 = fico_key
            end
          else
            if (value_credit_score & (first_range..last_range).to_a).present?
              fico_key2 = fico_key
            end
          end
        end
      end
    end
    return fico_key2
  end

  def dti_key_of_adjustment(dti_keys, value_dti)
    dti_keys.delete("cell_number")
    dti_key_2 = ''
    dti_keys.each do |dti_key|
      if dti_key == value_dti
        dti_key_2 = dti_key
      end
    end
    return dti_key_2
  end

  def adjusted_interest_rate_calculate(pro, adj_points, point)
    air_key = {}
    base_rate_keys = pro.base_rate.keys.first.present? ? pro.base_rate.keys : pro.base_rate.keys.drop(1)
    total_adj = adj_points.present? ? adj_points.sum : 0
    base_rate_column = pro.base_rate.values.map{|a| a[@lock_period]}.compact
    final_rate_column = base_rate_column.map{|a| ( ( a.to_f < 50 ? a.to_f : ( 100 - a.to_f ) ) + total_adj.to_f).round(3)}.compact
    
    air_point = final_rate_column.map{|a| a.to_f if a.to_i == point && a >= 0 }.compact.min
    unless air_point.present?
      if @source == 0 || (@source == 1 && @point_mode != "Regular")
        air_point = final_rate_column.map{|a| a.to_f if a.to_i >= point - 5 && a.to_i < point + 1 }.compact.max # closest one to Point on the other side of Point. 
      end
    end

    if air_point.present?
      air_key['air_point'] = air_point.to_f.round(3)
      air_key['air'] = (base_rate_keys[final_rate_column.index(air_point)]).to_f.round(3)
      air_key['starting_base_point'] = base_rate_column[final_rate_column.index(air_point)].to_f.round(3)
    end
    return air_key
  end

  def calculate_monthly_payment(p, interest, term)
    monthly_payment = nil
    if interest.present? && p.present? && term.present?
      if interest != 0.0
        r = (interest.to_f/12)/100 rescue nil
        n = term.to_i*12 rescue nil
        monthly_payment = ((r * p) / (1 - ((1 + r) ** (-1 * n)))) rescue nil
      end
    end
    return monthly_payment
  end

  def calculate_apr_value( air, term, loan_amount, points )
    # num_months    = term * 12.0
    # fees          = points / 100.0 * loan_amount
    # interest_paid = monthly_payment * num_months - loan_amount
    # number_days   = num_months * 30.0
    # return (((fees + interest_paid) / loan_amount) / number_days ) * 365.0 * 100.0
    if ( points == 0 )
      return air
    elsif ( points < 0 )
      loan = FinanceMath::Loan.new(nominal_rate: air, duration: term * 12, amount: loan_amount, structure_fee: -points, currency_protection: 0, fee: 0)
      return air * 2 - loan.apr
    else
      loan = FinanceMath::Loan.new(nominal_rate: air, duration: term * 12, amount: loan_amount, structure_fee: points, currency_protection: 0, fee: 0)
      return loan.apr
    end
  end
end
