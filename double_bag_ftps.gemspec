# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "double-bag-ftps"
  s.version     = "0.1.3"
  s.license     = "MIT"
  s.author      = "Bryan Nix"
  s.homepage    = "https://github.com/bnix/double-bag-ftps"
  s.summary     = "Provides a child class of Net::FTP to support implicit and explicit FTPS."

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler"
  s.add_development_dependency "rspec"
end
