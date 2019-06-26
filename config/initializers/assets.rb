Rails.application.config.assets.precompile += %w( search_api/application.scss search_api/datatables.scss search_api/dashboard.scss search_api/custom_style.css search_api/application.js search_api/cable.js search_api/datatables.js )

Rails.application.config.autoload_paths +=  %w("#{Rails.root}/lib") # add this line
