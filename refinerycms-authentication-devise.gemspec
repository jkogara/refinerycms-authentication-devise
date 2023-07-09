# Encoding: UTF-8
# frozen_string_literal: true

Gem::Specification.new do |s|
  s.platform          = Gem::Platform::RUBY
  s.name              = 'refinerycms-authentication-devise'
  s.version           = '2.0.1'
  s.summary           = 'Devise based authentication extension for Refinery CMS'
  s.description       = 'A Devise authentication extension for Refinery CMS'
  s.homepage          = 'http://refinerycms.com'
  s.authors           = ['Philip Arndt', 'Brice Sanchez', 'Rob Yurkowski']
  s.license           = 'MIT'
  s.require_paths     = %w[lib]

  s.files             = `git ls-files`.split("\n")
  s.test_files        = `git ls-files -- spec/*`.split("\n")

  s.add_dependency 'actionmailer',      '>= 5.0.0'
  s.add_dependency 'devise',            ['~> 4.0', '>= 4.3.0']
  s.add_dependency 'friendly_id',       '~> 5.2'
  s.add_dependency 'refinerycms-core',  ['>= 3.0.0', '< 5.0']

  s.required_ruby_version = '>= 2.2.2'
end
