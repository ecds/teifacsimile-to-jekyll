# teifacsimile-to-jekyll
Generate jekyll site content from annotated TEI facsimile.

**Requires Ruby 2.x**

Developed for with [Readux](http://readux.library.emory.edu) ([code](http://github.com/emory-libraries/readux))
annotated edition export.

[![Travis-CI build status](https://travis-ci.org/emory-libraries-ecds/teifacsimile-to-jekyll.svg "Travis-CI build")](https://travis-ci.org/emory-libraries-ecds/teifacsimile-to-jekyll)
[![Coverage Status](https://coveralls.io/repos/github/emory-libraries-ecds/teifacsimile-to-jekyll/badge.svg?branch=develop)](https://coveralls.io/github/emory-libraries-ecds/teifacsimile-to-jekyll?branch=develop)
[![Code Climate](https://codeclimate.com/github/emory-libraries-ecds/teifacsimile-to-jekyll/badges/gpa.svg)](https://codeclimate.com/github/emory-libraries-ecds/teifacsimile-to-jekyll)
[![Requirements Status](https://requires.io/github/emory-libraries-ecds/teifacsimile-to-jekyll/requirements.svg?branch=develop)](https://requires.io/github/emory-libraries-ecds/teifacsimile-to-jekyll/requirements/?branch=develop)

## Developer notes

Run the tests:
`rake test`

Build the documentation:
`yard doc`

Build the gem:
`gem build teifacsimile_to_jekyll.gemspec`

Run local development copy of the import script:

`env RUBYLIB=lib ./bin/jekyllimport_teifacsimile tei-annotated.xml`
