require 'fileutils'
require 'nokogiri'
require 'yaml'

# based in part on https://gist.github.com/juniorz/1564581

# usage: ruby import.rb annotated-teifacsimile.xml

TEI_NAMESPACE = "http://www.tei-c.org/ns/1.0"
$TEI_NS = {'t' => TEI_NAMESPACE}

class TeiTitleStatement
    def initialize(xmlelement)
        @el = xmlelement
    end

    def main
        return @el.at_xpath('.//t:title[@type="main"]', $TEI_NS).content
    end

    def subtitle
        return @el.at_xpath('.//t:title[@type="sub"]', $TEI_NS).content
    end
end

class TeiFacsimilePage
    def initialize(xmlelement)
        @el = xmlelement
    end

    def id
        return @el['xml:id']
    end

    def n
        return @el['n']
    end

    def images
        return @el.xpath('t:graphic', $TEI_NS)
    end

    def annotation_count
        return @el.xpath('count(.//t:anchor[@type="text-annotation-highlight-start"]
            |.//t:zone[@type="image-annotation-highlight"])', $TEI_NS).to_i
    end
end

class TeiNote
    def initialize(xmlelement)
        @el = xmlelement
    end

    def id
        return @el['xml:id']
    end

    def author
        return @el['resp']
    end

    def target
        return @el['target']
    end

    def start_target
        return @start_target
    end

    def end_target
        return @end_target
    end

    def range_target?
        return self.target.start_with?('#range')
    end

    def annotated_page
        # find the page that is annotated by this note
        if self.range_target?
            # text selections are stored in tei like
            # #range(#start_id, #end_id)
            target = self.target.gsub(/(^#range\(|\)$)/, '')
            @start_target, @end_target = target.split(', ')
            @start_target.gsub!(/^#/, '')
            @end_target.gsub!(/^#/, '')
        else
            # target ref format is #id; strip out # to get xml:id
            @start_target = self.target.gsub(/^#/, '')
        end

        # find the page that contains the annotation reference
        @annotated_page = TeiFacsimilePage.new(@el.at_xpath('//t:surface[@type="page"][.//*[@xml:id="%s"]]' % @start_target, $TEI_NS))

        return @annotated_page
    end

    def markdown
        md = @el.at_xpath('.//t:code[@lang="markdown"]', $TEI_NS)
        return md.content unless md.nil?
    end

end

class TeiBibl
    def initialize(el)
        @el = el
    end

    def type
        @el['type']
    end

    def title
        el = @el.at_xpath('t:title', $TEI_NS)
        return el.content unless el.nil?
    end

    def date
        el = @el.at_xpath('t:date', $TEI_NS)
        return el.content unless el.nil?
    end

    def author
        el = @el.at_xpath('t:author', $TEI_NS)
        return el.content unless el.nil?
    end

    def references
        @refs = {}
        @el.xpath('tei:ref').each do |ref|
            @refs[ref['type']] = ref['target']
        end
        return @refs
    end
end

class TeiFacsimile
    def initialize(xmldoc)
        @xmldoc = xmldoc
    end

    def title
        @title = TeiTitleStatement.new(@xmldoc.at_xpath('//t:teiHeader/t:fileDesc/t:titleStmt',
            $TEI_NS))
        return @title
    end

    def source_bibl
        @bibl = {}
        @xmldoc.xpath('//t:teiHeader/t:fileDesc/t:sourceDesc/t:bibl', $TEI_NS).each do |el|
            @bibl[el['type']] = TeiBibl.new(el)
        end
        return @bibl
    end

    def pages
        @pages = []
        @xmldoc.xpath('//t:facsimile/t:surface[@type="page"]', $TEI_NS).each do |teipage|
            @pages << TeiFacsimilePage.new(teipage)
        end
        return @pages
    end

    def annotations
        @annotations = []
        @xmldoc.xpath('//t:note[@type="annotation"]', $TEI_NS).each do |note|
            @annotations << TeiNote.new(note)
        end
        return @annotations
    end

end

teixml = File.open(ARGV[0]) { |f| Nokogiri::XML(f) }
teidoc = TeiFacsimile.new(teixml)

$volume_page_dir = '_volume_pages'
$annotation_dir = '_annotations'


def output_page(teipage)
    puts "Page #{teipage.n}"
    path = File.join($volume_page_dir, "%04d.html" % teipage.n)
    # retrieve page graphic urls by type for inclusion in front matter
    images = {}  # hash of image urls by rend attribute
    teipage.images.each { |img| images[img['rend']] = img['url'] }
    # construct page front matter
    front_matter = {
        'title'=> 'Page %s' % teipage.n,
        'page_order'=> teipage.n.to_i,
        'tei_id' => teipage.id,
        'annotation_count' => teipage.annotation_count,
        'images' => images
    }

    File.open(path, 'w') do |file|
        # write out front matter as yaml
        file.write front_matter.to_yaml
        file.write  "\n---"
        # todo: unique page content that can't be handled by template
        # (should be primarily tei text and annotation references)
        file.write "\n<img src='#{images["page"]}' />"
    end
end

def output_annotation(teinote)
    puts "Annotation #{teinote.id}"
    path = File.join($annotation_dir, "%s.md" % teinote.id)
    front_matter = {
        'annotation_id' => teinote.id,
        'author' => teinote.author,
        'tei_target' => teinote.target,
        'annotated_page' => teinote.annotated_page.id,
        'target' => teinote.start_target
    }
    if teinote.range_target?
        front_matter['end_target'] = teinote.end_target
    end

    File.open(path, 'w') do |file|
        # write out front matter as yaml
        file.write front_matter.to_yaml
        file.write  "\n---\n"
        # annotation content
        file.write teinote.markdown

    end

end

# puts teidoc.xpath('//tei:facsimile/tei:surface[@type="page"]')



# generate a volume page document for every facsimile page in the TEI
puts "** Writing volume pages"
FileUtils.rm_rf($volume_page_dir)
Dir.mkdir($volume_page_dir) unless File.directory?($volume_page_dir)
teidoc.pages.each do |teipage|
    output_page(teipage)
end

# generate an annotation document for every annotation in the TEI
puts "** Writing annotations"
FileUtils.rm_rf($annotation_dir)
Dir.mkdir($annotation_dir) unless File.directory?($annotation_dir)

teidoc.annotations.each do |teinote|
    output_annotation(teinote)
end


puts '** Updating site config'
if File.exist?('_config.yml')
    siteconfig = YAML.load_file('_config.yml')

    # set site title and subtitle from the tei
    siteconfig['title'] = teidoc.title.main
    siteconfig['tagline'] = teidoc.title.subtitle

    # placeholder description for author to edit (todo: include annotation author name here?)
    siteconfig['description'] = 'An annotated digital edition created with <a href="http://readux.library.emory.edu/">Readux</a>'

    # add urls to readux volume and pdf
    siteconfig['readux_url'] = teidoc.source_bibl['digital'].references['digital-edition']
    siteconfig['readux_pdf_url'] = teidoc.source_bibl['digital'].references['pdf']

    # add original publication information
    original = teidoc.source_bibl['original']
    pubinfo = {'title' => original.title, 'author' => original.author,
        'date' => original.date}

    # configure collections specific to tei facsimile + annotation data
    siteconfig.merge!({
        'publication_info' => pubinfo,
        'collections' => {
            # NOTE: annotations *must* come first, so content can
            # be rendered for display in volume pages templates
            'annotations' => {
                'output' => false
            },
            'volume_pages' => {
                'output' => true,
                'permalink' => '/pages/:path/'
            },
        },
        'defaults' => {
           'scope' => {
                'path' => '',
                'type' => 'volume_pages',
            },
            'values' => {
                'layout' => 'volume_pages'
            }
          }
    })
    # TODO:
    # - author information from resp statement?

    File.open('_config.yml', 'w') do |file|
        # write out updated site config
        file.write siteconfig.to_yaml
    end
end

