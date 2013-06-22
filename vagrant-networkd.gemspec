# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "vagrant-networkd"
  s.version = "0.0.6"
  s.authors = ["Alberto Murillo"]
  s.email = ["powerbsd@yahoo.com"]
  s.homepage = "http://github.com/albertomurillo/vagrant-networkd"
  s.summary = %q{Vagrant plugin to detect and support networkd based systems}
  s.description = %q{Vagrant plugin to detect and support networkd based systems}

  s.files            = `git ls-files`.split("\n")
  s.test_files       = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables      = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths    = ["lib"]
end
