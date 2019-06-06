class SearchApi::DashboardController < ApplicationController
  layout "application"
  before_action :set_default

  # def index
  #   list_of_banks_and_programs_with_search_results
  # end

  def list_of_banks_and_programs_with_search_results
    @time = Benchmark.measure {
      @all_banks_name = @banks.pluck(:name)
      if params["commit"].present?
        set_variable
      else
        set_default_values_without_submition
      end
      find_base_rate
      fetch_programs_by_bank(true)
    }
    puts "Query Time  #{@time.real}"
  end

  def fetch_programs_by_bank(html_type=false)
    

    if params[:bank_name].present?
      @all_programs = @all_programs.where(bank_name: params[:bank_name]) unless params[:bank_name].eql?('All')
    end

    if params[:loan_category].present?
      @all_programs = @all_programs.where(loan_category: params[:loan_category]) unless params[:loan_category].eql?('All')
    end

    if params[:pro_category].present?
      @all_programs = @all_programs.where(program_category: params[:pro_category]) unless (params[:pro_category] == "All" || params[:pro_category] == "No Category")
    end

    @program_names = @all_programs.pluck(:program_name).uniq.compact.sort
    @loan_categories = @all_programs.pluck(:loan_category).uniq.compact.sort
    @program_categories = @all_programs.pluck(:program_category).uniq.compact.sort

    if @program_categories.present?
      @program_categories.prepend(["All"])
    else
      @program_categories << "No Category"
    end

    # N+1 query, there is unrequired loop, we need to remove that, so that it will load quickly
    render json: {program_list: @program_names.map{ |lc| {name: lc}}, loan_category_list: @loan_categories.map{ |lc| {name: lc}}, pro_category_list: @program_categories.map{ |lc| {name: lc}}} unless html_type
  end

  private

  def set_default_values_without_submition
    @filter_not_nil[:term] = nil
    @filter_not_nil[:arm_basic] = nil
    @filter_not_nil[:arm_caps] = nil
    @filter_not_nil[:arm_advanced] = nil
    @filter_not_nil[:arm_benchmark] = nil
    @filter_not_nil[:arm_margin] = nil
    set_flag_loan_type(true)
  end

  def set_flag_loan_type(flag)
    @flag_loan_type = flag
  end

  def set_default
    @banks = Bank.all
    @all_programs = Program.all
    @term_list = @all_programs.where('term <= ?', 999).pluck(:term).compact.uniq.push(5,10,15,20,25,30).uniq.sort.map{|y| [y.to_s + " yrs" , y]}.prepend(["All"])
    # @term_list = (Program.pluck(:term).reject(&:blank?).uniq.map{|n| n if n.to_s.length < 3}.reject(&:blank?).push(5,10,15,20,25,30).uniq.sort).map{|y| [y.to_s + " yrs" , y]}.prepend(["All"])
    @arm_advanced_list = @all_programs.pluck(:arm_advanced).push("5-5").compact.uniq.reject(&:empty?).map{|c| [c]}
    # @arm_advanced_list = Program.pluck(:arm_advanced).push("5-5").uniq.compact.reject { |c| c.empty? }.map{|c| [c]}
    @arm_caps_list = @all_programs.pluck(:arm_caps).push("3-2-5").compact.uniq.reject(&:empty?).map{|c| [c]}
    # @arm_caps_list = Program.pluck(:arm_caps).push("3-2-5").uniq.compact.reject { |c| c.empty? }.map{|c| [c]}
    @base_rate = 0.0
    @filter_data = {}
    @filter_not_nil = {}
    @interest = "4.000"
    @term = "30"
    @ltv = []
    @cltv = []
    @credit_score = []
    @flag_loan_type = false
    @lock_period ="30"
    @loan_size = "High-Balance"
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
    @refinance_option ="Cash Out"
    @misc_adjuster = "CA Escrow Waiver (Full or Taxes Only)"
    @state = "All"
    @result = []
    @loan_amount = "0 - 50000"
    @ltv1 = "65.01 - 70.00"
    @credit_score1 = "700-719"
    @dti = "25.6%"
    @loan_purpose = "Purchase"
    @home_price = "300000"
    @down_payment = "50000"
    @coverage = "30.5%"
    @margin = "2.0"
    # ltv_range = 65.01..70.0
    # array_data = []
    # ltv_range.step(0.01) { |f| array_data << f.round(2) } rescue nil
    # @ltv = array_data.try(:uniq)

    # cltv_range = 75.01..80.0
    # array_data = []
    # cltv_range.step(0.01) { |f| array_data << f.round(2) } rescue nil
    # @cltv = array_data.try(:uniq)
    @ltv = (6500..7000).to_a.map{|e| e.to_f/100}
    @cltv = (7501..8000).to_a.map{|e| e.to_f/100}

    @credit_score = (700..719).to_a
  end

  def modified_ltv_cltv_credit_score
    %w[ltv cltv credit_score].each do |key|
      array_data = []
      if key == "ltv" || key == "cltv"
        key_value = params[key.to_sym]
        if key_value.present?
          if key_value.include?("-")
            key_range = (key_value.split("-").first.to_f..key_value.split("-").last.to_f)
            key_range.step(0.01) { |f| array_data << f }
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

  def modified_condition
    %w[fannie_mae_product freddie_mac_product bank_name program_name pro_category loan_category loan_purpose].each do |key|
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
            else
              @filter_data[key.to_sym] = key_value
            end
          end
          if %w[fannie_mae_product freddie_mac_product pro_category loan_category loan_purpose].include?(key)
            instance_variable_set("@#{key}", key_value)
          end
        else
          if %w[fannie_mae_product freddie_mac_product loan_purpose].include?(key)
            @filter_not_nil[key.to_sym] = nil
          end
        end
      end
    end
  end

  def modified_true_condition
    %w[fannie_mae freddie_mac fannie_mae_du freddie_mac_lp fha va usda streamline full_doc].each do |key|
      key_value = params[key.to_sym]
      if key_value.present?
        @filter_data[key.to_sym] = true
      end
    end
  end

  def modified_variables
    %w[state property_type financing_type refinance_option refinance_option misc_adjuster premium_type interest lock_period loan_amount program_category payment_type dti].each do |key|
      key_value = params[key.to_sym]
      instance_variable_set("@#{key}", key_value) if key_value.present?
    end
  end

  def set_term
    if params[:term].present?
      if (params[:term] == "All")
        @filter_not_nil[:term] = nil
      else
        @filter_data[:term] = params[:term].to_i
        @term = params[:term]
        @program_term = params[:term].to_i
      end
    end
  end

  def set_arm_basic
    if params[:arm_basic].present?
      if (params[:arm_basic] == "All")
        @filter_not_nil[:arm_basic] = nil
      else
        if params[:arm_basic].include?("/")
          @filter_data[:arm_basic] = params[:arm_basic].split("/").first
          @arm_basic = params[:arm_basic]
        end
      end
    end
  end

  def set_arm_advanced
    if params[:arm_advanced].present?
      if params[:arm_advanced] == "All"
        @filter_not_nil[:arm_advanced] = nil
      else
        @arm_advanced = params[:arm_advanced]
        @filter_data[:arm_advanced] = params[:arm_advanced]
      end
    end
  end

  def set_arm_caps
    if params[:arm_caps].present?
      if params[:arm_caps] == "All"
        @filter_not_nil[:arm_caps] = nil
      else
        @arm_caps = params[:arm_caps]
        @filter_data[:arm_caps] = params[:arm_caps]
      end
    end
  end

  def set_arm_benchmark
    if params[:arm_benchmark].present?
      if params[:arm_benchmark] == "All"
        @filter_not_nil[:arm_benchmark] = nil
      else
        @arm_benchmark = params[:arm_benchmark]
        @filter_data[:arm_benchmark] = params[:arm_benchmark]
      end
    end
  end

  def set_arm_margin
    if params[:arm_margin].present?
      if params[:arm_margin] == "All"
        @filter_not_nil[:arm_margin] = nil
      else
        @arm_margin = params[:arm_margin].to_f
        @filter_data[:arm_margin] = params[:arm_margin].to_f
      end
    end
  end

  def set_flag_loan_type(flag)
    @flag_loan_type = flag
  end

  def set_variable
    modified_ltv_cltv_credit_score
    modified_condition
    modified_true_condition
    modified_variables
    if params[:loan_type].present?
      @loan_type = params[:loan_type]
      if params[:loan_type] == "All"
        @filter_not_nil[:loan_type] = nil
        set_flag_loan_type(true)
        set_term
        set_arm_basic
        set_arm_advanced
        set_arm_caps
        set_arm_benchmark
        set_arm_margin
      else
        @filter_data[:loan_type] = params[:loan_type]
        if params[:loan_type] =="ARM"
          set_flag_loan_type(false)
          set_arm_basic
          set_arm_advanced
          set_arm_caps
          set_arm_benchmark
          set_arm_margin
        end
        if params[:loan_type] !="ARM"
          set_term
        end
      end
    else
      set_flag_loan_type(true)
    end

    if params[:loan_size].present?
      if params[:loan_size] == "All"
        @filter_not_nil[:loan_size] = nil
      end
    end
    @credit_score1 = params[:credit_score].present? ? params[:credit_score] : ""
    @ltv1 = params[:ltv].present? ? params[:ltv] : ""
    @home_price = params[:home_price].present? ? params[:home_price].tr(',', '') : "300000"
    @down_payment = params[:down_payment].present? ? params[:down_payment].tr(',', '') : "50000"
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

  def calculate_base_rate_of_selected_programs(programs)
    program_list = []
    programs.each do |program|
      if program.base_rate.present?
        base_rate_keys = program.base_rate.keys.map{ |k| ActionController::Base.helpers.number_with_precision(k, :precision => 3)}

        interest_rate = ActionController::Base.helpers.number_with_precision(@interest.to_f.to_s, :precision => 3)

        key_list = program.base_rate.keys

        if(base_rate_keys.include?(interest_rate))
          rate_index = base_rate_keys.index(interest_rate)
          if(program.base_rate[key_list[rate_index]].keys.include?(@lock_period))
              program_list << program
          end
        end
      end
    end
    return program_list
  end

  def search_programs_with_loan_type_all
    program_list = []
    term_all_programs = []
    arm_all_programs = []
    arm_hash = {}
    @all_programs = @all_programs.where(@filter_data.except(:arm_basic, :arm_advanced, :arm_caps, :arm_benchmark, :arm_margin, :term))

      term_all_programs = @all_programs.where.not(loan_type: "ARM")
      arm_all_programs = @all_programs.where(loan_type: "ARM")

      %i[arm_basic arm_advanced arm_caps arm_margin arm_benchmark].each do |term|
        if (@filter_not_nil.keys.include?(term))
          arm_hash[term] = nil
        end
      end
      arm_all_programs = arm_all_programs.where.not(arm_hash)
      
      if (@filter_data.keys & [:term]).any?
        term_all_programs = find_programs_on_term_based(term_all_programs, @filter_data[:term])
      end
      program_list = (term_all_programs + arm_all_programs)


      program_list = calculate_base_rate_of_selected_programs(program_list)
    total_searched_program = []

    if program_list.present?
      if params[:loan_size].present?
        if params[:loan_size] != "All"
          total_searched_program = []
          program_list = program_list.where.not(loan_size: nil)
            program_list.each do |pro|
              if(pro.loan_size.split("&").map{ |l| l.strip }.include?(params[:loan_size]))
                total_searched_program << pro
              end
            end
        else
          total_searched_program = program_list
        end
      else
        total_searched_program = program_list
      end
    end

    @result= []
    if total_searched_program.present?
      @result = find_adjustments_by_searched_programs(total_searched_program, @lock_period, @arm_basic, @arm_advanced, @arm_caps, @fannie_mae_product, @freddie_mac_product, @loan_purpose, @program_category, @property_type, @financing_type, @premium_type, @refinance_option, @misc_adjuster, @state, @loan_type, @loan_size, @result, @interest, @loan_amount, @ltv, @cltv, @term, @credit_score, @dti )
    end
  end
  # def search_programs_with_loan_type_all
  #   term_programs = []
  #   arm_programs = []
  #   if (@filter_not_nil.keys & [:arm_basic, :arm_advanced, :arm_caps, :arm_margin, :arm_benchmark, :term]).any?
  #     term_programs = Program.where.not(loan_type: "ARM")
  #     arm_all_programs = Program.where(loan_type: "ARM")

  #     %i[arm_basic arm_advanced arm_caps arm_margin arm_benchmark].each do |term|
  #       if (@filter_not_nil.keys.include?(term))
  #         arm_programs << arm_all_programs.where.not(term => nil)
  #       end
  #     end
  #     arm_programs = arm_programs.flatten.compact.uniq
  #   else
  #     if (@filter_not_nil.keys.include?(:term))
  #       term_programs = Program.where.not(loan_type: "ARM")
  #     elsif (@filter_not_nil.keys.include?(:arm_basic || :arm_advanced || :arm_margin || :arm_benchmark || :arm_caps))
  #       arm_programs = Program.where(loan_type: "ARM")
  #     else
  #       term_programs = Program.where.not(loan_type: "ARM")
  #       arm_programs = Program.where(loan_type: "ARM")
  #     end
  #   end
  #   if (@filter_data.keys & [:term]).any?
  #     term_programs1 = Program.where(@filter_data.except(:arm_basic, :arm_advanced, :arm_caps, :arm_benchmark, :arm_margin, :term))
  #     term_programs = find_programs_on_term_based(term_programs1, @filter_data[:term])
  #     if (@filter_data.keys & [:term] & [:arm_basic, :arm_advanced, :arm_caps, :arm_margin, :arm_benchmark, :term]).any?
  #       arm_programs = arm_all_programs.where(@filter_data.except(:term))
  #     end
  #   elsif (@filter_data.keys & [:arm_basic, :arm_advanced, :arm_caps, :arm_margin, :arm_benchmark]).any?
  #     arm_programs = arm_all_programs.where(@filter_data.except(:term))
  #   end
  #   if arm_programs.present?
  #     arm_ids = arm_programs.pluck(:id)
  #     arm_programs = Program.where(id: arm_ids).where(@filter_data.except(:term))
  #     # arm_programs = arm_programs.where(@filter_data.except(:term))
  #   end

  #   if term_programs.present?
  #     term_ids = term_programs.pluck(:id)
  #     term_programs = Program.where(id: term_ids).where(@filter_data.except(:arm_basic, :arm_advanced, :arm_caps, :arm_benchmark, :arm_margin, :term))
  #     # term_programs = term_programs.where(@filter_data.except(:arm_basic, :arm_advanced, :arm_caps, :arm_benchmark, :arm_margin, :term))
  #   end
  #   total_searched_program1 = calculate_base_rate_of_selected_programs((term_programs + arm_programs).uniq)
  #   total_searched_program = []

  #   if total_searched_program1.present?
  #     if params[:loan_size].present?
  #       if params[:loan_size] == "All"
  #         total_searched_program = total_searched_program1
  #       else
  #         @loan_size = params[:loan_size]
  #         # total_searched_program1 = total_searched_program1.where.not(loan_size: nil)
  #         total_searched_program1 = total_searched_program1.map{ |pro| pro if pro.loan_size!=nil}.compact
  #         total_searched_program1.each do |pro|
  #           if(pro.loan_size.split("&").map{ |l| l.strip }.include?(params[:loan_size]))
  #             total_searched_program << pro
  #           end
  #         end
  #       end
  #     else
  #       total_searched_program = total_searched_program1
  #     end
  #   end
  #   @result= []
  #   if total_searched_program.present?
  #     @result = find_adjustments_by_searched_programs(total_searched_program, @lock_period, @arm_basic, @arm_advanced, @arm_caps, @fannie_mae_product, @freddie_mac_product, @loan_purpose, @program_category, @property_type, @financing_type, @premium_type, @refinance_option, @misc_adjuster, @state, @loan_type, @loan_size, @result, @interest, @loan_amount, @ltv, @cltv, @term, @credit_score, @dti )
  #   end
  # end

  # def search_programs_with_selected_loan_type
  #   @program_list = Program.where(@filter_data.except(:term))
  #   @program_list = @program_list.where.not(@filter_not_nil)
  #   @program_list2 = []
  #   if @program_list.present?
  #     if @program_term.present?
  #       @program_list = @program_list.where.not(term:nil)
  #       @program_list2 = find_programs_on_term_based(@program_list, @program_term)
  #     else
  #       @program_list2 = @program_list
  #     end

  #     if @program_list2.present?
  #       @program_list3 = []
  #       if params[:loan_size].present?
  #         if params[:loan_size] == "All"
  #           @program_list3 = @program_list2
  #         else
  #           @loan_size = params[:loan_size]
  #           @program_list2 = @program_list2.map{ |pro| pro if pro.loan_size!=nil}.compact
  #           @program_list2.each do |pro|
  #             if(pro.loan_size.split("and").map{ |l| l.strip }.include?(params[:loan_size]))
  #               @program_list3 << pro
  #             end
  #           end
  #         end
  #       else
  #         @program_list3 = @program_list2
  #       end
  #     end

  #     @programs =[]
  #     if @program_list3.present?
  #       @programs = calculate_base_rate_of_selected_programs(@program_list3)
  #     end
  #     @result= []
  #     if @programs.present?
  #       @result = find_adjustments_by_searched_programs(@programs, @lock_period, @arm_basic, @arm_advanced, @arm_caps, @fannie_mae_product, @freddie_mac_product, @loan_purpose, @program_category, @property_type, @financing_type, @premium_type, @refinance_option, @misc_adjuster, @state, @loan_type, @loan_size, @result, @interest, @loan_amount, @ltv, @cltv, @term, @credit_score, @dti )
  #     end
  #   end
  # end

  def search_programs_with_selected_loan_type
    program_list = @all_programs.where.not(@filter_not_nil)
    program_list = program_list.where(@filter_data.except(:term))
    program_list2 = []
    if program_list.present?

      if program_list.present?
        if params[:loan_size].present?
          if params[:loan_size] != "All"
            program_list = program_list.where.not(loan_size: nil).compact
              program_list.each do |pro|
                if(pro.loan_size.split("&").map{ |l| l.strip }.include?(params[:loan_size]))
                  program_list2 << pro
                end
              end
          else
            program_list2 = program_list
          end
        else
          program_list2 = program_list
        end
      end

      if ((@filter_data.keys & [:term]).any? && program_list2.present?)
        program_list2 = find_programs_on_term_based(program_list2, @program_term)
      end

      @programs =[]
      if program_list2.present?
        program_list2 = calculate_base_rate_of_selected_programs(program_list2)
      end
      @result= []
      if program_list2.present?
        @result = find_adjustments_by_searched_programs(program_list2, @lock_period, @arm_basic, @arm_advanced, @arm_caps, @fannie_mae_product, @freddie_mac_product, @loan_purpose, @program_category, @property_type, @financing_type, @premium_type, @refinance_option, @misc_adjuster, @state, @loan_type, @loan_size, @result, @interest, @loan_amount, @ltv, @cltv, @term, @credit_score, @dti )
      end
    end
  end

  def find_base_rate
    if (@flag_loan_type)
      search_programs_with_loan_type_all
    else
      search_programs_with_selected_loan_type
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
    data_hash['MiscAdjuster'] = value_misc_adjuster
    data_hash['LoanSize'] = value_loan_size
    data_hash['CLTV'] = value_cltv
    data_hash['State'] = value_state
    data_hash['Term'] = value_term
    data_hash['DTI'] = value_dti

    hash_obj = {
                 :id => "", :term => nil, :air => 0.0, :conforming => "", :fannie_mae => "", :fannie_mae_home_ready => "", :freddie_mac => "", :freddie_mac_home_possible => "", :fha => "", :va => "", :usda => "", :streamline => "", :full_doc => "", :loan_category => "", :program_category => "", :bank_name => "", :program_name => "", :loan_type => "", :loan_purpose => "", :arm_basic => "", :arm_advanced => "", :arm_caps => "", :loan_size => "", :fannie_mae_product => "", :freddie_mac_product => "", :fannie_mae_du => "", :freddie_mac_lp => "", :arm_benchmark => "", :arm_margin => "", :base_rate => 0.0, :adj_points => [], :adj_primary_key => [], :final_rate => [], :cell_number=>[], :closing_cost => 0.0, :apr => 0.0
               }

    all_adj_ids = []
    # programs.each {|p| all_adj_ids +=  p.adjustment_ids.try(:split(',')).collect{|e| e.to_i}}
    programs.each {|p| all_adj_ids +=  p.adjustment_ids.split(',').collect{|e| e.to_i} if p.adjustment_ids}
    all_adj_ids.uniq!
    all_adjustments = Adjustment.find(all_adj_ids)

    programs.each do |pro|
      hash_obj.except(:air, :base_rate, :adj_points, :adj_primary_key, :final_rate, :cell_number, :closing_cost, :apr).keys.map{ |key| hash_obj[key.to_sym] = pro.send(key) }

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

            adj_key_hash.keys.each do |hash_key, index|
              begin
                point = case hash_key
                        when 0
                          adj.data[first_key][adj_key_hash[hash_key]]
                        when 1
                          adj.data[first_key][adj_key_hash[hash_key-1]][adj_key_hash[hash_key]]
                        when 2
                          adj.data[first_key][adj_key_hash[hash_key-2]][adj_key_hash[hash_key-1]][adj_key_hash[hash_key]]
                        when 3
                          adj.data[first_key][adj_key_hash[hash_key-3]][adj_key_hash[hash_key-2]][adj_key_hash[hash_key-1]][adj_key_hash[hash_key]]
                        when 4
                          adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]]
                        when 5
                          adj.data[first_key][adj_key_hash[hash_key-5]][adj_key_hash[hash_key-4]][adj_key_hash[hash_key-3]][adj_key_hash[hash_key-2]][adj_key_hash[hash_key-1]][adj_key_hash[hash_key]]
                        when 6
                          adj.data[first_key][adj_key_hash[hash_key-6]][adj_key_hash[hash_key-5]][adj_key_hash[hash_key-4]][adj_key_hash[hash_key-3]][adj_key_hash[hash_key-2]][adj_key_hash[hash_key-1]][adj_key_hash[hash_key]]
                        end

                if adj_key_hash.keys.count-1==hash_key
                  if (((point.is_a? Float) || (point.is_a? Integer) || (point.is_a? String)) && (point != "N/A") && (point != "n/a") && (point != "NA") && (point != "na") && (point != "-"))
                    hash_obj[:adj_points] << point.to_f
                    hash_obj[:final_rate] << point.to_f
                    hash_obj[:adj_primary_key] << adj.data.keys.first
                    hash_obj[:cell_number] << adj.data[first_key]["cell_number"]
                  end
                end
              rescue Exception
              end
            end

          end
        else
          hash_obj[:adj_points] = "Adjustment Not Present"
          hash_obj[:adj_primary_key] = "Adjustment Not Present"
        end
      end

      air_values = []
      if hash_obj[:adj_points].present?
        @point = '0'
        if params[:point].present?
          @point = params[:point]
        end
        air_values = adjusted_interest_rate_calculate(pro, hash_obj[:adj_points], @point.to_i)
        if air_values.try(:last).present?
          hash_obj[:air] = air_values.try(:last).try(:to_f)
          hash_obj[:apr] = calculate_apr_value(hash_obj[:air])
        else
          hash_obj[:air] = 0.0
        end
      end

      hash_obj[:final_rate] << (hash_obj[:base_rate].to_f < 50.0 ? hash_obj[:base_rate].to_f : (100 - hash_obj[:base_rate].to_f)) rescue nil

      loan_amount = (@home_price.to_i - @down_payment.to_i) rescue nil

      if air_values.try(:first).present?
        hash_obj[:closing_cost] = ((air_values.try(:first).try(:to_f)/100)*loan_amount) rescue nil
      else
        hash_obj[:closing_cost] = 0.0
      end

      hash_obj[:monthly_payment] = calculate_monthly_payment(loan_amount, hash_obj[:air], @term )
      value_result << hash_obj unless (hash_obj[:air] == 0.0)
      # value_result << hash_obj

      hash_obj = {
                   :id => "", :term => nil, :air => 0.0, :conforming => "", :fannie_mae => "", :fannie_mae_home_ready => "", :freddie_mac => "", :freddie_mac_home_possible => "", :fha => "", :va => "", :usda => "", :streamline => "", :full_doc => "", :loan_category => "", :program_category => "", :bank_name => "", :program_name => "", :loan_type => "", :loan_purpose => "", :arm_basic => "", :arm_advanced => "", :arm_caps => "", :loan_size => "", :fannie_mae_product => "", :freddie_mac_product => "", :fannie_mae_du => "", :freddie_mac_lp => "", :arm_benchmark => "", :arm_margin => "", :base_rate => 0.0, :adj_points => [], :adj_primary_key => [], :final_rate => [], :cell_number=>[], :closing_cost => 0.0, :apr => 0.0
                 }
    end
    return value_result.sort_by { |h| h[:air] } || []
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
          if params[:ltv] && params[:ltv].include?("+")
            full_range = params[:ltv] && params[:ltv].split("+").first.strip.to_f
            if (full_range >= first_range && full_range < last_range )
              ltv_key2 = ltv_key
            end
          else
            (first_range..last_range).step(0.01) { |f| ltv_key_range << f }
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
            (first_range..last_range).step(0.01) { |f| cltv_key_range << f }
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
        fico_key_range =[]
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
    air_key = []
    base_rate_keys = pro.base_rate.keys
    total_adj = adj_points.present? ? adj_points.sum : 0
    yellow_keys = pro.base_rate.values.map{|a| a[@lock_period]}
    orange_keys = yellow_keys.map{|a| (a.to_f + total_adj.to_f).round(3)}
    air_value = orange_keys.map{|a| a.to_f if a.to_i == point && a.positive?}.compact.min
    if air_value.present?
      air_key << air_value
      air_key << base_rate_keys[orange_keys.index(air_value)]
    else
      air_key << 0.0
      air_key << 0.0
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

  def calculate_apr_value(air_value)
    ( 1 + air_value / 30 ) ** 365 - 1 rescue nil
  end
end
