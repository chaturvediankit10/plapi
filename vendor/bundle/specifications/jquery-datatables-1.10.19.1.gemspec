# -*- encoding: utf-8 -*-
# stub: jquery-datatables 1.10.19.1 ruby lib

Gem::Specification.new do |s|
  s.name = "jquery-datatables".freeze
  s.version = "1.10.19.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["mkhairi".freeze]
  s.date = "2018-10-05"
  s.description = "Include jQuery DataTables in asset pipeline with ease".freeze
  s.email = ["mkhairi@labs.my".freeze]
  s.homepage = "https://github.com/mkhairi/jquery-datatables".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Jquery DataTables web assets for Rails, etc.".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<jquery-rails>.freeze, ["~> 3.1"])
      s.add_development_dependency(%q<bundler>.freeze, ["~> 1.7"])
      s.add_development_dependency(%q<rake>.freeze, ["~> 10.0"])
    else
      s.add_dependency(%q<jquery-rails>.freeze, ["~> 3.1"])
      s.add_dependency(%q<bundler>.freeze, ["~> 1.7"])
      s.add_dependency(%q<rake>.freeze, ["~> 10.0"])
    end
  else
    s.add_dependency(%q<jquery-rails>.freeze, ["~> 3.1"])
    s.add_dependency(%q<bundler>.freeze, ["~> 1.7"])
    s.add_dependency(%q<rake>.freeze, ["~> 10.0"])
  end
end
