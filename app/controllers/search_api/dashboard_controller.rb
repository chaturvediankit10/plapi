class SearchApi::DashboardController < ActionController::Base
  layout "application"
  before_action :set_default

  def index
    @banks = Bank.all
    @all_banks_name = @banks.pluck(:name)
    if params["commit"].present?
      set_variable
      find_base_rate
    end
    fetch_programs_by_bank(true)
  end

  def fetch_programs_by_bank(html_type=false)
    @all_programs = Program.all
    @program_names = @all_programs.pluck(:program_name).uniq.compact.sort
    @loan_categories = @all_programs.pluck(:loan_category).uniq.compact.sort
    @program_categories = @all_programs.pluck(:program_category).uniq.compact.sort

    if params[:bank_name].present?
      if (params[:bank_name] == "All")
        @program_names = @all_programs.pluck(:program_name).uniq.compact.sort
        @loan_categories = @all_programs.pluck(:loan_category).uniq.compact.sort
        @program_categories = @all_programs.pluck(:program_category).uniq.compact.sort
      else
        @all_programs = @all_programs.where(bank_name: params[:bank_name])
        @program_names = @all_programs.pluck(:program_name).uniq.compact.sort
        @loan_categories = @all_programs.pluck(:loan_category).uniq.compact.sort
        @program_categories = @all_programs.pluck(:program_category).uniq.compact.sort
      end
    end
    if params[:loan_category].present?
      if (params[:loan_category] == "All")
        @program_names = @all_programs.pluck(:program_name).uniq.compact.sort
        @program_categories = @all_programs.pluck(:program_category).uniq.compact.sort
      else
        @all_programs = @all_programs.where(loan_category: params[:loan_category])
        @program_names = @all_programs.pluck(:program_name).uniq.compact.sort
        @program_categories = @all_programs.pluck(:program_category).uniq.compact.sort
      end
    end
    if params[:pro_category].present?
      if (params[:pro_category] == "All" || params[:pro_category] == "No Category")
        @program_names = @all_programs.pluck(:program_name).uniq.compact.sort
      else
        @all_programs = @all_programs.where(program_category: params[:pro_category])
        @program_names = @all_programs.pluck(:program_name).uniq.compact.sort
      end
    end

    if @program_categories.present?
      @program_categories.prepend(["All"])
    else
      @program_categories << "No Category"
    end
    render json: {program_list: @program_names.map{ |lc| {name: lc}}, loan_category_list: @loan_categories.map{ |lc| {name: lc}}, pro_category_list: @program_categories.map{ |lc| {name: lc}}} unless html_type
  end

  def set_default
    @term_list = (Program.pluck(:term).reject(&:blank?).uniq.map{|n| n if n.to_s.length < 3}.reject(&:blank?).push(5,10,15,20,25,30).uniq.sort).map{|y| [y.to_s + " yrs" , y]}.prepend(["All"])
    @arm_advanced_list = Program.pluck(:arm_advanced).push("3-2-5").uniq.compact.reject { |c| c.empty? }.map{|c| [c]}
    @base_rate = 0.0
    @filter_data = {}
    @filter_not_nil = {}
    @interest = "4.000"
    @lock_period ="30"
    @loan_size = "High-Balance"
    @loan_type = "Fixed"
    @term = "30"
    @ltv = []
    @credit_score = []
    @cltv = []
    @fannie_mae_product = "HomeReady"
    @freddie_mac_product = "Home Possible"
    @flag_loan_type = false
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
            instance_variable_set("@#{key}", array_data.uniq)
          end
        end
      end
      if key == "credit_score"
        key_value = params[key.to_sym]
        if key_value.present?
          array_data = (key_value.split("-").first.to_i..key_value.split("-").last.to_i)
          instance_variable_set("@#{key}", array_data.uniq)
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
    %w[fannie_mae freddie_mac du lp fha va usda streamline full_doc].each do |key|
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
        set_arm_benchmark
        set_arm_margin
      else
        @filter_data[:loan_type] = params[:loan_type]
        if params[:loan_type] =="ARM"
          set_flag_loan_type(false)
          set_arm_basic
          set_arm_advanced
          set_arm_benchmark
          set_arm_margin
        end
        if params[:loan_type] !="ARM"
          set_term
        end
      end
    end

    if params[:loan_size].present?
      if params[:loan_size] == "All"
        @filter_not_nil[:loan_size] = nil
      end
    end
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
    term_programs = []
    arm_programs = []
    if (@filter_not_nil.keys & [:arm_basic, :arm_advanced, :arm_margin, :arm_benchmark, :term]).any?
        term_programs = Program.where.not(loan_type: "ARM")
        arm_programs1 = Program.where(loan_type: "ARM")
        arm_basic_programs  = []
        arm_advanced_programs = []
        arm_margin_programs = []
        arm_benchmark_programs  = []
        if (@filter_not_nil.keys.include?(:arm_basic))
          arm_basic_programs = arm_programs1.where.not(arm_basic: nil)
        end
        if (@filter_not_nil.keys.include?(:arm_advanced))
          arm_advanced_programs = arm_programs1.where.not(arm_advanced: nil)
        end
        if (@filter_not_nil.keys.include?(:arm_margin))
          arm_margin_programs = arm_programs1.where.not(arm_margin: nil)
        end
        if (@filter_not_nil.keys.include?(:arm_benchmark))
          arm_benchmark_programs = arm_programs1.where.not(arm_benchmark: nil)
        end
      arm_programs = (arm_basic_programs + arm_advanced_programs + arm_margin_programs + arm_benchmark_programs).uniq
    else
      if (@filter_not_nil.keys.include?(:term))
        term_programs = Program.where.not(loan_type: "ARM")
      else
        if (@filter_not_nil.keys.include?(:arm_basic || :arm_advanced || :arm_margin || :arm_benchmark))
          arm_programs = Program.where(loan_type: "ARM")
        else
          term_programs = Program.where.not(loan_type: "ARM")
          arm_programs = Program.where(loan_type: "ARM")
        end
      end
    end

    if (@filter_data.keys & [:term] & [:arm_basic, :arm_advanced, :arm_margin, :arm_benchmark, :term]).any?
        term_programs1 = Program.where(@filter_data.except(:arm_basic, :arm_advanced, :arm_benchmark, :arm_margin, :term))
        term_programs = find_programs_on_term_based(term_programs1, @filter_data[:term])
        arm_programs = Program.where(@filter_data.except(:term))
    else
      if (@filter_data.keys & [:term]).any?
        term_programs1 = Program.where(@filter_data.except(:arm_basic, :arm_advanced, :arm_benchmark, :arm_margin, :term))
        term_programs = find_programs_on_term_based(term_programs1, @filter_data[:term])
      else
        if (@filter_data.keys & [:arm_basic, :arm_advanced, :arm_margin, :arm_benchmark]).any?
          arm_programs = Program.where(@filter_data.except(:term))
        end
      end
    end
    if arm_programs.present?
      arm_ids = arm_programs.pluck(:id)
      arm_programs = Program.where(id: arm_ids).where(@filter_data.except(:term))
    end
    if term_programs.present?
      term_ids = term_programs.pluck(:id)
      term_programs = Program.where(id: term_ids).where(@filter_data.except(:arm_basic, :arm_advanced, :arm_benchmark, :arm_margin, :term))
    end
    
    total_searched_program1 = calculate_base_rate_of_selected_programs((term_programs + arm_programs).uniq)
      total_searched_program = []

      if total_searched_program1.present?
        if params[:loan_size].present?
          if params[:loan_size] == "All"
            total_searched_program = total_searched_program1
          else
            @loan_size = params[:loan_size]
            total_searched_program1 = total_searched_program1.map{ |pro| pro if pro.loan_size!=nil}.compact
            total_searched_program1.each do |pro|
              if(pro.loan_size.split("&").map{ |l| l.strip }.include?(params[:loan_size]))
                total_searched_program << pro
              end
            end
          end
        else
          total_searched_program = total_searched_program1
        end
      end

    @result= []
    if total_searched_program.present?
      @result = find_adjustments_by_searched_programs(total_searched_program, @lock_period, @arm_basic, @arm_advanced, @fannie_mae_product, @freddie_mac_product, @loan_purpose, @program_category, @property_type, @financing_type, @premium_type, @refinance_option, @misc_adjuster, @state, @loan_type, @loan_size, @result, @interest, @loan_amount, @ltv, @cltv, @term, @credit_score, @dti )
    end
  end

  def search_programs_with_selected_loan_type
    @program_list = Program.where(@filter_data.except(:term))
    @program_list = @program_list.where.not(@filter_not_nil)
    @program_list2 = []
    if @program_list.present?
      if @program_term.present?
        @program_list = @program_list.where.not(term:nil)
        @program_list2 = find_programs_on_term_based(@program_list, @program_term)
      else
        @program_list2 = @program_list
      end

      if @program_list2.present?
        @program_list3 = []
        if params[:loan_size].present?
          if params[:loan_size] == "All"
            @program_list3 = @program_list2
          else
            @loan_size = params[:loan_size]
            @program_list2 = @program_list2.map{ |pro| pro if pro.loan_size!=nil}.compact
            @program_list2.each do |pro|
              if(pro.loan_size.split("and").map{ |l| l.strip }.include?(params[:loan_size]))
                @program_list3 << pro
              end
            end
          end
        else
          @program_list3 = @program_list2
        end
      end

      @programs =[]
      if @program_list3.present?
        @programs = calculate_base_rate_of_selected_programs(@program_list3)
      end
      @result= []
      if @programs.present?
        @result = find_adjustments_by_searched_programs(@programs, @lock_period, @arm_basic, @arm_advanced, @fannie_mae_product, @freddie_mac_product, @loan_purpose, @program_category, @property_type, @financing_type, @premium_type, @refinance_option, @misc_adjuster, @state, @loan_type, @loan_size, @result, @interest, @loan_amount, @ltv, @cltv, @term, @credit_score, @dti )
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
  def find_adjustments_by_searched_programs(programs, value_lock_period, value_arm_basic, value_arm_advanced, value_fannie_mae_product, value_freddie_mac_product, value_loan_purpose, value_program_category, value_property_type, value_financing_type, value_premium_type, value_refinance_option, value_misc_adjuster, value_state, value_loan_type, value_loan_size, value_result, value_interest, value_loan_amount, value_ltv, value_cltv, value_term, value_credit_score, value_dti)
    hash_obj = {
      :bank_name => "",
      :loan_category => "",
      :program_category => "",
      :program_name => "",
      :base_rate => 0.0,
      :adj_points => [],
      :adj_primary_key => [],
      :final_rate => []
    }
    programs.each do |pro|
      hash_obj[:bank_name] = pro.bank_name.present? ? pro.bank_name : ""
      hash_obj[:loan_category] = pro.loan_category.present? ? pro.loan_category : ""
      hash_obj[:program_category] = pro.program_category.present? ? pro.program_category : ""
      hash_obj[:program_name] = pro.program_name.present? ? pro.program_name : ""

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
          value_loan_type = pro.loan_type
          value_arm_basic = pro.arm_basic
          value_arm_advanced = pro.arm_advanced
          value_fannie_mae_product = pro.fannie_mae_product
          value_freddie_mac_product = pro.freddie_mac_product
          value_loan_purpose = pro.loan_purpose
          value_loan_size = pro.loan_size
          pro_term = pro.term
          if (pro_term.to_s.length <=2 )
            value_term = pro_term.to_s
          else
            first = pro_term/100
            last = pro_term%100
            value_term = first.to_s+"-"+last.to_s
          end

        end
      end

      program_adjustments = pro.adjustments
      if program_adjustments.present?
        program_adjustments.each do |adj|
          first_key = adj.data.keys.first
          key_list = first_key.split("/")
          adj_key_hash = {}

          key_list.each_with_index do |key_name, key_index|
            if(Adjustment::INPUT_VALUES.include?(key_name))
              if key_index==0
                if key_name == "LockDay"
                  begin
                    if adj.data[first_key][value_lock_period].present?
                      adj_key_hash[key_index] = value_lock_period
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmBasic"
                  begin
                    if adj.data[first_key][value_arm_basic].present?
                      adj_key_hash[key_index] = value_arm_basic
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmAdvanced"
                  begin
                    if adj.data[first_key][value_arm_advanced].present?
                      adj_key_hash[key_index] = value_arm_advanced
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FannieMaeProduct"
                  begin
                    if adj.data[first_key][value_fannie_mae_product].present?
                      adj_key_hash[key_index] = value_fannie_mae_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FreddieMacProduct"
                  begin
                    if adj.data[first_key][value_freddie_mac_product].present?
                      adj_key_hash[key_index] = value_freddie_mac_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "LoanPurpose"
                  begin
                    if adj.data[first_key][value_loan_purpose].present?
                      adj_key_hash[key_index] = value_loan_purpose
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanAmount"
                  begin
                    if adj.data[first_key].present?
                      loan_amount_key2 = ''
                      loan_amount_key2 = loan_amount_key_of_adjustment(adj.data[first_key].keys, value_loan_amount)
                      if loan_amount_key2.present?
                        adj_key_hash[key_index] = loan_amount_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "ProgramCategory"
                  begin
                    if adj.data[first_key][value_program_category].present?
                      adj_key_hash[key_index] = value_program_category
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "PropertyType"
                  begin
                    if adj.data[first_key][value_property_type].present?
                      adj_key_hash[key_index] = value_property_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FinancingType"
                  begin
                    if adj.data[first_key][value_financing_type].present?
                      adj_key_hash[key_index] = value_financing_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "PremiumType"
                  begin
                    if adj.data[first_key][value_premium_type].present?
                      adj_key_hash[key_index] = value_premium_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LTV"
                  begin
                    if adj.data[first_key].present?
                      ltv_key2 = ''
                      ltv_key2 = ltv_key_of_adjustment(adj.data[first_key].keys, value_ltv)
                      if ltv_key2.present?
                        adj_key_hash[key_index] = ltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "FICO"
                  begin
                    if adj.data[first_key].present?
                      fico_key2 = ''
                      fico_key2 = fico_key_of_adjustment(adj.data[first_key].keys, value_credit_score)
                      if fico_key2.present?
                        adj_key_hash[key_index] = fico_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "RefinanceOption"
                  begin
                    if adj.data[first_key][value_refinance_option].present?
                      adj_key_hash[key_index] = value_refinance_option
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "MiscAdjuster"
                  begin
                    if adj.data[first_key][value_misc_adjuster].present?
                      adj_key_hash[key_index] = value_misc_adjuster
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanSize"
                  begin
                    loan_size_key2 = ''
                    loan_size_key2 = loan_size_key_of_adjustment(adj.data[first_key].keys, value_loan_size)
                    if loan_size_key2.present?
                      adj_key_hash[key_index] = loan_size_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "CLTV"
                  begin
                    if adj.data[first_key].present?
                      ltv_key2 = ''
                      cltv_key2 = cltv_key_of_adjustment(adj.data[first_key].keys, value_cltv)
                      if cltv_key2.present?
                        adj_key_hash[key_index] = cltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "State"
                  begin
                    if value_state == "All"
                      first_state_key = adj.data[first_key].keys.first
                      if adj.data[first_key][first_state_key].present?
                        adj_key_hash[key_index] = first_state_key
                      else
                        break
                      end
                    else
                      if adj.data[first_key][value_state].present?
                        adj_key_hash[key_index] = value_state
                      else
                        break
                      end
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanType"
                  begin
                    if adj.data[first_key][value_loan_type].present?
                      adj_key_hash[key_index] = value_loan_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "Term"
                  begin
                    term_key2 = ''
                    term_key2 = term_key_of_adjustment(adj.data[first_key].keys, value_term)
                    if term_key2.present?
                      adj_key_hash[key_index] = term_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "DTI"
                  begin
                    dti_key2 = ''
                    dti_key2 = dti_key_of_adjustment(adj.data[first_key].keys, value_dti)
                    if dti_key2.present?
                      adj_key_hash[key_index] = dti_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

              end
              if key_index==1
                if key_name == "LockDay"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_lock_period].present?
                      adj_key_hash[key_index] = value_lock_period
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmBasic"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_arm_basic].present?
                      adj_key_hash[key_index] = value_arm_basic
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmAdvanced"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_arm_advanced].present?
                      adj_key_hash[key_index] = value_arm_advanced
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FannieMaeProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_fannie_mae_product].present?
                      adj_key_hash[key_index] = value_fannie_mae_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FreddieMacProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_freddie_mac_product].present?
                      adj_key_hash[key_index] = value_freddie_mac_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "LoanPurpose"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_loan_purpose].present?
                      adj_key_hash[key_index] = value_loan_purpose
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanAmount"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]].present?
                      loan_amount_key2 = ''
                      loan_amount_key2 = loan_amount_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-1]].keys, value_loan_amount)
                      if loan_amount_key2.present?
                        adj_key_hash[key_index] = loan_amount_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "ProgramCategory"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_program_category].present?
                      adj_key_hash[key_index] = value_program_category
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "PropertyType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_property_type].present?
                      adj_key_hash[key_index] = value_property_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FinancingType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_financing_type].present?
                      adj_key_hash[key_index] = value_financing_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "PremiumType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_premium_type].present?
                      adj_key_hash[key_index] = value_premium_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]].present?
                      ltv_key2 = ''
                      ltv_key2 = ltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-1]].keys, value_ltv)

                      if ltv_key2.present?
                        adj_key_hash[key_index] = ltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "FICO"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]].present?
                      fico_key2 = ''
                      fico_key2 = fico_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-1]].keys, value_credit_score)
                      if fico_key2.present?
                        adj_key_hash[key_index] = fico_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "RefinanceOption"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_refinance_option].present?
                      adj_key_hash[key_index] = value_refinance_option
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "MiscAdjuster"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_misc_adjuster].present?
                      adj_key_hash[key_index] = value_misc_adjuster
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanSize"
                  begin
                    loan_size_key2 = ''
                    loan_size_key2 = loan_size_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-1]].keys, value_loan_size)
                    if loan_size_key2.present?
                      adj_key_hash[key_index] = loan_size_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "CLTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]].present?
                      cltv_key2 = ''
                      cltv_key2 = cltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-1]].keys, value_cltv)
                      if cltv_key2.present?
                        adj_key_hash[key_index] = cltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "State"
                  begin
                    if value_state == "All"
                      first_state_key = adj.data[first_key][adj_key_hash[key_index-1]].keys.first
                      if adj.data[first_key][adj_key_hash[key_index-1]][first_state_key].present?
                        adj_key_hash[key_index] = first_state_key
                      else
                        break
                      end
                    else
                      if adj.data[first_key][adj_key_hash[key_index-1]][value_state].present?
                        adj_key_hash[key_index] = value_state
                      else
                        break
                      end
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-1]][value_loan_type].present?
                      adj_key_hash[key_index] = value_loan_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "Term"
                  begin
                    term_key2 = ''
                    term_key2 = term_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-1]].keys, value_term)
                    if term_key2.present?
                      adj_key_hash[key_index] = term_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "DTI"
                  begin
                    dti_key2 = ''
                    dti_key2 = dti_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-1]].keys, value_dti)
                    if dti_key2.present?
                      adj_key_hash[key_index] = dti_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

              end

              if key_index==2
                if key_name == "LockDay"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_lock_period].present?
                      adj_key_hash[key_index] = value_lock_period
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmBasic"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_arm_basic].present?
                      adj_key_hash[key_index] = value_arm_basic
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmAdvanced"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_arm_advanced].present?
                      adj_key_hash[key_index] = value_arm_advanced
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FannieMaeProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_fannie_mae_product].present?
                      adj_key_hash[key_index] = value_fannie_mae_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FreddieMacProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_freddie_mac_product].present?
                      adj_key_hash[key_index] = value_freddie_mac_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "LoanPurpose"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_loan_purpose].present?
                      adj_key_hash[key_index] = value_loan_purpose
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanAmount"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      loan_amount_key2 = ''
                      loan_amount_key2 = loan_amount_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_loan_amount)
                      if loan_amount_key2.present?
                        adj_key_hash[key_index] = loan_amount_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "ProgramCategory"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_program_category].present?
                      adj_key_hash[key_index] = value_program_category
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "PropertyType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_property_type].present?
                      adj_key_hash[key_index] = value_property_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FinancingType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_financing_type].present?
                      adj_key_hash[key_index] = value_financing_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "PremiumType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_premium_type].present?
                      adj_key_hash[key_index] = value_premium_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      ltv_key2 = ''
                      ltv_key2 = ltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_ltv)

                      if ltv_key2.present?
                        adj_key_hash[key_index] = ltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "FICO"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      fico_key2 = ''
                      fico_key2 = fico_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_credit_score)
                      if fico_key2.present?
                        adj_key_hash[key_index] = fico_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "RefinanceOption"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_refinance_option].present?
                      adj_key_hash[key_index] = value_refinance_option
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "MiscAdjuster"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_misc_adjuster].present?
                      adj_key_hash[key_index] = value_misc_adjuster
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "LoanSize"
                  begin
                    loan_size_key2 = ''
                    loan_size_key2 = loan_size_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_loan_size)
                    if loan_size_key2.present?
                      adj_key_hash[key_index] = loan_size_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "CLTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      cltv_key2 = ''
                      cltv_key2 = cltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_cltv)
                      if cltv_key2.present?
                        adj_key_hash[key_index] = cltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "State"
                  begin
                    if value_state == "All"
                      first_state_key = adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys.first
                      if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][first_state_key].present?
                        adj_key_hash[key_index] = first_state_key
                      else
                        break
                      end
                    else
                      if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_state].present?
                        adj_key_hash[key_index] = value_state
                      else
                        break
                      end
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_loan_type].present?
                      adj_key_hash[key_index] = value_loan_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "Term"
                  begin
                    term_key2 = ''
                    term_key2 = term_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_term)
                    if term_key2.present?
                      adj_key_hash[key_index] = term_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "DTI"
                  begin
                    dti_key2 = ''
                    dti_key2 = dti_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_dti)
                    if dti_key2.present?
                      adj_key_hash[key_index] = dti_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

              end
              if key_index==3
                if key_name == "LockDay"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_lock_period].present?
                      adj_key_hash[key_index] = value_lock_period
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmBasic"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_arm_basic].present?
                      adj_key_hash[key_index] = value_arm_basic
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmAdvanced"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_arm_advanced].present?
                      adj_key_hash[key_index] = value_arm_advanced
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FannieMaeProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_fannie_mae_product].present?
                      adj_key_hash[key_index] = value_fannie_mae_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FreddieMacProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_freddie_mac_product].present?
                      adj_key_hash[key_index] = value_freddie_mac_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "LoanPurpose"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_loan_purpose].present?
                      adj_key_hash[key_index] = value_loan_purpose
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanAmount"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      loan_amount_key2 = ''
                      loan_amount_key2 = loan_amount_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_loan_amount)

                      if loan_amount_key2.present?
                        adj_key_hash[key_index] = loan_amount_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "ProgramCategory"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_program_category].present?
                      adj_key_hash[key_index] = value_program_category
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "PropertyType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_property_type].present?
                      adj_key_hash[key_index] = value_property_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FinancingType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_financing_type].present?
                      adj_key_hash[key_index] = value_financing_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "PremiumType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_premium_type].present?
                      adj_key_hash[key_index] = value_premium_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      ltv_key2 = ''
                      ltv_key2 = ltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_ltv)

                      if ltv_key2.present?
                        adj_key_hash[key_index] = ltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "FICO"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      fico_key2 = ''
                      fico_key2 = fico_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_credit_score)
                      if fico_key2.present?
                        adj_key_hash[key_index] = fico_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "RefinanceOption"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_refinance_option].present?
                      adj_key_hash[key_index] = value_refinance_option
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "MiscAdjuster"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_misc_adjuster].present?
                      adj_key_hash[key_index] = value_misc_adjuster
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "LoanSize"
                  begin
                    loan_size_key2 = ''
                    loan_size_key2 = loan_size_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_loan_size)
                    if loan_size_key2.present?
                      adj_key_hash[key_index] = loan_size_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "CLTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      cltv_key2 = ''
                      cltv_key2 = cltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_cltv)
                      if cltv_key2.present?
                        adj_key_hash[key_index] = cltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "State"
                  begin
                    if value_state == "All"
                      first_state_key = adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys.first
                      if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][first_state_key].present?
                        adj_key_hash[key_index] = first_state_key
                      else
                        break
                      end
                    else
                      if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_state].present?
                        adj_key_hash[key_index] = value_state
                      else
                        break
                      end
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_loan_type].present?
                      adj_key_hash[key_index] = value_loan_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "Term"
                  begin
                    term_key2 = ''
                    term_key2 = term_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_term)
                    if term_key2.present?
                      adj_key_hash[key_index] = term_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "DTI"
                  begin
                    dti_key2 = ''
                    dti_key2 = dti_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_dti)
                    if dti_key2.present?
                      adj_key_hash[key_index] = dti_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

              end
              if key_index==4
                if key_name == "LockDay"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_lock_period].present?
                      adj_key_hash[key_index] = value_lock_period
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmBasic"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_arm_basic].present?
                      adj_key_hash[key_index] = value_arm_basic
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmAdvanced"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_arm_advanced].present?
                      adj_key_hash[key_index] = value_arm_advanced
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FannieMaeProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_fannie_mae_product].present?
                      adj_key_hash[key_index] = value_fannie_mae_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FreddieMacProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_freddie_mac_product].present?
                      adj_key_hash[key_index] = value_freddie_mac_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "LoanPurpose"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_loan_purpose].present?
                      adj_key_hash[key_index] = value_loan_purpose
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanAmount"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      loan_amount_key2 = ''
                      loan_amount_key2 = loan_amount_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_loan_amount)

                      if loan_amount_key2.present?
                        adj_key_hash[key_index] = loan_amount_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "ProgramCategory"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_program_category].present?
                      adj_key_hash[key_index] = value_program_category
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "PropertyType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_property_type].present?
                      adj_key_hash[key_index] = value_property_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FinancingType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_financing_type].present?
                      adj_key_hash[key_index] = value_financing_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "PremiumType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_premium_type].present?
                      adj_key_hash[key_index] = value_premium_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      ltv_key2 = ''
                      ltv_key2 = ltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_ltv)

                      if ltv_key2.present?
                        adj_key_hash[key_index] = ltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "FICO"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      fico_key2 = ''
                      fico_key2 = fico_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_credit_score)
                      if fico_key2.present?
                        adj_key_hash[key_index] = fico_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "RefinanceOption"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_refinance_option].present?
                      adj_key_hash[key_index] = value_refinance_option
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "MiscAdjuster"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_misc_adjuster].present?
                      adj_key_hash[key_index] = value_misc_adjuster
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "LoanSize"
                  begin
                    loan_size_key2 = ''
                    loan_size_key2 = loan_size_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_loan_size)
                    if loan_size_key2.present?
                      adj_key_hash[key_index] = loan_size_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "CLTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      cltv_key2 = ''
                      cltv_key2 = cltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_cltv)
                      if cltv_key2.present?
                        adj_key_hash[key_index] = cltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "State"
                  begin
                    if value_state == "All"
                      first_state_key = adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys.first
                      if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][first_state_key].present?
                        adj_key_hash[key_index] = first_state_key
                      else
                        break
                      end
                    else
                      if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_state].present?
                        adj_key_hash[key_index] = value_state
                      else
                        break
                      end
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_loan_type].present?
                      adj_key_hash[key_index] = value_loan_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "Term"
                  begin
                    term_key2 = ''
                    term_key2 = term_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_term)
                    if term_key2.present?
                      adj_key_hash[key_index] = term_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "DTI"
                  begin
                    dti_key2 = ''
                    dti_key2 = dti_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_dti)
                    if dti_key2.present?
                      adj_key_hash[key_index] = dti_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

              end
              if key_index==5
                if key_name == "LockDay"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_lock_period].present?
                      adj_key_hash[key_index] = value_lock_period
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmBasic"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_arm_basic].present?
                      adj_key_hash[key_index] = value_arm_basic
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmAdvanced"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_arm_advanced].present?
                      adj_key_hash[key_index] = value_arm_advanced
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FannieMaeProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_fannie_mae_product].present?
                      adj_key_hash[key_index] = value_fannie_mae_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FreddieMacProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_freddie_mac_product].present?
                      adj_key_hash[key_index] = value_freddie_mac_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "LoanPurpose"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_loan_purpose].present?
                      adj_key_hash[key_index] = value_loan_purpose
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanAmount"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      loan_amount_key2 = ''
                      loan_amount_key2 = loan_amount_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_loan_amount)

                      if loan_amount_key2.present?
                        adj_key_hash[key_index] = loan_amount_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "ProgramCategory"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_program_category].present?
                      adj_key_hash[key_index] = value_program_category
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "PropertyType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_property_type].present?
                      adj_key_hash[key_index] = value_property_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FinancingType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_financing_type].present?
                      adj_key_hash[key_index] = value_financing_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "PremiumType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_premium_type].present?
                      adj_key_hash[key_index] = value_premium_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      ltv_key2 = ''
                      ltv_key2 = ltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_ltv)

                      if ltv_key2.present?
                        adj_key_hash[key_index] = ltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "FICO"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      fico_key2 = ''
                      fico_key2 = fico_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_credit_score)
                      if fico_key2.present?
                        adj_key_hash[key_index] = fico_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "RefinanceOption"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_refinance_option].present?
                      adj_key_hash[key_index] = value_refinance_option
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "MiscAdjuster"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_misc_adjuster].present?
                      adj_key_hash[key_index] = value_misc_adjuster
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "LoanSize"
                  begin
                    loan_size_key2 = ''
                    loan_size_key2 = loan_size_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_loan_size)
                    if loan_size_key2.present?
                      adj_key_hash[key_index] = loan_size_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "CLTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      cltv_key2 = ''
                      cltv_key2 = cltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_cltv)
                      if cltv_key2.present?
                        adj_key_hash[key_index] = cltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "State"
                  begin
                    if value_state == "All"
                      first_state_key = adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys.first
                      if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][first_state_key].present?
                        adj_key_hash[key_index] = first_state_key
                      else
                        break
                      end
                    else
                      if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_state].present?
                        adj_key_hash[key_index] = value_state
                      else
                        break
                      end
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_loan_type].present?
                      adj_key_hash[key_index] = value_loan_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "Term"
                  begin
                    term_key2 = ''
                    term_key2 = term_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_term)
                    if term_key2.present?
                      adj_key_hash[key_index] = term_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "DTI"
                  begin
                    dti_key2 = ''
                    dti_key2 = dti_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_dti)
                    if dti_key2.present?
                      adj_key_hash[key_index] = dti_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

              end
              if key_index==6
                if key_name == "LockDay"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_lock_period].present?
                      adj_key_hash[key_index] = value_lock_period
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmBasic"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_arm_basic].present?
                      adj_key_hash[key_index] = value_arm_basic
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "ArmAdvanced"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_arm_advanced].present?
                      adj_key_hash[key_index] = value_arm_advanced
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FannieMaeProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_fannie_mae_product].present?
                      adj_key_hash[key_index] = value_fannie_mae_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FreddieMacProduct"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_freddie_mac_product].present?
                      adj_key_hash[key_index] = value_freddie_mac_product
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "LoanPurpose"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_loan_purpose].present?
                      adj_key_hash[key_index] = value_loan_purpose
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanAmount"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      loan_amount_key2 = ''
                      loan_amount_key2 = loan_amount_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_loan_amount)

                      if loan_amount_key2.present?
                        adj_key_hash[key_index] = loan_amount_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "ProgramCategory"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_program_category].present?
                      adj_key_hash[key_index] = value_program_category
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "PropertyType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_property_type].present?
                      adj_key_hash[key_index] = value_property_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "FinancingType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_financing_type].present?
                      adj_key_hash[key_index] = value_financing_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end
                if key_name == "PremiumType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_premium_type].present?
                      adj_key_hash[key_index] = value_premium_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      ltv_key2 = ''
                      ltv_key2 = ltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_ltv)

                      if ltv_key2.present?
                        adj_key_hash[key_index] = ltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "FICO"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      fico_key2 = ''
                      fico_key2 = fico_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_credit_score)
                      if fico_key2.present?
                        adj_key_hash[key_index] = fico_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "RefinanceOption"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_refinance_option].present?
                      adj_key_hash[key_index] = value_refinance_option
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "MiscAdjuster"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_misc_adjuster].present?
                      adj_key_hash[key_index] = value_misc_adjuster
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanSize"
                  begin
                    loan_size_key2 = ''
                    loan_size_key2 = loan_size_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_loan_size)
                    if loan_size_key2.present?
                      adj_key_hash[key_index] = loan_size_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "CLTV"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].present?
                      cltv_key2 = ''
                      cltv_key2 = cltv_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_cltv)
                      if cltv_key2.present?
                        adj_key_hash[key_index] = cltv_key2
                      else
                        break
                      end
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "State"
                  begin
                    if value_state == "All"
                      first_state_key = adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys.first
                      if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][first_state_key].present?
                        adj_key_hash[key_index] = first_state_key
                      else
                        break
                      end
                    else
                      if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_state].present?
                        adj_key_hash[key_index] = value_state
                      else
                        break
                      end
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "LoanType"
                  begin
                    if adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]][value_loan_type].present?
                      adj_key_hash[key_index] = value_loan_type
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "Term"
                  begin
                    term_key2 = ''
                    term_key2 = term_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_term)
                    if term_key2.present?
                      adj_key_hash[key_index] = term_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

                if key_name == "DTI"
                  begin
                    dti_key2 = ''
                    dti_key2 = dti_key_of_adjustment(adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]].keys, value_dti)
                    if dti_key2.present?
                      adj_key_hash[key_index] = dti_key2
                    else
                      break
                    end
                  rescue Exception
                    puts "Adjustment Error: Adjustment Id: #{adj.id}, Adjustment Primary Key: #{first_key}, Key Name: #{key_name}, Loan Category: #{adj.loan_category}"
                  end
                end

              end
            else
              if key_index==0
                if (key_name == "HighBalance" || key_name == "Conforming" || key_name == "FannieMae" || key_name == "FannieMaeHomeReady" || key_name == "FreddieMac" || key_name == "FreddieMacHomePossible" || key_name == "FHA" || key_name == "VA" || key_name == "USDA" || key_name == "StreamLine" || key_name == "FullDoc" || key_name == "Jumbo" || key_name == "FHLMC" || key_name == "LPMI" || key_name == "EPMI" || key_name == "FNMA")
                  adj.data[first_key]["true"]
                  adj_key_hash[key_index] = "true"
                end
              end
              if key_index==1
                if (key_name == "HighBalance" || key_name == "Conforming" || key_name == "FannieMae" || key_name == "FannieMaeHomeReady" || key_name == "FreddieMac" || key_name == "FreddieMacHomePossible" || key_name == "FHA" || key_name == "VA" || key_name == "USDA" || key_name == "StreamLine" || key_name == "FullDoc" || key_name == "Jumbo" || key_name == "FHLMC" || key_name == "LPMI" || key_name == "EPMI" || key_name == "FNMA")
                  adj.data[first_key][adj_key_hash[key_index-1]]["true"]
                  adj_key_hash[key_index] = "true"
                end
              end
              if key_index==2
                if (key_name == "HighBalance" || key_name == "Conforming" || key_name == "FannieMae" || key_name == "FannieMaeHomeReady" || key_name == "FreddieMac" || key_name == "FreddieMacHomePossible" || key_name == "FHA" || key_name == "VA" || key_name == "USDA" || key_name == "StreamLine" || key_name == "FullDoc" || key_name == "Jumbo" || key_name == "FHLMC" || key_name == "LPMI" || key_name == "EPMI" || key_name == "FNMA")
                  adj.data[first_key][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]]["true"]
                  adj_key_hash[key_index] = "true"
                end
              end
              if key_index==3
                if (key_name == "HighBalance" || key_name == "Conforming" || key_name == "FannieMae" || key_name == "FannieMaeHomeReady" || key_name == "FreddieMac" || key_name == "FreddieMacHomePossible" || key_name == "FHA" || key_name == "VA" || key_name == "USDA" || key_name == "StreamLine" || key_name == "FullDoc" || key_name == "Jumbo" || key_name == "FHLMC" || key_name == "LPMI" || key_name == "EPMI" || key_name == "FNMA")
                  adj.data[first_key][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]]["true"]
                  adj_key_hash[key_index] = "true"
                end
              end
              if key_index==4
                if (key_name == "HighBalance" || key_name == "Conforming" || key_name == "FannieMae" || key_name == "FannieMaeHomeReady" || key_name == "FreddieMac" || key_name == "FreddieMacHomePossible" || key_name == "FHA" || key_name == "VA" || key_name == "USDA" || key_name == "StreamLine" || key_name == "FullDoc" || key_name == "Jumbo" || key_name == "FHLMC" || key_name == "LPMI" || key_name == "EPMI" || key_name == "FNMA")
                  adj.data[first_key][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]]["true"]
                  adj_key_hash[key_index] = "true"
                end
              end
              if key_index==5
                if (key_name == "HighBalance" || key_name == "Conforming" || key_name == "FannieMae" || key_name == "FannieMaeHomeReady" || key_name == "FreddieMac" || key_name == "FreddieMacHomePossible" || key_name == "FHA" || key_name == "VA" || key_name == "USDA" || key_name == "StreamLine" || key_name == "FullDoc" || key_name == "Jumbo" || key_name == "FHLMC" || key_name == "LPMI" || key_name == "EPMI" || key_name == "FNMA")
                  adj.data[first_key][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]]["true"]
                  adj_key_hash[key_index] = "true"
                end
              end
              if key_index==6
                if (key_name == "HighBalance" || key_name == "Conforming" || key_name == "FannieMae" || key_name == "FannieMaeHomeReady" || key_name == "FreddieMac" || key_name == "FreddieMacHomePossible" || key_name == "FHA" || key_name == "VA" || key_name == "USDA" || key_name == "StreamLine" || key_name == "FullDoc" || key_name == "Jumbo" || key_name == "FHLMC" || key_name == "LPMI" || key_name == "EPMI" || key_name == "FNMA")
                  adj.data[first_key][adj_key_hash[key_index-6]][adj_key_hash[key_index-5]][adj_key_hash[key_index-4]][adj_key_hash[key_index-3]][adj_key_hash[key_index-2]][adj_key_hash[key_index-1]]["true"]
                  adj_key_hash[key_index] = "true"
                end
              end
            end
          end
          adj_key_hash.keys.each do |hash_key, index|
            if hash_key==0 && adj_key_hash.keys.count-1==hash_key
              point = adj.data[first_key][adj_key_hash[hash_key]]
              if (((point.is_a? Float) || (point.is_a? Integer) || (point.is_a? String)) && (point != "N/A") && (point != "n/a") && (point != "NA") && (point != "na") && (point != "-"))
                hash_obj[:adj_points] << point.to_f
                hash_obj[:final_rate] << point.to_f
                hash_obj[:adj_primary_key] << adj.data.keys.first
              end
            end
            if hash_key==1 && adj_key_hash.keys.count-1==hash_key
              point = adj.data[first_key][adj_key_hash[hash_key-1]][adj_key_hash[hash_key]]
              if (((point.is_a? Float) || (point.is_a? Integer) || (point.is_a? String)) && (point != "N/A") && (point != "n/a") && (point != "NA") && (point != "na") && (point != "-"))
                hash_obj[:adj_points] << point.to_f
                hash_obj[:final_rate] << point.to_f
                hash_obj[:adj_primary_key] << adj.data.keys.first
              end
            end
            if hash_key==2 && adj_key_hash.keys.count-1==hash_key
              point = adj.data[first_key][adj_key_hash[hash_key-2]][adj_key_hash[hash_key-1]][adj_key_hash[hash_key]]
              if (((point.is_a? Float) || (point.is_a? Integer) || (point.is_a? String)) && (point != "N/A") && (point != "n/a") && (point != "NA") && (point != "na") && (point != "-"))
                hash_obj[:adj_points] << point.to_f
                hash_obj[:final_rate] << point.to_f
                hash_obj[:adj_primary_key] << adj.data.keys.first
              end
            end
            if hash_key==3 && adj_key_hash.keys.count-1==hash_key
              point = adj.data[first_key][adj_key_hash[hash_key-3]][adj_key_hash[hash_key-2]][adj_key_hash[hash_key-1]][adj_key_hash[hash_key]]
              if (((point.is_a? Float) || (point.is_a? Integer) || (point.is_a? String)) && (point != "N/A") && (point != "n/a") && (point != "NA") && (point != "na") && (point != "-"))
                hash_obj[:adj_points] << point.to_f
                hash_obj[:final_rate] << point.to_f
                hash_obj[:adj_primary_key] << adj.data.keys.first
              end
            end
            if hash_key==4 && adj_key_hash.keys.count-1==hash_key
              point = adj.data[first_key][adj_key_hash[hash_key-4]][adj_key_hash[hash_key-3]][adj_key_hash[hash_key-2]][adj_key_hash[hash_key-1]][adj_key_hash[hash_key]]
              if (((point.is_a? Float) || (point.is_a? Integer) || (point.is_a? String)) && (point != "N/A") && (point != "n/a") && (point != "NA") && (point != "na") && (point != "-"))
                hash_obj[:adj_points] << point.to_f
                hash_obj[:final_rate] << point.to_f
                hash_obj[:adj_primary_key] << adj.data.keys.first
              end
            end
            if hash_key==5 && adj_key_hash.keys.count-1==hash_key
              point = adj.data[first_key][adj_key_hash[hash_key-5]][adj_key_hash[hash_key-4]][adj_key_hash[hash_key-3]][adj_key_hash[hash_key-2]][adj_key_hash[hash_key-1]][adj_key_hash[hash_key]]
              if (((point.is_a? Float) || (point.is_a? Integer) || (point.is_a? String)) && (point != "N/A") && (point != "n/a") && (point != "NA") && (point != "na") && (point != "-"))
                hash_obj[:adj_points] << point.to_f
                hash_obj[:final_rate] << point.to_f
                hash_obj[:adj_primary_key] << adj.data.keys.first
              end
            end
            if hash_key==6 && adj_key_hash.keys.count-1==hash_key
              point = adj.data[first_key][adj_key_hash[hash_key-6]][adj_key_hash[hash_key-5]][adj_key_hash[hash_key-4]][adj_key_hash[hash_key-3]][adj_key_hash[hash_key-2]][adj_key_hash[hash_key-1]][adj_key_hash[hash_key]]
              if (((point.is_a? Float) || (point.is_a? Integer) || (point.is_a? String)) && (point != "N/A") && (point != "n/a") && (point != "NA") && (point != "na") && (point != "-"))
                hash_obj[:adj_points] << point.to_f
                hash_obj[:final_rate] << point.to_f
                hash_obj[:adj_primary_key] << adj.data.keys.first
              end
            end
          end
        end
      else
        hash_obj[:adj_points] = "Adjustment Not Present"
        hash_obj[:adj_primary_key] = "Adjustment Not Present"
      end
      if hash_obj[:adj_points].present?
        # hash_obj[:final_rate] << value_interest.to_f
        hash_obj[:final_rate] << (hash_obj[:base_rate].to_f < 50.0 ? hash_obj[:base_rate].to_f : (100 - hash_obj[:base_rate].to_f))
        value_result << hash_obj
      else
        # hash_obj[:final_rate] << value_interest.to_f
        hash_obj[:final_rate] << (hash_obj[:base_rate].to_f < 50.0 ? hash_obj[:base_rate].to_f : (100 - hash_obj[:base_rate].to_f))
        value_result << hash_obj
      end

      hash_obj = {
      :bank_name => "",
      :loan_category => "",
      :program_category => "",
      :program_name => "",
      :base_rate => 0.0,
      :adj_points => [],
      :adj_primary_key => [],
      :final_rate => []
    }

    end
    return value_result
  end

  def loan_size_key_of_adjustment(loan_size_keys, value_loan_size)
    loan_size_key2 = ''
    if (loan_size_keys & value_loan_size.split("&")).present?
      loan_size_key2 = (value_loan_size.split("&") & loan_size_keys).first
    end
    return loan_size_key2
  end

  def loan_amount_key_of_adjustment(loan_amount_keys, value_loan_amount)
    loan_amount_key2 = ''
    if value_loan_amount.include?("-")
      first_range = value_loan_amount.split("-").first.strip.to_i
      last_range = value_loan_amount.split("-").last.strip.to_i
      if loan_amount_keys.present?
        loan_amount_keys.each do |loan_amount_key|
          if loan_amount_key.include?("$")
            loan_amount_key = loan_amount_key.tr('$', '').strip
          end
          if loan_amount_key.include?(",")
            loan_amount_key = loan_amount_key.tr(',', '').strip
          end
          if (loan_amount_key.include?("Inf") || loan_amount_key.include?("Infinity"))
            loan_amount_value = loan_amount_key.split("-").first.strip.to_i
            if (loan_amount_value <= first_range)
                loan_amount_key2 = loan_amount_key
            end
          else
            if loan_amount_key.include?("-")
                first_value_range = loan_amount_key.split("-").first.strip.to_i
                last_value_range = loan_amount_key.split("-").last.strip.to_i
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
          if loan_amount_key.include?("$")
            loan_amount_key = loan_amount_key.tr('$', '').strip
          end
          if loan_amount_key.include?(",")
            loan_amount_key = loan_amount_key.tr(',', '').strip
          end
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
    ltv_key2 = ''
    ltv_keys.each do |ltv_key|
      if (ltv_key.include?("Any") || ltv_key.include?("All"))
        ltv_key2 = ltv_key
      end
      if ltv_key.include?("-")
        ltv_key_range =[]
        if ltv_key.include?("Inf") || ltv_key.include?("Infinity")
          first_range = ltv_key.split("-").first.strip.to_f
          if params[:ltv].include?("+")
              ltv_key2 = ltv_key
          else
            if first_range <= value_ltv.last
              ltv_key2 = ltv_key
            end
          end
        else
          first_range = ltv_key.split("-").first.strip.to_f
          last_range =  ltv_key.split("-").last.strip.to_f
          if params[:ltv].include?("+")
            full_range = params[:ltv].split("+").first.strip.to_f
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
    cltv_key2 = ''
    cltv_keys.each do |cltv_key|
      if (cltv_key.include?("Any") || cltv_key.include?("All"))
        cltv_key2 = cltv_key
      end
      if cltv_key.include?("-")
        cltv_key_range =[]
        if cltv_key.include?("Inf") || cltv_key.include?("Infinity")
          first_range = cltv_key.split("-").first.strip.to_f
          if params[:cltv].include?("+")
              cltv_key2 = cltv_key
          else
            if first_range <= value_cltv.last
              cltv_key2 = cltv_key
            end
          end
        else
          first_range = cltv_key.split("-").first.strip.to_f
          last_range =  cltv_key.split("-").last.strip.to_f
          if params[:cltv].include?("+")
            full_range = params[:cltv].split("+").first.strip.to_f
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
    fico_key2 = ''
    fico_keys.each do |fico_key|
      if (fico_key.include?("Any") || fico_key.include?("All"))
        fico_key2 = fico_key
      end
      if fico_key.include?("-")
        fico_key_range =[]
        if fico_key.include?("Inf") || fico_key.include?("Infinity")
          first_range = fico_key.split("-").first.strip.to_i
          if params[:credit_score].include?("+")
              fico_key2 = fico_key
          else
            if first_range <= value_credit_score.last
              fico_key2 = fico_key
            end
          end
        else
          first_range = fico_key.split("-").first.strip.to_i
          last_range =  fico_key.split("-").last.strip.to_i
          if params[:credit_score].include?("+")
            full_range = params[:credit_score].split("+").first.strip.to_i
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
    dti_key_2 = ''
    dti_keys.each do |dti_key|
      if dti_key == value_dti
        dti_key_2 = dti_key
      end
    end
    return dti_key_2
  end

end
