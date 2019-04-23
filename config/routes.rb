require 'sidekiq/web'
Rails.application.routes.draw do
	scope :module => 'rate_sheet_extractor' do
	# namespace :rate_sheet_extractor do
	  # root :to => "dashboard#index"
	  get 'dashboard/banks'
	  # root :to => "ob_new_rez_wholesale5806#index"
	  get 'error_logs/*name', to: 'error_logs#display_logs', as: :display_logs
	  resources :ob_new_rez_wholesale5806, :only => [:index] do
	    member do
	      get :programs
	      get :cover_zone_1
	      get :heloc
	      get :smartseries
	      get :government
	      get :freddie_fixed_rate
	      get :conforming_fixed_rate
	      get :home_possible
	      get :conforming_arms
	      get :lp_open_acces_arms
	      get :lp_open_access_105
	      get :lp_open_access
	      get :du_refi_plus_arms
	      get :du_refi_plus_fixed_rate_105
	      get :du_refi_plus_fixed_rate
	      get :dream_big
	      get :high_balance_extra
	      get :freddie_arms
	      get :jumbo_series_c
	      get :jumbo_series_d
	      get :jumbo_series_f
	      get :jumbo_series_h
	      get :jumbo_series_i
	      get :jumbo_series_jqm
	      get :homeready_hb
	      get :homeready
	      get :single_program
	      get :error_page
	    end
	  end

	  resources :ob_blue_point_mortgage_wholesale6187, :only => [:index] do
	    member do
	      get :fha_standard_programs
	      get :fha_streamline_programs
	    end
	  end

	  # resources :ob_cmg_wholesales, only: [:index] do
	  #   member do
	  #     get :import_gov_sheet
	  #   end
	  # end
	  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

	  resources :ob_cmg_wholesales, only: [:index] do
	    member do
	      get :programs
	      get :gov
	      get :agency
	      get :agencyllpas
	      get :durp
	      get :oa
	      get :jumbo_700
	      get :jumbo_6200
	      get :jumbo_7200_6700
	      get :jumbo_6600
	      get :jumbo_7600
	      get :jumbo_6400
	      get :jumbo_6800
	      get :jumbo_6900_7900
	      get :mi_llpas
	      get :single_program
	      get :aio
	    end
	  end
	  resources :ob_cardinal_financial_wholesale10742, only: [:index] do
	    member do
	      get :ak
	      get :sheet1
	      get :programs
	      get :single_program
	      get :fannie_mae_products
	      get :freddie_mac_products
	      get :fha_va_usda_products
	      get :non_conforming_jumbo_core
	      get :non_conforming_jumbo_x
	    end
	  end

	  resources :ob_allied_mortgage_group_wholesale8570, only: [:index] do
	    member do
	      get :programs
	      get :fha
	      get :va
	      get :conf_fixed
	      get :single_program
	    end
	  end

	  resources :ob_newfi_wholesale7019, only: [:index] do
	    member do
	      get :programs
	      get :biscayne_delegated_jumbo
	      get :sequoia_portfolio_plus_products
	      get :sequoia_expanded_products
	      get :sequoia_investor_pro
	      get :fha_buydown_fixed_rate_products
	      get :fha_fixed_arm_products
	      get :fannie_mae_homeready_products
	      get :fnma_buydown_products
	      get :fnma_conventional_fixed_rate
	      get :fnma_conventional_high_balance
	      get :fnma_conventional_arm
	      get :olympic_piggyback_fixed
	      get :olympic_piggyback_high_balance
	      get :olympic_piggyback_arm
	      get :single_program
	    end
	  end

	  resources :ob_home_point_financial_wholesale11098, only: [:index] do
	    member do
	      get :programs
	      get :conforming_standard
	      get :conforming_high_balance
	      get '/fha-va-usda' => 'ob_home_point_financial_wholesale11098#fha_va_usda'
	      get :fha_203k
	      get :homestyle
	      get :durp
	      get :lpoa
	      get :err
	      get :hlr
	      get :homeready
	      get :homepossible
	      get :jumbo_select
	      get :jumbo_choice
	      get :single_program
	    end
	  end

	  resources :ob_sun_west_wholesale_demo5907, only: [:index] do
	    member do
	      get :programs
	      get :ratesheet
	      get :single_program
	      get :agency_conforming_programs
	      get :fhlmc_home_possible
	      get :non_conforming_sigma_qm_prime_jumbo
	      get :non_conforming_jw
	      get :government_programs
	      get :hecm_reverse_mortgage
	      get :non_qm_sigma_seasoned_credit_event
	      get :non_qm_sigma_no_credit_event_plus
	      get :non_qm_real_prime_advantage
	      get :non_qm_real_credit_advantage_a
	      get :non_qm_real_credit_advantage_bbc
	      get :non_qm_real_investor_income_a
	      get :non_qm_real_investor_income_bb
	      get :non_qm_real_dsc_ratio
	    end
	  end

	  resources :ob_united_wholesale_mortgage4892, only: [:index] do
	    member do
	      get :programs
	      get :single_program
	      get :conv
	      get :govt
	      get :govt_arms
	      get '/non-conf' => 'ob_united_wholesale_mortgage4892#non_conf'
	      get :harp
	      get :conv_adjustments
	    end
	  end

	  resources :ob_quicken_loans3571, only: [:index] do
	    member do
	      get :programs
	      get :single_program
	      get :ws_rate_sheet_summary
	      get :ws_du_lp_pricing
	      get :durp_lp_relief_pricing
	      get :fha_usda_full_doc_pricing
	      get :fha_streamline_pricing
	      get :va_full_doc_pricing
	      get :va_irrrl_pricing_govy_llpas
	      get :na_jumbo_pricing_llpas
	      get :du_lp_llpas
	      get :durp_lp_relief_llpas
	      get :lpmi
	    end
	  end

	  resources :ob_union_home_mortgage_wholesale1711, only: [:index] do
	    member do
	      get :programs
	      get :single_program
	      get :conventional
	      get :conven_highbalance_30
	      get :gov_highbalance_30
	      get :government_30_15_yr
	      get :arm_programs
	      get '/fnma_du-refi_plus' => 'ob_union_home_mortgage_wholesale1711#fnma_du_refi_plus'
	      get :fhlmc_open_access
	      get :fnma_home_ready
	      get :fhlmc_home_possible
	      get :simple_access
	      get :jumbo_fixed
	      get '/non-qm' => 'ob_union_home_mortgage_wholesale1711#non_qm'
	    end
	  end

	  resources :ob_sun_west_wholesale_demo5907, only: [:index] do
	    member do
	      get :programs
	      get :ratesheet
	      get :single_program
	    end
	  end

	  resources :ob_american_financial_resources_wholesale5513, only: [:index] do
	    member do
	      get :programs
	      get :gnma
	      get :gnma_hb
	      get :fnma
	      get :fhlmc
	      get :hp
	      get :jumbo
	      get :single_program
	    end
	  end

	  resources :ob_m_t_bank_wholesale9996, only: [:index] do
	    member do
	      get :programs
	      get :single_program
	      get :rates
	    end
	  end

	  resources :ob_direct_mortgage_corp_wholesale8443, only: [:index] do
	    member do
	      get :programs
	      get '/ratesheet-singlepageexcel' => 'ob_direct_mortgage_corp_wholesale8443#rate_sheet_single_page_excel'
	      get :single_program
	    end
	  end

	  resources :ob_royal_pacific_funding_wholesale8409, only: [:index] do
	    member do
	      get :programs
	      get :royal_pfc#Royal PFC
	      get :single_program
	      get :fha_standard_programs
	      get :fha_streamline_programs
	      get :va_standard_programs
	      get :va_streamline_programs
	      get :conventional_fixed_programs
	      get :conventional_arm_programs
	      get :freddie_mac_programs
	      get '/core_jumbo_-_minimum_loan_amount_$1.00_above_agency_limit' => 'ob_royal_pacific_funding_wholesale8409#core_jumbo_minimum_loan_amount_above_agency_limit'
	      get :choice_advantage_plus
	      get :choice_advantage
	      get :choice_alternative
	      get :choice_ascent
	      get :choice_investor
	      get :pivot_prime_jumbo
	    end
	  end
	  resources :wholesale_rate_sheet_home_bridge_wholesale, only: [:index] do
	    member do
	      get :programs
	      get :single_program
	      get :rate_sheet
	      get :conventional_fixed_rate_products
	      get :conventional_arm_products
	      get :government_products
	      get :high_ltv_refinance
	      get :jumbo_products
	      get :jumbo_flex_product
	      get :elite_plus_programs
	      get :expanded_plus_programs
	      get :simple_access_programs
	    end
	  end
	  resources :ob_lakeview_wholesale8393, only: [:index] do
	    member do
	      get :programs
	      get :single_program
	      get :early_access
	      get :asset_inclusion
	      get :expanded_ratio
	      get :alternative_income_calculation
	      get :investor_product_no_prepayment_penalty
	      get :bayview_portfolio_products
	      get :piggy_back_second_lien_prepayment
	    end
	  end

	  resources :ob_acc_mortgage9933, only: [:index] do
	    member do
	      get :programs
	      get :single_program
	      get :expanded_prime
	    end
	  end

	  match "dashboard/index", to: 'dashboard#index', via: [:get, :post]
	  get 'dashboard/fetch_programs_by_bank', to: 'dashboard#fetch_programs_by_bank'
	  # mount Sidekiq::Web => '/sidekiq'
	end
end