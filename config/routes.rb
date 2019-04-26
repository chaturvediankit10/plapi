require 'sidekiq/web'
Rails.application.routes.draw do

	scope :module => 'search_api' do
	  root "dashboard#index"
	  get 'dashboard/fetch_programs_by_bank', to: 'dashboard#fetch_programs_by_bank'
	  get 'dashboard/index', to: 'dashboard#index'

	end
end