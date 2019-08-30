module SearchApi
  class Calculation
    def monthly_expenses_breakdown(calculate_loan_payment, number_of_payments, calculate_monthly_payment, home_price, default_annual_home_insurance, default_pmi_insurance, default_property_tax_perc, down_payment, params)
      mortgage_principal = {}
      mortgage_interest  = {}
      home_insurance = {}
      @pmi_insurance = {}
      hoa_dues = {}
      monthly_expenses_sum = {}
      property_tax = {}
      

      if params["monthly_property_tax"].present?
        property_tax[:monthly] = params["monthly_property_tax"].delete(',').to_f rescue 0.0
        property_tax[:total] = (property_tax[:monthly]*number_of_payments) rescue 0.0
      else
        property_tax[:monthly] = (home_price * default_property_tax_perc*1.0 /100/12) rescue 0.0
        property_tax[:total] = (property_tax[:monthly]*number_of_payments) rescue 0.0
      end

      mortgage_principal[:monthly] = (calculate_loan_payment/number_of_payments) rescue 0.0
      mortgage_principal[:total] = calculate_loan_payment

      mortgage_interest[:monthly] = (calculate_monthly_payment-mortgage_principal[:monthly]) rescue 0.0
      mortgage_interest[:total] =  (calculate_monthly_payment*number_of_payments-mortgage_principal[:total]) rescue 0.0
      if params["commit"].nil? && params["monthly_home_insurance"].present?
        home_insurance[:monthly] = params["monthly_home_insurance"].delete(',').to_f
      else
        # home_insurance[:monthly] = (home_price*0.35).round(2) rescue 0.0
        home_insurance[:monthly] = (default_annual_home_insurance/12) rescue 0.0
      end

      home_insurance[:total] = ((default_annual_home_insurance*1.0*number_of_payments)/12) rescue 0.0

      if params["commit"].nil? && params["monthly_pmi_insurance"].present?
        @pmi_insurance[:monthly] = params["monthly_pmi_insurance"].delete(',').to_f
        default_pmi_insurance = params["monthly_pmi_insurance"].delete(',').to_f
      else
        @pmi_insurance[:monthly] = default_pmi_insurance rescue 0.0
      end
      @pmi_insurance[:total] =  @pmi_insurance[:monthly].to_i == 0 ? 0.0 :  @pmi_insurance[:monthly]*calculate_pmi_term(home_price, number_of_payments, down_payment) rescue 0.0

      if params["commit"].nil? && params["monthly_hoa_dues"].present?
        hoa_dues[:monthly] = params["monthly_hoa_dues"].delete(',').to_f
      else
        hoa_dues[:monthly] = 0.00
      end

      hoa_dues[:total] = (hoa_dues[:monthly]*number_of_payments) rescue 0.0
      monthly_expenses_sum[:monthly] =  ((mortgage_principal[:monthly] + mortgage_interest[:monthly] + property_tax[:monthly] + home_insurance[:monthly] + @pmi_insurance[:monthly] + hoa_dues[:monthly]))  rescue 0.0

      monthly_expenses_sum[:total] = ((mortgage_principal[:total] + mortgage_interest[:total] + property_tax[:total] + home_insurance[:total] + @pmi_insurance[:total])) rescue 0.0

      mortgage_principal[:percentage] = ((mortgage_principal[:monthly]*100 / monthly_expenses_sum[:monthly])).round(2) rescue 0.0

      mortgage_interest[:percentage] =  ((mortgage_interest[:monthly]*100 / monthly_expenses_sum[:monthly])).round(2) rescue 0.0

      property_tax[:percentage] = ((property_tax[:monthly]*100 / monthly_expenses_sum[:monthly])).round(2) rescue 0.0

      home_insurance[:percentage] = ((home_insurance[:monthly]*100 / monthly_expenses_sum[:monthly])).round(2) rescue 0.0

      @pmi_insurance[:percentage] =  ((@pmi_insurance[:monthly]*100 / monthly_expenses_sum[:monthly])).round(2) rescue 0.0

      hoa_dues[:percentage] =  ((hoa_dues[:monthly]*100 / monthly_expenses_sum[:monthly])).round(2) rescue 0.0

      return { mortgage_principal: mortgage_principal,mortgage_interest: mortgage_interest,home_insurance: home_insurance,pmi_insurance: @pmi_insurance,hoa_dues: hoa_dues,monthly_expenses_sum: monthly_expenses_sum, property_tax: property_tax}  
    end

    def calculate_pmi_term(home_price, number_of_payments, down_payment)
     pmi_term = (((home_price*0.22- down_payment)/((home_price - down_payment)/number_of_payments)).ceil) rescue 0
     return pmi_term
    end


  end
end
