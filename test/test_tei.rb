require 'minitest/autorun'
require 'teifacsimile_to_jekyll/tei'
require 'fileutils'

class TeiTest < Minitest::Unit::TestCase
    @@tei_fixture = File.expand_path('../fixtures/ladiesfirst.xml', __FILE__)

    def test_load_tei
        assert_instance_of TeiFacsimile, load_tei(@@tei_fixture),
            'load_tei should return TeiFacsimile instance'
    end

    def test_tei_facsimile
        teidoc = load_tei(@@tei_fixture)
        # check basic top-level types & mappings
        assert_instance_of TeiTitleStatement, teidoc.title_statement,
            'title_statement should be a TeiTitleStatement instance'
        assert_instance_of Hash, teidoc.source_bibl,
            'source_bibl should return a Hash'
        assert_instance_of Array, teidoc.pages,
            'pages should return an array'
        assert_instance_of Array, teidoc.annotations,
            'annotations should return an array'

        # check counts/keys for arrays and hashes
        assert_equal 328, teidoc.pages.size,
            'should load 328 facsimile pages from fixture'
        assert_equal 13, teidoc.annotations.size,
            'should load 13 annotations from fixture'
        assert teidoc.source_bibl.key?('original')
        assert teidoc.source_bibl.key?('digital')

        # check subtypes
        assert_instance_of TeiBibl, teidoc.source_bibl['original'],
            'source bibl should be loaded as instance of TeiBibl'
        assert_instance_of TeiFacsimilePage, teidoc.pages[0],
            'pages should be loaded as instances of TeiFacsimilePage'
        assert_instance_of TeiNote, teidoc.annotations[0],
            'annotations should be loaded as instances of TeiNote'
    end

    def test_tei_titlestatement
        title_statement = load_tei(@@tei_fixture).title_statement
        assert_equal '"Ladies first!"  a novel ', title_statement.title
        assert_equal ', an annotated digital edition', title_statement.subtitle
    end

    def test_tei_bibl
        teidoc = load_tei(@@tei_fixture)
        original_bibl = teidoc.source_bibl['original']
        assert_equal '"Ladies first!"  a novel ', original_bibl.title
        assert_equal '1896', original_bibl.date
        assert_equal 'Verdenal, Dominique François, Mrs.', original_bibl.author

        digital_bibl = teidoc.source_bibl['digital']
        assert_equal '"Ladies first!"  a novel , digital edition', digital_bibl.title
        assert_equal '2010', digital_bibl.date
        # digital bible includes ref tags with target urls
        assert_instance_of Hash, digital_bibl.references
        assert digital_bibl.references.key?('digital-edition')
        assert digital_bibl.references.key?('pdf')
        assert_instance_of TeiRef, digital_bibl.references['pdf']
        assert_equal digital_bibl.references['digital-edition'].target,
            "http://readux.library.emory.edu/books/emory:7sr72/"
        assert_equal digital_bibl.references['pdf'].target,
            "http://readux.library.emory.edu/books/emory:7sr72/pdf/#page=2"
    end

    def test_teifacsimile_page
        teidoc = load_tei(@@tei_fixture)
        page = teidoc.pages[0]
        assert_equal 'rdx_7sr72.p.idp356752', page.id
        assert_equal '1', page.n
        assert_instance_of Array, page.images
        assert_instance_of TeiGraphic, page.images[0]
        assert_equal 5, page.images.size,
            'expected 5 images for page 1'
        assert_equal 'small-thumbnail', page.images[0].rend
        assert_equal 'http://readux.library.emory.edu/books/emory:7sr72/pages/emory:gmrpr/mini-thumbnail/',
            page.images[0].url
        assert_equal 4, page.annotation_count,
            'expected annotation count of 4 for page 1'
        assert_instance_of Array, page.lines
        assert_instance_of TeiZone, page.lines[0]
        assert_instance_of Array, page.word_zones
        # this fixture does not contain word-level zones
        assert_equal 0, page.word_zones.size
        assert_instance_of Array, page.image_highlight_zones
        assert_instance_of TeiZone, page.image_highlight_zones[0]

        # basic testing on html output, to confirm template is running
        # and including data from current page
        html = page.html()
        assert_match 'class="ocr-line ocrtext"', html,
            'html for tei without word zones should include ocrtext at line level'
        assert_match '<span class="annotator-hl image-annotation-highlight"', html,
            'html for page 1 should include image annotation highlights'
        assert_match "data-annotation-id=\"#{page.image_highlight_zones[0].annotation_id}\"",
            html, 'html for image annotation highlights should include annotation id'
    end

    def test_teinote
        teidoc = load_tei(@@tei_fixture)
        note = teidoc.annotations[0]
        assert_equal 'annotation-11c8fa74-7839-4d31-8a04-48a50ee4c015', note.id
        assert_equal 'sepalme', note.author
        assert_equal '#highlight-11c8fa74-7839-4d31-8a04-48a50ee4c015', note.target
        assert_equal 'super sara was here', note.markdown
        assert_equal '11c8fa74-7839-4d31-8a04-48a50ee4c015', note.annotation_id
        assert_equal false, note.range_target?,
            'range_target? should return false for image highlight annotation'
        assert_instance_of TeiFacsimilePage, note.annotated_page
        assert_equal 'rdx_7sr72.p.idp356752', note.annotated_page.id

        # TODO: test ranged annotation also
    end

    def test_teizone
        teidoc = load_tei(@@tei_fixture)
        page = teidoc.pages[0]
        zone = page.lines[0]
        # values from the xml document
        assert_equal 'rdx_7sr72.ln.idm1446864', zone.id
        assert_equal 'line', zone.type
        assert_equal 1030.0, zone.ulx
        assert_equal 432.0, zone.uly
        assert_equal 1136.0, zone.lrx
        assert_equal 462.0, zone.lry
        assert_equal '^ Ui', zone.text
        assert_instance_of TeiZone, zone.parent
        assert_instance_of TeiZone, zone.page
        assert_equal "rdx_7sr72.b.idp1205744", zone.parent.id
        assert_equal "Text", zone.parent.type
        assert_equal page.id, zone.page.id
        assert_equal nil, zone.annotation_id,
            'normal text zone should not have an annotation id'

        # calculated values
        assert_equal zone.lrx - zone.ulx, zone.width
        assert_equal zone.lry - zone.uly, zone.height
        assert_equal nil, zone.avg_height,
            'tei zone without word zones should have no average height'
        assert_equal zone.page.height, zone.page.long_edge

        # minimal checking on css styles
        # (note: currently checking that values are present but not
        # double-checking the calculations)
        css = zone.css_style()
        assert_match 'style="', css
        assert_match 'left:', css
        assert_match 'top:', css
        assert_match 'width:', css
        assert_match 'height:', css
        assert_match 'text-align:left', css
        assert_match 'font-size:', css
        assert_match 'data-vhfontsize="', css

        # image annotation zone - should have an annotation id
        imgzone = page.image_highlight_zones[0]
        assert_equal '11c8fa74-7839-4d31-8a04-48a50ee4c015', imgzone.annotation_id
    end

end