MRuby::Gem::Specification.new('mruby-httpsclient') do |spec|
  spec.license = 'Apache-2'
  spec.author  = 'Hendrik Beskow'
  spec.summary = 'a https only client'

  spec.add_dependency 'mruby-tls'
  spec.add_dependency 'mruby-phr'
  spec.add_dependency 'mruby-uri-parser'
  spec.add_dependency 'mruby-fiber'
  spec.add_dependency 'mruby-struct'
end
