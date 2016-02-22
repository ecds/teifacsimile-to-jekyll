Gem::Specification.new do |s|
  s.name        = 'teifacsimile_to_jekyll'
  s.version     = '0.1.0'
  s.date        = '2015-11-30'
  s.summary     = "Import TEI facsimile pages and annotations as Jekyll content"
  s.description = "A simple hello world gem"
  s.authors     = ["Rebecca Sutton Koeser"]
  s.email       = 'rebecca.s.koeser@emory.edu'
  s.files       = ["lib/teifacsimile_to_jekyll.rb", "lib/teifacsimile_to_jekyll/tei.rb",
    "lib/teifacsimile_to_jekyll/teipage-to-html.xsl"]
  s.executables = ['jekyllimport_teifacsimile']
  s.homepage    = 'https://github.com/emory-libraries-ecds/teifacsimile-to-jekyll'
    # 'http://rubygems.org/gems/hola'
  s.license       = 'Apache-2.0'
  s.add_runtime_dependency "nokogiri",  "~> 1.6"
  s.add_runtime_dependency 'fastimage',  '~> 1.8', '>= 1.8.1'
  s.add_development_dependency 'rake', '~> 10.4', '>= 10.4.2'
end