# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'sproutcore/version'

Gem::Specification.new do |s|
  s.name        = "abbot-ng"
  s.version     = SproutCore::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = []
  s.email       = []
  s.homepage    = "http://rubygems.org/gems/abbot-ng"
  s.summary     = "TODO: Write a gem summary"
  s.description = "TODO: Write a gem description"

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "abbot-ng"

  s.add_runtime_dependency "erubis", "~> 2.6.6"
  s.add_runtime_dependency "rack",   "~> 1.2"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").select{|f| f =~ /^bin/}
  s.require_path = 'lib'
end
