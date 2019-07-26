# -*- encoding: utf-8 -*-
# stub: finance_math 1.0.5 ruby lib

Gem::Specification.new do |s|
  s.name = "finance_math".freeze
  s.version = "1.0.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Nesha Zoric".freeze]
  s.date = "2017-08-16"
  s.description = "Implementation of Loan/Mortgage functions in Ruby language. APR function and PMT function. In calculations it includes implementation of bank fee, marketplace fee, fees for each payment to provide the most precise calculation at very high speed. ".freeze
  s.email = ["nesha@kolosek.com".freeze]
  s.homepage = "http://kolosek.com".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.0.4".freeze
  s.summary = "Most accurate APR and PMT caluclator for Ruby.".freeze

  s.installed_by_version = "3.0.4" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bundler>.freeze, ["~> 1.6"])
      s.add_development_dependency(%q<rake>.freeze, [">= 0"])
      s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
    else
      s.add_dependency(%q<bundler>.freeze, ["~> 1.6"])
      s.add_dependency(%q<rake>.freeze, [">= 0"])
      s.add_dependency(%q<rspec>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<bundler>.freeze, ["~> 1.6"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, [">= 0"])
  end
end
