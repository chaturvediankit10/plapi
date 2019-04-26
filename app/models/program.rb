class Program < ApplicationRecord
  belongs_to :bank, optional: true
  belongs_to :sheet, optional: true
  has_many :program_adjustments
  has_many :adjustments, through: :program_adjustments
  belongs_to :sub_sheet, optional: true
  before_save :add_bank_name
  # after_save :add_default_loan_size

  STATE = [["All"], ["AK"], ["AL"], ["AR"], ["AS"], ["AZ"], ["CA"], ["CO"], ["CT"], ["DC"], ["DE"], ["FL"], ["FM"], ["GA"], ["GU"], ["HI"], ["IA"], ["ID"], ["IL"], ["IN"], ["KS"], ["KY"], ["LA"], ["MA"], ["MD"], ["ME"], ["MH"], ["MI"], ["MN"], ["MO"], ["MP"], ["MS"], ["MT"], ["NC"], ["ND"], ["NE"], ["NH"], ["NJ"], ["NM"], ["NV"], ["NY"], ["OH"], ["OK"], ["OR"], ["PA"], ["PR"], ["PW"], ["RI"], ["SC"], ["SD"], ["TN"], ["TX"], ["UT"], ["VA"], ["VI"], ["VT"], ["WA"], ["WI"], ["WV"], ["WY"]]

  LOAN_TYPE = [["All"], ["Fixed"], ["ARM"], ["Hybrid"], ["Floating"], ["Variable"]]

  LOAN_AMOUNT = [["$0 - $50,000", "0 - 50000"], ["$50,000 - $100,000", "50000 - 100000"], ["$100,000 - $150,000", "100000 - 150000"], ["$150,000 - $200,000", "150000 - 200000"], ["$200,000 - $250,000", "200000 - 250000"], ["$250,000 - $300,000", "250000 - 300000"], ["$300,000 - $350,000", "300000 - 350000"], ["$350,000 - $400,000", "350000 - 400000"], ["$400,000 - $450,000", "400000 - 450000"], ["$450,000 - $500,000", "450000 - 500000"], ["$500,000 - $550,000", "500000 - 550000"], ["$550,000 - $600,000", "550000 - 600000"], ["$600,000 - $650,000", "600000 - 650000"], ["$650,000 - $700,000", "650000 - 700000"], ["$700,000 - $750,000", "700000 - 750000"], ["$750,000 - $800,000", "750000 - 800000"], ["$800,000 - $850,000", "800000 - 850000"], ["$850,000 +", "850000 +"]]

  LOAN_PURPOSE = [["All"], ["Purchase"], ["Refinance"]]

  LOAN_SIZE = [["All"], ["Conforming"], ["Non-Conforming"], ["Super Conforming"], ["Jumbo"], ["High-Balance"], ["High-Balance Extra"]]

  ARM_BASIC = [["All"], ["1/1"],["2/1"],["3/1"],["5/1"], ["7/1"],["10/1"]]

  ARM_BENCHMARK_LIST = [["All"], ["LIBOR"], ["CMT"]]

  ARM_MARGIN_LIST = [["All"], ["0.00"], ["2.20"], ["2.25"]]

  INTEREST_LIST =[["2.275"],["2.500"],["2.625"],["2.750"],["2.875"],["3.000"],["3.125"], ["3.250"],["3.375"],["3.500"],["3.625"],["3.750"],["3.875"],["4.000"],["4.125"],["4.250"],["4.375"],["4.500"],["4.625"],["4.750"],["4.875"],["5.000"],["5.125"],["5.250"],["5.375"],["5.500"],["5.625"],["5.750"],["5.875"], ["6.000"]]

  LOCK_PERIOD_LIST =[["15 days","15"], ["30 days","30"], ["45 days","45"], ["60 days","60"], ["75 days","75"], ["90 days","90"]]

  FANNIE_MAE_PRODUCT_LIST =[["HomeReady"]]

  FREDDIE_MAC_PRODUCT_LIST =[["Home Possible"]]

  CREDIT_SCORE_LIST = [["760 +", "760 +"], ["740-759", "740-759"], ["720-739", "720-739"], ["700-719", "700-719"], ["680-699", "680-699"], ["660-679", "660-679"], ["640-659", "640-659"], ["620-639", "620-639"], ["0-619", "0-619"]]

  LTV_VALUES = [["97 +"], ["95.01 - 97.00"], ["90.01 - 95.00"], ["85.01 - 90.00"], ["80.01 - 85.00"], ["75.01 - 80.00"], ["70.01 - 75.00"], ["65.01 - 70.00"], ["60.01 - 65.00"], ["0.00 - 60.00"]]

  CLTV_VALUES = [["97 +"], ["95.01 - 97.00"], ["90.01 - 95.00"], ["85.01 - 90.00"], ["80.01 - 85.00"], ["75.01 - 80.00"], ["70.01 - 75.00"], ["65.01 - 70.00"], ["60.01 - 65.00"], ["0.00 - 60.00"]]

  PROGRAM_CATEGORY_LIST =[["7900"], ["6900"]]

  PROPERTY_TYPE_VALUES = [["Manufactured Home"],["2nd Home"],["3-4 Unit"],["Non-Owner Occupied"],["Condo"],["1 Unit"], ["2-Unit"], ["2-4 Unit"],["Investment Property"], ["Gov'n Non Owner"], ["NOO"]]

  FINANCING_TYPE_VALUES = [["Subordinate Financing"], ["Home Possible"]]

  REFINANCE_OPTION_VALUES = [["Cash Out"], ["Rate and Term"], ["IRRRL"]]

  MISC_ADJUSTER_VALUES = [["Escrow Waiver"], ["CA Escrow Waiver (Full or Taxes Only)"], ["CA Escrow Waiver (Insurance Only)"], ["Miscellaneous"], ["Escrow Waiver Fee"], ["Escrow Waiver (LTVs >80%; CA only)"], ["Escrow Waiver (N/A for: CA, CT, ME, MT, NY, RI, SD, UT, VT, WV)"], ["Escrow Waiver - except CA"]]

  PATMENT_TYPE_VALUES = [["Principal and Interest"], ["Interest Only"]]

  DTI_VALUES = [["25.6%"]]

  COVERAGE_VALUES = [["30.5%"]]

  MARGIN_VALUES = [["2.0"]]

  def add_bank_name
    self.bank_name = self.sheet.bank.name if self.sheet.present?
    self.bank_name = self.sub_sheet.sheet.bank.name if self.sub_sheet.present?
  end

  def get_adjustments
    Adjustment.where(loan_category: self.loan_category)
  end

  def get_non_conforming
    non_conforming = ["Non-Conforming","non conforming", "NON CONFORMING", "Non-Conf"]
    # non_conforming += Acronym.new(non_conforming).to_a
    non_conforming += non_conforming.map(&:downcase)
    return non_conforming
  end

  def get_conforming
    conforming = ["Conforming","Conf", "FCF"]
    # conforming += Acronym.new(conforming).to_a
    conforming += conforming.map(&:downcase)
    return conforming
  end

  def get_super_conforming
    sup_conf = ["Super Conforming"," SC "]
    sup_conf += sup_conf.map(&:downcase)
    return sup_conf
  end

  def get_non_conf_hb
    non_conf_hb = ["Non-Conforming Jumbo"]
    non_conf_hb += non_conf_hb.map(&:downcase)
    return non_conf_hb
  end

  def get_conf
    conf = ["CONF HB","Conf High Bal", "Conforming High Balance"]
    # conforming += Acronym.new(conforming).to_a
    conf += conf.map(&:downcase)
    return conf
  end

  def get_high_balance_extra
    high_balance_extra = ["High Balance Extra"]
    high_balance_extra += high_balance_extra.map(&:downcase)
    return high_balance_extra
  end

  def get_high_balance
    high_balance = ["High-Balance", "HIGH BAL", "High Balance", "HB", "HighBalance"]
    # high_balance += Acronym.new(high_balance).to_a
    high_balance += high_balance.map(&:downcase)
    return high_balance
  end

  def get_jumbo
    jumbo = ["Jumbo"]
    jumbo += Acronym.new(jumbo).to_a
    jumbo += jumbo.map(&:downcase)
    return jumbo
  end

  def get_purchase
    lp = ["Purchase","Purch"]
    lp += lp.map(&:downcase)
    return lp
  end

  def get_refinance
    rf = ["Refinance","Refi"]
    rf += rf.map(&:downcase)
    return rf
  end

  def fetch_loan_size_fields p_name
    @loan_size = []
    @loan_size = get_non_conforming.map{|a| a if p_name.downcase.include?(a)}.compact
    unless @loan_size.present?
      @loan_size = get_super_conforming.map{|a| a if p_name.downcase.include?(a)}.compact
      unless @loan_size
        @loan_size = get_conforming
      end
    end
    @check_high_bal = get_high_balance_extra.map{|a| a if p_name.downcase.include?(a)}.compact
    
    unless @check_high_bal.nil?
      @check_high_bal1 = get_high_balance.map{|a| a if p_name.downcase.include?(a)}.compact
      @loan_size << @check_high_bal1
    end

    @check_jumbo = get_jumbo.map{|a| a if p_name.downcase.include?(a)}.compact
    if @check_jumbo.present?
      @loan_size << @check_jumbo
    end

    return @loan_size.try(:compact).try(:flatten)
    # loan_size = get_non_conforming + get_super_conforming + get_conforming + get_high_balance_extra + get_high_balance + get_jumbo + get_conf + get_non_conf_hb 
    # return loan_size
  end

  def fetch_loan_purpose_fields
    loan_purpose = get_purchase + get_refinance
    return loan_purpose
  end

  def update_fields p_name
    set_loan_size(fetch_loan_size_fields(p_name), p_name)
    set_loan_purpose(p_name)        if fetch_loan_purpose_fields.each{ |word| p_name.downcase.include?(word.downcase) }
    set_load_type(p_name)           if ["Fixed", "ARM", "Hybrid", "Floating", "Variable"].each{ |word| p_name.downcase.include?(word.downcase) }
    set_fha                         if p_name.downcase.include?("fha")
    set_du                          if p_name.downcase.include?("du ")
    set_lp                          if p_name.downcase.include?("lp ")
    set_va                          if p_name.downcase.include?("va")
    set_usda                        if p_name.downcase.include?("usda")
    set_streamline(p_name)          if ["streamline","SL"].each{ |word| p_name.downcase.include?(word.downcase) }
    set_full_doc                    if p_name.downcase.include?("full doc")
    set_libor(p_name)               if p_name.downcase.include?("arm")
    set_arm_margin(p_name)          if p_name.downcase.include?("arm")
    # set_loan_purpose(p_name)        if ["Purchase", "Refinance"].each{ |word| p_name.downcase.include?(word.downcase) }
    set_conforming(p_name)          if ["Conforming","Conf","fcf"].each{ |word| p_name.downcase.include?(word.downcase) }
    set_fannie_mae(p_name)          if ["Fannie Mae", "FNMA", "Du "].each{ |word| p_name.downcase.include?(word.downcase) }
    set_freddie_mac(p_name)         if ["Freddie Mac", "FHLMC", "Lp "].each{ |word| p_name.downcase.include?(word.downcase) }
    set_freddie_mac_product(p_name) if ["Home Possible","HOME POSSIBLE"].each{ |word| p_name.downcase.include?(word.downcase) }
    set_fannie_mae_product(p_name)  if ["HOMEREADY", "Home Ready"].each{ |word| p_name.downcase.include?(word.downcase) }
    self.save
  end

  def set_load_type(prog_name)
    present_word = nil
    ["Fixed", "ARM", "Hybrid", "Floating", "Variable" ,"FCF"].each{ |word|
      present_word = word if prog_name.downcase.include?(word.downcase)
      if present_word.present? && present_word.downcase.include?('fcf')
        present_word = "Fixed"
      end
      if present_word.nil?
        present_word = "Fixed"
      end
      if present_word == "ARM"
        self.arm_benchmark = "LIBOR"
      end
    }
    self.loan_type = present_word
  end

  def set_conforming(prog_name)
    present_word = nil
    # self.conforming = true
    ["Conforming","Conf","fcf"].map { |word|
      present_word = true if prog_name.downcase.include?(word.downcase)
    }
    self.conforming = present_word
  end

  def set_du
    self.du = true
    self.fannie_mae = true
  end

  def set_lp
    self.lp = true
    self.freddie_mac = true
  end

  def set_fha
    self.fha = true
    return
  end

  def set_va
    self.va = true
  end

  def set_usda
    self.usda = true
  end

  def set_streamline(prog_name)
    present_word = nil
    ["streamline","SL"].map { |word|
      if prog_name.downcase.include?(word.downcase)
        present_word = true 
        self.streamline = present_word
        self.fha = present_word
        self.loan_purpose = "Refinance" if present_word
      end
    }
  end

  def set_libor(prog_name)
    present_word = nil
    ["LIBOR", "CMT"].each{ |word|
      present_word = word if prog_name.downcase.include?(word.downcase)
    }
    present_word.present? ? self.arm_benchmark = present_word : self.arm_benchmark = "LIBOR"
  end

  def set_arm_margin(prog_name)
    ["2.25","2.00"].each{ |word| 
      if prog_name.include?(word) 
        self.arm_margin = word
      else
        self.arm_margin = 0
      end
      break if self.arm_margin.present?
    }
  end

  def set_full_doc
    self.full_doc = true
  end

  def set_loan_purpose p_name
    present_word = nil
    fetch_loan_purpose_fields.each{ |word|
      present_word = word if p_name.downcase.include?(word.downcase)
    }
    loan_purpose = get_refinance.include?(present_word) ? "Refinance" : "Purchase"
    self.loan_purpose = loan_purpose
  end

  def set_arm_basic p_name
    self.arm_basic = ProgramUpdate.arm_basic(p_name)
  end

  # def set_loan_size p_name
  #   present_word = nil
  #   fetch_loan_size_fields.each{ |word|
  #     if p_name.squish.downcase.include?(word.downcase)
  #       present_word = word 
  #       break
  #     end
  #   }
  #   loan_size = get_high_balance.include?(present_word) ? "High-Balance" : get_jumbo.include?(present_word) ? "Jumbo" : get_super_conforming.include?(present_word) ? "Super Conforming" : get_non_conforming.include?(present_word) ? "Non-Conforming" : get_conforming.include?(present_word) ? "Conforming" : get_conf.include?(present_word) ? "Conforming and High-Balance" : get_non_conf_hb.include?(present_word) ? "Non-Conforming and Jumbo" : "Conforming"
  #   self.loan_size = loan_size
  # end
  def set_loan_size selected_val, p_name
    loan_size = selected_val.map { |present_word| loan_size = get_high_balance.include?(present_word) ? "High-Balance" : get_jumbo.include?(present_word) ? "Jumbo" : get_super_conforming.include?(present_word) ? "Super Conforming" : get_non_conforming.include?(present_word) ? "Non-Conforming" : get_conforming.include?(present_word) ? "Conforming" : get_conf.include?(present_word) ? "Conforming and High-Balance" : get_non_conf_hb.include?(present_word) ? "Non-Conforming and Jumbo" : "Conforming"}.join('&')
    loan_size = loan_size.split('&').uniq.join('&')
    unless loan_size.downcase.include?("non-conforming") || loan_size.downcase.include?("super conforming")
      conf = get_conforming.map { |word|  p_name.downcase.include?(word) }.any?
    end
    if loan_size.present? && conf
      self.loan_size = loan_size +"&" +"Conforming"
    else
      self.loan_size = (loan_size == "" ? "Conforming" : loan_size)
    end
    # self.loan_size = (loan_size == "" ? "Conforming" : loan_size)
  end

  def set_arm_advanced p_name
    present_word = nil
    ["10/5", "5/1 3-2-5"].each{ |word|
      present_word = word if p_name.downcase.include?(word.downcase)
    }
    self.arm_advanced = present_word
  end

  def set_fannie_mae p_name
    present_word = false
    ["Fannie Mae", "FNMA", "DU "].each{ |word|
      present_word = true if p_name.downcase.include?(word.downcase)
    }
    self.fannie_mae = present_word
  end

  def set_freddie_mac p_name
    present_word = false
    ["Freddie Mac", "FHLMC", "LP "].each{ |word|
      present_word = true if p_name.downcase.include?(word.downcase)
    }
    self.freddie_mac = present_word
  end

  def set_freddie_mac_product p_name
    present_word = nil
    ["Home Possible"].each{ |word|
      present_word = word if p_name.downcase.include?(word.downcase)
    }
    self.freddie_mac_product = present_word
  end

  def set_fannie_mae_product p_name
    present_word = nil
    ["HomeReady", "Home Ready"].each{ |word|
      present_word = "HomeReady" if p_name.downcase.include?(word.downcase)
    }
    self.fannie_mae_product = present_word
  end

  # def add_default_loan_size
  #   p_name = self.program_name
  #   present_word = nil
  #   fetch_loan_size_fields.each{ |word|
  #     if p_name.squish.downcase.include?(word.downcase)
  #       present_word = word 
  #       break
  #     end
  #   }
  #   loan_size = get_high_balance_extra.include?(present_word) ? "High-Balance Extra" : get_high_balance.include?(present_word) ? "High-Balance" : get_jumbo.include?(present_word) ? "Jumbo" : get_super_conforming.include?(present_word) ? "Super Conforming" : get_non_conforming.include?(present_word) ? "Non-Conforming" : get_conforming.include?(present_word) ? "Conforming" : get_conf.include?(present_word) ? "Conforming and High-Balance" : get_non_conf_hb.include?(present_word) ? "Non-Conforming and Jumbo" : "Conforming"
  #   self.update_column(:loan_size, loan_size)
  # end
end
