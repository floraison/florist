
Gem::Specification.new do |s|

  s.name = 'florist'

  s.version = File.read(
    File.expand_path('../lib/florist.rb', __FILE__)
  ).match(/ VERSION *= *['"]([^'"]+)/)[1]

  s.platform = Gem::Platform::RUBY
  s.authors = [ 'John Mettraux' ]
  s.email = [ 'jmettraux+flor@gmail.com' ]
  s.homepage = 'http://github.com/floraison'
  #s.rubyforge_project = 'flor'
  s.license = 'MIT'
  s.summary = 'a worklist implementation for the flor workflow engine'

  s.description = %{
a worklist implementation for the flor workflow engine
  }.strip

  #s.files = `git ls-files`.split("\n")
  s.files = Dir[
    'README.{md,txt}',
    'CHANGELOG.{md,txt}', 'CREDITS.{md,txt}', 'LICENSE.{md,txt}',
    'Makefile',
    'lib/**/*.rb', #'spec/**/*.rb', 'test/**/*.rb',
    "#{s.name}.gemspec",
  ]

  #flor_version = s.version.to_s.split('.').take(2).join('.')
  #s.add_runtime_dependency 'flor', "~> #{flor_version}"
  s.add_runtime_dependency 'flor'

  s.add_development_dependency 'rspec', '~> 3'

  s.require_path = 'lib'
end

