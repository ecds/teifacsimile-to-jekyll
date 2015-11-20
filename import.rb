require 'fileutils'
require 'nokogiri'
require 'yaml'

# based in part on https://gist.github.com/juniorz/1564581

# usage: ruby import.rb annotated-teifacsimile.xml
puts ARGV[0]

teidoc = File.open(ARGV[0]) { |f| Nokogiri::XML(f) }
$tei_namespace = "http://www.tei-c.org/ns/1.0"
$volume_page_dir = '_volume_pages'
$annotation_dir = '_annotations'

def output_page(teipage)
    puts "Page #{teipage['n']}"
    path = File.join($volume_page_dir, "%04d.html" % teipage['n'])
    # page front matter
    front_matter = {
        # 'layout' => 'volume_page',  # NOTE: may be able to set a default in site config
        'title'=> 'Page %s' % teipage['n'],
        'page_order'=> teipage['n'].to_i,
        'tei_id' => teipage['xml:id']
    }
    puts front_matter

    # retrieve page graphic urls by type and add to front matter
    graphics = teipage.xpath('tei:graphic', 'tei' => $tei_namespace)
    images = {}  # hash of image urls by rend attribute
    graphics.each { |graphic| images[graphic['rend']] = graphic['url'] }
    # add image urls to front matter as well
    front_matter['images'] = images

    count = teipage.xpath('count(.//tei:anchor[@type="text-annotation-highlight-start"]|.//tei:zone[@type="image-annotation-highlight"])')
    front_matter['annotation_count'] = count.to_i
    puts front_matter.to_yaml
    # TODO: pull out graphic details
    # 'thumbnail': teipage['thumbnail']['url'],
    # 'small_thumbnail': teipage['thumbnail']['url'],

    File.open(path, 'w') do |file|
        # write out front matter as yaml
        file.write front_matter.to_yaml
        file.write  "\n---"
        # todo: unique page content that can't be handled by template
        # (should be primarily tei text and annotation references)
        file.write "\n<img src='#{images["page"]}' />"
    end
end

def output_annotation(teinote, teidoc)
    puts "Annotation #{teinote['xml:id']}"
    path = File.join($annotation_dir, "%s.html" % teinote['xml:id'])
    puts 'annotation file is ', path
    front_matter = {
        'annotation_id' => teinote['xml:id'],
        'author' => teinote['resp'],
        'tei_target' => teinote['target'],
    }
    # TODO: check for tags and add to front matter
    # determine which page is being annotated
    puts teinote['target']
    if teinote['target'].start_with?('#range')
        # text selections are stored in tei like
        # #range(#start_id, #end_id)
        puts 'range target'
        target = teinote['target'].gsub(/(^#range\(|\)$)/, '')
        # target = teinote['target'].sub('#range(', '').sub(')', '')
        puts target
        start_target, end_target = target.split(', ')
        puts 'start = %s' % start_target.gsub!(/^#/, '')
        puts 'end  = %s' % end_target.gsub!(/^#/, '')
        front_matter.merge!({'target' => start_target, 'end_target'=> end_target})
        target_id = start_target
    else
        # target ref format is #id; strip out # to get xml:id
        target_id = teinote['target'].gsub(/^#/, '')
        front_matter['target'] = target_id
    end

    # find the id of page that contains the annotation reference
    xpath = '//tei:surface[@type="page"][.//*[@xml:id="%s"]]' % target_id
    # teipage = teidoc.xpath(xpath).first()
    teipage = teinote.at_xpath(xpath)
    front_matter['annotated_page'] = teipage['xml:id']
    # get the content as markdown, for easier display
    markdown = teinote.at_xpath('.//tei:code[@lang="markdown"]',
        'tei' => $tei_namespace)

    File.open(path, 'w') do |file|
        # write out front matter as yaml
        file.write front_matter.to_yaml
        file.write  "\n---\n"
        # annotation content
        file.write markdown.content

    end

end

# puts teidoc.xpath('//tei:facsimile/tei:surface[@type="page"]')

# generate a volume page document for every facsimile page in the TEI
puts "** Writing volume pages"
FileUtils.rm_rf($volume_page_dir)
Dir.mkdir($volume_page_dir) unless File.directory?($volume_page_dir)
teidoc.xpath('//tei:facsimile/tei:surface[@type="page"]',
                            'tei' => $tei_namespace).each do |teipage|
    puts "%s %s" % [teipage['xml:id'], teipage['n']]
    output_page(teipage)
end

# generate an annotation document for every annotation in the TEI
puts "** Writing annotations"
FileUtils.rm_rf($annotation_dir)
Dir.mkdir($annotation_dir) unless File.directory?($annotation_dir)

teidoc.xpath('//tei:note[@type="annotation"]',
             'tei' => $tei_namespace).each do |teinote|
    output_annotation(teinote, teidoc)
end


puts '** Updating site config'
if File.exist?('_config.yml')
    siteconfig = YAML.load_file('_config.yml')

    # set site title and subtitle from the tei
    title_statement = teidoc.xpath('//tei:teiHeader/tei:fileDesc/tei:titleStmt',
        'tei' => $tei_namespace)
    title = title_statement.at_xpath('//tei:title[@type="main"]', 'tei' => $tei_namespace)
    siteconfig['title'] = title.content
    subtitle = title_statement.at_xpath('//tei:title[@type="sub"]', 'tei' => $tei_namespace)
    siteconfig['tagline'] = subtitle.content

    # placeholder description for author to edit (todo: include annotation author name here?)
    siteconfig['description'] = 'An annotated digital edition created with <a href="http://readux.library.emory.edu/">Readux</a>'

    # add urls to readux volume and pdf
    digital_bibl = teidoc.at_xpath('//tei:sourceDesc/tei:bibl[@type="digital"]')
    digital_edition = digital_bibl.at_xpath('tei:ref[@type="digital-edition"]')
    pdf = digital_bibl.at_xpath('tei:ref[@type="pdf"]')
    siteconfig['readux_url'] = digital_edition['target']
    siteconfig['readux_pdf_url'] = pdf['target']

    # configure collections specific to tei facsimile + annotation data
    siteconfig.merge!({
        'collections' => {
            'volume_pages' => {
                'output' => true,
                'permalink' => '/pages/:path/'
            },
            'annotations' => {
                'output' => false
            }
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

# todo: placeholder pages for introduction, credits
# perhaps easier to fork lanyon theme?
