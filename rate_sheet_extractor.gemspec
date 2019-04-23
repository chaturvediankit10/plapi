
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rate_sheet_extractor/version"

Gem::Specification.new do |spec|
  spec.name          = "rate_sheet_extractor"
  spec.version       = RateSheetExtractor::VERSION
  spec.authors       = ["Clara"]
  spec.email         = ["clara@gmail.com"]

  spec.summary       = "RateSheetExtractor Gem"
  spec.description   = "New Gem"
  spec.homepage      = "http://ratesheetextractor.com"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
  #   `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  # end
  spec.add_dependency "activesupport"

  spec.files = Dir["{app,config,db,lib}/**/*", 'LICENSE', 'Rakefile', 'README.md']
  spec.test_files = Dir['test/**/*']
  
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_dependency 'jquery-datatables'
  spec.add_dependency 'bootsnap', '>= 1.1.0'
	spec.add_dependency 'bootstrap'
	spec.add_dependency 'jquery-rails'
	spec.add_dependency "roo", "~> 2.7.0"
	spec.add_dependency 'roo-xls'
	# spec.add_development_dependency 'bundler', '~> 2.0', '>= 2.0.1'
	spec.add_dependency 'sidekiq'
	spec.add_dependency 'google_drive'
	spec.add_dependency 'redis-rails'
  # s.add_dependency 'stripe'
  spec.add_dependency 'tzinfo-data'
	spec.add_dependency "select2-rails"
	spec.add_dependency 'csv'
	spec.add_dependency 'jquery-validation-rails'
  # s.add_dependency 'stripe'
end
