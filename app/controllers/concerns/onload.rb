module Onload
  extend ActiveSupport::Concern

  def set_default
    @source = params[:source].present? ? params[:source].to_i : 0  # 0: Main page. 1: Internal search
    #@banks = Bank.all
    @base_rate = 0.0
    @filter_data = {}
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
    @refinance_option = "Cash Out"
    @misc_adjuster = "CA Escrow Waiver (Full or Taxes Only)"
    @state = "All"
    @result = []
    @loan_amount = "0 - 50000"
    @set_ltv = params[:ltv].present? ? params[:ltv] : "65.01 - 70.00"
    @set_credit_score = params[:credit_score].present? ? params[:credit_score] : "700-719"
    @dti = "25.6%"
    @loan_purpose = "Purchase"
    @home_price = "300000"
    @down_payment = "50000"
    @coverage = "30.5%"
    @margin = "2.0"
    @ltv = (6500..7000).to_a.map{|e| e.to_f/100}
    @cltv = (7501..8000).to_a.map{|e| e.to_f/100}
    @credit_score = (700..719).to_a

    @programs_all = load_programs_all

    if @source == 1
      @banks = Bank.all   
      @all_banks_name = @banks.pluck(:name)
      @arm_advanced_list = @programs_all.pluck(:arm_advanced).push("5-5").compact.uniq.reject(&:empty?).map{|c| [c]}
      @arm_caps_list = @programs_all.pluck(:arm_caps).push("3-2-5").compact.uniq.reject(&:empty?).map{|c| [c]}
      @term_list = @programs_all.where('term <= ?', 999).pluck(:term).compact.uniq.push(5,10,15,20,25,30).uniq.sort.map{|y| [y.to_s + " yrs" , y]}.prepend(["All"])
    end

    @default_property_tax_perc = 0.86
    @default_annual_home_insurance = 974
    @default_pmi_insurance = 100.00
  end

  def api_search
    @time = Benchmark.measure {
      if params["commit"].present?
        set_variable
      end
      search_programs
    }
    puts "Query Time  #{@time.real}"
  end
end
