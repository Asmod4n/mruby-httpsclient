MRuby::Gem::Specification.new('httpsclient') do |spec|
  spec.license = 'Apache-2'
  spec.author  = 'Hendrik Beskow'
  spec.summary = 'mruby gem for picohttpparser'

  spec.add_dependency 'tls'
  spec.add_dependency 'phr'
end
