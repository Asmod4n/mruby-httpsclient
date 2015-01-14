MRuby::Gem::Specification.new('mruby-httpsclient') do |spec|
  spec.license = 'Apache-2'
  spec.author  = 'Hendrik Beskow'
  spec.summary = 'a https only client'

  spec.add_dependency 'mruby-tls'
  spec.add_dependency 'mruby-phr'
end
