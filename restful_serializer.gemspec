lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'restful/version'

Gem::Specification.new do |s|
  s.name = %q{restful_serializer}
  s.version = Restful::VERSION
  s.required_rubygems_version = ">= 1.3.6"

  s.authors = ["Josh Partlow"]
  s.email = %q{jpartlow@glatisant.org}
  s.summary = %q{Helps with serializing activerecord instances as Restful resources.}
  s.description = %q{This library is used to decorate ActiveRecord with methods to assist in generating Restful content for Web Services.}
  s.homepage = %q{http://github.com/jpartlow/restful_serializer}
  s.extra_rdoc_files = [
    "LICENSE",
    "README.rdoc"
  ]
  s.rdoc_options = ["--main=README.rdoc", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files spec/*`.split("\n")

  s.add_development_dependency(%q<rspec>, [">= 2.0.0"])
  s.add_development_dependency(%q<sqlite3>)
  s.add_runtime_dependency(%q<rails>, [">= 3.0.0", "< 4.0.0"])
  s.add_runtime_dependency(%q<deep_merge>, [">= 1.0.0"])
end
