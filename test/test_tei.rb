# encoding: utf-8

require 'minitest/autorun'
require 'teifacsimile_to_jekyll/tei'
require 'fileutils'

class TeiTest < Minitest::Unit::TestCase
    @@tei_fixture = File.expand_path('../fixtures/ladiesfirst.xml', __FILE__)
    @@teipage_fixture = File.expand_path('../fixtures/page.xml', __FILE__)

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

        # interpgrp / tags
        assert_instance_of Hash, teidoc.tags
        assert_instance_of TeiInterp, teidoc.tags['test']
        assert_equal teidoc.tags['whee'].value, 'whee!'

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
        assert_equal 0, page.index
        assert_equal 5, teidoc.pages[5].index
        assert_equal teidoc.pages.size - 1, teidoc.pages[-1].index
        assert_instance_of Array, page.images
        assert_instance_of TeiGraphic, page.images[0]
        assert_equal 5, page.images.size,
            'expected 5 images for page 1'
        assert_equal 'small-thumbnail', page.images[0].rend
        assert_equal 'http://readux.library.emory.edu/books/emory:7sr72/pages/emory:gmrpr/mini-thumbnail/',
            page.images[0].url

        assert_instance_of Hash, page.images_by_type
        assert_instance_of TeiGraphic, page.images_by_type['page']
        assert_equal 5, page.images_by_type.size,
            'expected 5 images for page 1'
        assert_equal 'http://readux.library.emory.edu/books/emory:7sr72/pages/emory:gmrpr/mini-thumbnail/',
            page.images_by_type['small-thumbnail'].url

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
        assert_match '<span>{% raw %}RS{% endraw %}</span>', html,
            'ocr text in html should marked as raw'

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
        assert_equal [], note.tags

        # TODO: test ranged annotation also

        # annotation with tags
        note = teidoc.annotations[11]
        tags = note.tags
        assert_instance_of Array, tags
        assert_includes tags, 'whee'
        assert_includes tags, 'formatting'
        assert_includes tags, 'test'
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

        # preceding/following anchors and text annotation
        # preceding start anchors / following end anchors
        # - first zone has no preceding; and all end anchors follow
        assert_equal [], zone.preceding_start_anchors
        assert_equal 3, zone.following_end_anchors.size
        assert_instance_of TeiAnchor, zone.following_end_anchors[0]
        assert_equal false, zone.highlighted?
        assert_equal 'testannotation1', zone.following_end_anchors[0].annotation_id
        assert_equal '4c69b06c-0888-4265-a891-5fa315f8fccd',
            zone.following_end_anchors[1].annotation_id
        assert_equal '4c69b06c-0888-4265-a891-5fa315f8fccf',
            zone.following_end_anchors[2].annotation_id
        anchor_ids = zone.following_end_anchor_ids
        assert anchor_ids.include? 'testannotation1'
        assert anchor_ids.include? '4c69b06c-0888-4265-a891-5fa315f8fccd'
        assert anchor_ids.include? '4c69b06c-0888-4265-a891-5fa315f8fccf'

        lastline = teidoc.pages[-1].lines[-1]
        assert_equal [], lastline.following_end_anchors
        assert_equal 3, lastline.preceding_start_anchors.size
        assert_equal 'testannotation1',
            lastline.preceding_start_anchors[0].annotation_id
        assert_equal '4c69b06c-0888-4265-a891-5fa315f8fccf',
            lastline.preceding_start_anchors[1].annotation_id
        assert_equal '4c69b06c-0888-4265-a891-5fa315f8fccd',
            lastline.preceding_start_anchors[2].annotation_id
        anchor_ids = lastline.preceding_start_anchor_ids
        assert anchor_ids.include? 'testannotation1'
        assert anchor_ids.include? '4c69b06c-0888-4265-a891-5fa315f8fccd'
        assert anchor_ids.include? '4c69b06c-0888-4265-a891-5fa315f8fccf'

        # test a zone that is between highlights
        # part-way through page 8  (xml:id = rdx_7sr72.ln.idp1066928)
        hizone = teidoc.pages[7].lines[7]
        assert_equal true, hizone.highlighted?
        annotation_data = hizone.begin_annotation_data
        assert_equal '<span class="annotator-hl" data-annotation-id="%s">' % hizone.annotation_ids[0],
            annotation_data
        assert_equal false, hizone.partially_highlighted?
        assert_equal hizone.text, hizone.annotated_text

        # all lines in this section should be highlighted
        hizone = teidoc.pages[7].lines[5]
        assert_equal true, hizone.highlighted?,
            'line between highlight anchors should be highlighted'
        assert_equal ['4c69b06c-0888-4265-a891-5fa315f8fccf'], hizone.annotation_ids
        hizone = teidoc.pages[7].lines[6]
        assert_equal true, hizone.highlighted?
        assert hizone.annotation_ids.include? '4c69b06c-0888-4265-a891-5fa315f8fccf'
        hizone = teidoc.pages[7].lines[8]
        assert_equal true, hizone.highlighted?
        assert hizone.annotation_ids.include? '4c69b06c-0888-4265-a891-5fa315f8fccf'
        hizone = teidoc.pages[7].lines[9]
        assert_equal false, hizone.highlighted?
        assert_equal true, hizone.partially_highlighted?

        # test a zone that is partially highlighted
        # part-way through page 8, two before previous (xml:id = rdx_7sr72.ln.idp1060480)
        partialhizone = teidoc.pages[7].lines[5]
        assert_equal 2, partialhizone.anchors.size
        assert_instance_of TeiAnchor, partialhizone.anchors[0]
        assert_equal true, partialhizone.partially_highlighted?
        assert_match " XIV.—In", partialhizone.anchors[0].preceding_text
        assert_match "Search of a Father,", partialhizone.anchors[0].following_text
        assert_equal '" XIV.—In <span class="annotator-hl" data-annotation-id="%s"> Search of a Father, </span> - 162' % partialhizone.anchors[0].annotation_id,
            partialhizone.annotated_text

        # test multiple, overlapping highlights
        teipagexml = Nokogiri::XML(File.open(@@teipage_fixture)) do |config|
          config.options = Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NONET
        end
        page = TeiFacsimilePage.new(teipagexml)
        # line 5, id bmst8.ln.idp19102912, is partially highlighted
        assert page.lines[4].partially_highlighted?
        assert_equal 'Elendig<span class="annotator-hl" data-annotation-id="b7905819-0bab-436c-909a-fe076b470479"> quaad, zo zeer te fchuuwen en te myden!',
            page.lines[4].annotated_text
        # line 6, id bmst8.ln.idp19105184, is fully highlighted
        assert page.lines[5].highlighted?
        assert_equal '<span class="annotator-hl" data-annotation-id="b7905819-0bab-436c-909a-fe076b470479">',
            page.lines[5].begin_annotation_data
        assert_equal '</span>', page.lines[5].end_annotation_data
        # line 7, id bmst8.ln.idp19106896, is fully highlighted
        assert page.lines[6].highlighted?
        # line 8, id bmst8.ln.idp13846640, is fully highlighted
        assert page.lines[7].highlighted?
        # line 9, id bmst8.ln.idp13849376, is fully highlighted
        assert page.lines[8].highlighted?
        # line 10, id bmst8.ln.idp13851648, is fully highlighted
        assert page.lines[9].highlighted?
        # line 11, id bmst8.ln.idp20144224, is fully highlighted AND partially highlighted
        assert page.lines[10].highlighted?
        assert page.lines[10].partially_highlighted?
        assert_equal '<span class="annotator-hl" data-annotation-id="b7905819-0bab-436c-909a-fe076b470479">',
            page.lines[10].begin_annotation_data
        assert_equal 'En <span class="annotator-hl" data-annotation-id="021e3090-d6f2-4120-ad65-690ab97d60fd">neem den vaften grond der zaligheid in',
            page.lines[10].annotated_text
        assert_equal '</span>', page.lines[10].end_annotation_data
        # line 12, id bmst8.ln.idp20147024, should be double-highlighted
        assert page.lines[11].highlighted?
        assert_equal 2, page.lines[11].annotation_ids.size
        assert_equal '<span class="annotator-hl" data-annotation-id="b7905819-0bab-436c-909a-fe076b470479"><span class="annotator-hl" data-annotation-id="021e3090-d6f2-4120-ad65-690ab97d60fd">',
            page.lines[11].begin_annotation_data
        assert_equal '</span></span>',
            page.lines[11].end_annotation_data
        # line 13, id bmst8.ln.idp20149760, double-highlighted AND partially highlighted
        assert page.lines[12].highlighted?
        assert page.lines[12].partially_highlighted?
        assert_equal 2, page.lines[12].annotation_ids.size
        assert_equal '<span class="annotator-hl" data-annotation-id="b7905819-0bab-436c-909a-fe076b470479"><span class="annotator-hl" data-annotation-id="021e3090-d6f2-4120-ad65-690ab97d60fd">',
            page.lines[12].begin_annotation_data
        assert_equal 'ó <span class="annotator-hl" data-annotation-id="7db68084-7a80-42da-a3a0-42412636ade3">Oog der Zielen ! </span>als die dingen voor u komen,',
            page.lines[12].annotated_text
        assert_equal '</span></span>',
            page.lines[12].end_annotation_data

        # line 19, id bmst8.ln.idp18545696, highlighted and partially highlighted
        assert page.lines[18].highlighted?
        assert page.lines[18].partially_highlighted?
        assert_equal '<span class="annotator-hl" data-annotation-id="b7905819-0bab-436c-909a-fe076b470479">',
            page.lines[18].begin_annotation_data
        assert_equal '
      <span class="annotator-hl" data-annotation-id="72ce2589-ccf2-49d6-bd88-9edddcf6d3b3">Maar queekt e</span>en Gulden Oogft uit zulk een',
            page.lines[18].annotated_text
        assert_equal '</span>', page.lines[18].end_annotation_data

        # last line is partially highlighted with an anchor outside the line tag
        assert page.lines[-1].partially_highlighted?
        assert_equal '<span class="annotator-hl" data-annotation-id="postlineanno1">D E</span>',
            page.lines[-1].annotated_text
    end

end