Gem::Specification.new do |s|
  s.name        = 'teifacsimile_to_jekyll'
  s.version     = '0.1.0'
  s.date        = '2015-11-30'
  s.summary     = "Import TEI facsimile pages and annotations as Jekyll content"
  s.description = "A simple hello world gem"
  s.authors     = ["Rebecca Sutton Koeser"]
  s.email       = 'rebecca.s.koeser@emory.edu'
  s.files       = ["lib/teifacsimile_to_jekyll.rb", "lib/teifacsimile_to_jekyll/tei.rb"]
  s.executables = ['jekyllimport_teifacsimile']
  s.homepage    = 'https://github.com/emory-libraries-ecds/teifacsimile-to-jekyll'
    # 'http://rubygems.org/gems/hola'
  s.license       = 'Apache 2'
  s.add_runtime_dependency "nokogiri"
  s.add_runtime_dependency "fastimage"
  s.add_development_dependency "rake"
end