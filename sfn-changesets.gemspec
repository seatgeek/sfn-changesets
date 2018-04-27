$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'sfn-changesets/version'
Gem::Specification.new do |s|
  s.name = 'sfn-changesets'
  s.version = SfnChangeSets::VERSION.version
  s.summary = 'Sparkleformation Change Sets'
  s.author = 'Michael Weinberg'
  s.email = 'mweinberg@seatgeek.com'
  s.description = 'SparkleFormation Change Sets Callback'
  s.homepage = 'https://gitlab.service.seatgeek.mgmt/infra'
  s.license = 'Nonstandard'
  s.require_path = 'lib'
  s.add_dependency 'sfn'
  s.files = Dir['lib/**/*'] + ['sfn-changesets.gemspec']
end
