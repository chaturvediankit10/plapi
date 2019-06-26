module SearchApi
  class Calculation
    def monthly_expenses_breakdown(calculate_loan_payment, number_of_payments, calculate_monthly_payment, home_price, default_annual_home_insurance, default_pmi_insurance, default_property_tax_perc, down_payment)
      monthly_breakdown = {
        :mortgage_principal => {},
        :mortgage_interest => {},
        :home_insurance => {},
        :pmi_insurance => {},
        :hoa_dues => {},
        :monthly_expenses_sum => {},
        :property_tax => {}
      }
      property_tax = {}
      property_tax[:monthly] = (home_price * default_property_tax_perc*1.0 /100/12)
      property_tax[:total] = (property_tax[:monthly]*number_of_payments)
      monthly_breakdown[:property_tax][:monthly] = property_tax[:monthly]
      monthly_breakdown[:mortgage_principal][:monthly] = (calculate_loan_payment/number_of_payments)
      monthly_breakdown[:mortgage_principal][:total] = calculate_loan_payment
      monthly_breakdown[:mortgage_interest][:monthly] = (calculate_monthly_payment-monthly_breakdown[:mortgage_principal][:monthly])
      monthly_breakdown[:mortgage_interest][:total] =  (calculate_monthly_payment*number_of_payments-monthly_breakdown[:mortgage_principal][:total])
      monthly_breakdown[:home_insurance][:monthly] = (home_price*0.35).round(2)

      monthly_breakdown[:home_insurance][:total] = ((default_annual_home_insurance*1.0*number_of_payments)/12)
      monthly_breakdown[:pmi_insurance][:monthly] = default_pmi_insurance
      monthly_breakdown[:pmi_insurance][:total] =  monthly_breakdown[:pmi_insurance][:monthly].to_i == 0 ? 0.0 :  monthly_breakdown[:pmi_insurance][:monthly]*calculate_pmi_term(home_price, number_of_payments, down_payment)
      monthly_breakdown[:hoa_dues][:monthly] = 0.00
      monthly_breakdown[:hoa_dues][:total] = (monthly_breakdown[:hoa_dues][:monthly]*number_of_payments)
      monthly_breakdown[:monthly_expenses_sum][:monthly] =  ((monthly_breakdown[:mortgage_principal][:monthly] + monthly_breakdown[:mortgage_interest][:monthly] + property_tax[:monthly] + monthly_breakdown[:home_insurance][:monthly] + monthly_breakdown[:pmi_insurance][:monthly] + monthly_breakdown[:hoa_dues][:monthly]))

      monthly_breakdown[:monthly_expenses_sum][:total] = ((monthly_breakdown[:mortgage_principal][:total] + monthly_breakdown[:mortgage_interest][:total] + property_tax[:total] + monthly_breakdown[:home_insurance][:total] + monthly_breakdown[:pmi_insurance][:total]))

      monthly_breakdown[:mortgage_principal][:percentage] = ((monthly_breakdown[:mortgage_principal][:monthly]*100 / monthly_breakdown[:monthly_expenses_sum][:monthly])).infinite? ? 0.0 : ((monthly_breakdown[:mortgage_principal][:monthly]*100 / monthly_breakdown[:monthly_expenses_sum][:monthly])).round(2)

      monthly_breakdown[:mortgage_interest][:percentage] =  ((monthly_breakdown[:mortgage_interest][:monthly]*100 / monthly_breakdown[:monthly_expenses_sum][:monthly])).infinite? ? 0.0 : ((monthly_breakdown[:mortgage_interest][:monthly]*100 / monthly_breakdown[:monthly_expenses_sum][:monthly])).round(2)

      property_tax[:percentage] = ((property_tax[:monthly]*100 / monthly_breakdown[:monthly_expenses_sum][:monthly])).round(2)

      monthly_breakdown[:home_insurance][:percentage] = ((monthly_breakdown[:home_insurance][:monthly]*100 / monthly_breakdown[:monthly_expenses_sum][:monthly])).round(2)

      monthly_breakdown[:pmi_insurance][:percentage] =  ((monthly_breakdown[:pmi_insurance][:monthly]*100 / monthly_breakdown[:monthly_expenses_sum][:monthly])).round(2)

      monthly_breakdown[:hoa_dues][:percentage] =  ((monthly_breakdown[:hoa_dues][:monthly]*100 / monthly_breakdown[:monthly_expenses_sum][:monthly])).round(2)

      monthly_breakdown[:monthly_expenses_sum][:percentage] = (monthly_breakdown[:mortgage_principal][:percentage] + monthly_breakdown[:mortgage_interest][:percentage] + property_tax[:percentage] + monthly_breakdown[:home_insurance][:percentage] + monthly_breakdown[:pmi_insurance][:percentage] + monthly_breakdown[:hoa_dues][:percentage]).round()

      return monthly_breakdown
    end

    def calculate_pmi_term(home_price, number_of_payments, down_payment)
     (((home_price*0.22- down_payment)/((home_price - down_payment)/number_of_payments)).ceil) rescue 0
    end


  end
end
