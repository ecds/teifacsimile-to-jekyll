# teifacsimile-to-jekyll
Generate jekyll site content from annotated TEI facsimile.

## Developer notes

Run the tests:
`rake test`

Build the documentation:
`yard doc`

Build the gem:
`gem build teifacsimile_to_jekyll.gemspec`

Run local development copy of the import script:

`env RUBYLIB=lib ./bin/jekyllimport_teifacsimile tei-annotated.xml`
