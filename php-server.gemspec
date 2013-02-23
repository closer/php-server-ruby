# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'php-server/version'

Gem::Specification.new do |gem|
  gem.name          = "php-server"
  gem.version       = PHPServer::VERSION
  gem.authors       = ["Eido NABESHIMA"]
  gem.email         = ["closer009@gmail.com"]
  gem.description   = %q{Webrick server: PHP mounted}
  gem.summary       = %q{Webrick server: PHP mounted}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
