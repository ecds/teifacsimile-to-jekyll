require 'fileutils'
require 'yaml'


# jekyll import logic based in part on https://gist.github.com/juniorz/1564581


# functionality for generating jekyll content from a tei facsimile
# document with annotations
class TeifacsimileToJekyll

    # jekyll volume pages directory
    @volume_page_dir = '_volume_pages'
    # jekyll annotation directory
    @annotation_dir = '_annotations'
    # jekyll config file
    @configfile = '_config.yml'

    # Generate a jekyll collection volume page with appropriate yaml
    # metadata from a TEI facsimile page and annotations
    # @param teipage [TeiPage]
    def self.output_page(teipage)
        puts "Page #{teipage.n}"
        path = File.join(@volume_page_dir, "%04d.html" % teipage.n.to_i)
        # retrieve page graphic urls by type for inclusion in front matter
        images = {}  # hash of image urls by rend attribute
        teipage.images.each { |img| images[img.rend] = img.url }
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
            # file.write "\n<img src='#{images["page"]}' />"
            file.write teipage.html()
        end
    end

    # Generate a jekyll collection annotation with appropriate yaml
    # metadata from a TEI Note
    # @param teinote [TeiNote]
    def self.output_annotation(teinote)
        puts "Annotation #{teinote.annotation_id}"
        path = File.join(@annotation_dir, "%s.md" % teinote.id)
        front_matter = {
            'annotation_id' => teinote.annotation_id,
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

    # Update jekyll site config with values from the TEI document
    # and necessary configurations for setting up jekyll collections
    # of volume pages and annotation content.
    # @param teidoc [TeiFacsimile]
    # @param configfile [String] path to existing config file to be updated
    def self.upate_site_config(teidoc, configfile)
        siteconfig = YAML.load_file(configfile)

        # set site title and subtitle from the tei
        siteconfig['title'] = teidoc.title_statement.title
        siteconfig['tagline'] = teidoc.title_statement.subtitle

        # placeholder description for author to edit (todo: include annotation author name here?)
        siteconfig['description'] = 'An annotated digital edition created with <a href="http://readux.library.emory.edu/">Readux</a>'

        # add urls to readux volume and pdf
        siteconfig['readux_url'] = teidoc.source_bibl['digital'].references['digital-edition'].target
        siteconfig['readux_pdf_url'] = teidoc.source_bibl['digital'].references['pdf'].target

        # use first page (which should be the cover) as a default splash
        # image for the home page
        siteconfig['homepage_image'] = teidoc.pages[0].images_by_type['page']

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

        File.open(configfile, 'w') do |file|
            # write out updated site config
            file.write siteconfig.to_yaml
        end
    end

    # Import TEI facsimile page and annotation content into a jekyll site
    # @param filename [String] TEI filename to be imported
    def self.import(filename)
        teidoc = load_tei(filename)

        # generate a volume page document for every facsimile page in the TEI
        puts "** Writing volume pages"
        FileUtils.rm_rf(@volume_page_dir)
        Dir.mkdir(@volume_page_dir) unless File.directory?(@volume_page_dir)
        teidoc.pages.each do |teipage|
            output_page(teipage)
        end

        # generate an annotation document for every annotation in the TEI
        puts "** Writing annotations"
        FileUtils.rm_rf(@annotation_dir)
        Dir.mkdir(@annotation_dir) unless File.directory?(@annotation_dir)
        teidoc.annotations.each do |teinote|
            output_annotation(teinote)
        end

        if File.exist?(@configfile)
            puts '** Updating site config'
            upate_site_config(teidoc, @configfile)
        end

    end
end

require 'teifacsimile_to_jekyll/tei'

