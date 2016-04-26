require 'minitest/autorun'
require 'teifacsimile_to_jekyll'

class TeiFacsimileToJekyllTest < Minitest::Test
    @@tei_fixture = File.expand_path('../fixtures/ladiesfirst.xml', __FILE__)

    def test_annotation_frontmatter
        teidoc = load_tei(@@tei_fixture)
        note = teidoc.annotations[0]
        frontmatter = TeifacsimileToJekyll.annotation_frontmatter(note)
        assert_equal note.annotation_id, frontmatter['annotation_id']
        assert_equal note.author, frontmatter['author']
        assert_equal note.target, frontmatter['tei_target']
        assert_equal note.annotated_page.id, frontmatter['annotated_page']
        assert_equal note.annotated_page.index, frontmatter['page_index']
        assert_equal note.start_target, frontmatter['target']
        # optional pieces
        assert_equal false, frontmatter.key?("tags"),
            'tags should not be set when annotation has none'
        assert_equal true, frontmatter.key?("related_pages"),
            'related pages should be set when annotation has page references'
        assert_equal false, frontmatter.key?("end_target"),
            'end target should not be set for image highlight annotations'
        assert_equal note.related_page_ids, frontmatter['related_pages']

        # annotation with tags and end target
        note = teidoc.annotations[11]
        frontmatter = TeifacsimileToJekyll.annotation_frontmatter(note)
        assert frontmatter.key?('tags'),
            'tags should be set in front matter if annotation has any'
        assert_equal note.tags, frontmatter['tags']
        assert_equal true, frontmatter.key?("end_target"),
            'end target should be set for text highlight annotations'
        assert_equal note.end_target, frontmatter['end_target']
    end

    def test_page_frontmatter
        teidoc = load_tei(@@tei_fixture)
        page = teidoc.pages[0]

        frontmatter = TeifacsimileToJekyll.page_frontmatter(page)
        assert_equal page.n.to_i, frontmatter['sort_order']
        assert_equal page.n.to_i, frontmatter['number']
        assert_equal 'Page %s' % page.n.to_i, frontmatter['title']
        assert_equal page.id, frontmatter['tei_id']
        assert_equal page.annotation_count, frontmatter['annotation_count']
        page.images.each { |img|
            assert frontmatter['images'].key?(img.rend)
            assert_equal img.url, frontmatter['images'][img.rend]
        }
        assert_equal false, frontmatter.key?('short_label'),
            'short label should not be set when start page is not specified'

        # page one specified in options, first page becomes front matter 1
        frontmatter = TeifacsimileToJekyll.page_frontmatter(page,
            {:page_one => 5})
        assert_equal '/pages/front-%s/' % page.n.to_i, frontmatter['permalink']
        assert_equal 'Front %s' % page.n.to_i, frontmatter['title']
        assert_equal 'f.', frontmatter['short_label']
        assert_equal page.n.to_i, frontmatter['number']

        # adjusted page number - new page 1
        page = teidoc.pages[4]
        frontmatter = TeifacsimileToJekyll.page_frontmatter(page,
            {:page_one => 5})
        assert_equal '/pages/1/', frontmatter['permalink']
        assert_equal 'Page 1', frontmatter['title']
        assert_equal 1, frontmatter['number']
    end


end
