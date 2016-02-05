require 'date'
require 'fileutils'
require 'yaml'
require 'fastimage'


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
    # jekyll data dir
    @data_dir = '_data'
    # tags data file
    @tagfile = File.join(@data_dir, 'tags.yml')
    # directory where tag stub pages should be created
    @tag_dir = 'tags'

    # Generate a jekyll collection volume page with appropriate yaml
    # metadata from a TEI facsimile page and annotations
    # @param teipage [TeiPage]
    def self.output_page(teipage, opts={})
        puts "Page #{teipage.n}" unless opts[:quiet]
        # by default, use page number from the tei
        page_number = teipage.n.to_i
        path = File.join(@volume_page_dir, "%04d.html" % teipage.n.to_i)
        # retrieve page graphic urls by type for inclusion in front matter
        images = {}  # hash of image urls by rend attribute
        teipage.images.each { |img| images[img.rend] = img.url }
        # construct page front matter
        front_matter = {
            'sort_order'=> page_number,
            'tei_id' => teipage.id,
            'annotation_count' => teipage.annotation_count,
            'images' => images,
            'title'=> 'Page %s' % page_number,
            'number' => page_number
        }

        # if an override start page is set, adjust the labels and set an
        # override url
        if opts[:page_one]
            if page_number < opts[:page_one]
                # pages before the start page will be output as front-#
                permalink = '/pages/front-%s/' % page_number
                front_matter['title'] = 'Front %s' % page_number
                front_matter['short_label'] = 'f.'
                front_matter['number'] = page_number
            else
                # otherwise, offset by requested start page (1-based counting)
                adjusted_number = page_number - opts[:page_one] + 1
                permalink = '/pages/%s/' % adjusted_number
                front_matter['title'] = 'Page %s' % adjusted_number
                # default short label configured as p.
                front_matter['number'] = adjusted_number
            end

            front_matter['permalink'] = permalink
        end


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
    def self.output_annotation(teinote, opts={})
        puts "Annotation #{teinote.annotation_id}" unless opts[:quiet]
        if teinote.annotated_page.nil?
            puts 'Error: annotated page not found'
            return
        end

        path = File.join(@annotation_dir, "%s.md" % teinote.id)
        front_matter = {
            'annotation_id' => teinote.annotation_id,
            'author' => teinote.author,
            'tei_target' => teinote.target,
            'annotated_page' => teinote.annotated_page.id,
            'page_index' => teinote.annotated_page.index,
            'target' => teinote.start_target,
        }
        if teinote.tags
            front_matter['tags'] = teinote.tags
        end

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

    def self.output_tags(tags, opts={})
        puts "** Generating tags" unless opts[:quiet]
        # create data dir if not already present
        Dir.mkdir(@data_dir) unless File.directory?(@data_dir)
        tag_data = {}
        # create a jekyll data file with tag data
        # structure tag data for lookup by slug, with a name attribute
        tags.each do |tag, interp|
            tag_data[tag] = {'name' => interp.value}
        end

        File.open(@tagfile, 'w') do |file|
            file.write tag_data.to_yaml
        end

        # Create a tag stub file for each tag
        # create tag dir if not already present
        Dir.mkdir(@tag_dir) unless File.directory?(@tag_dir)
        tags.each do |tag, interp|
            puts "Tag #{tag}" unless opts[:quiet]
            @tagfile =
            File.open(File.join(@tag_dir, "#{tag}.md"), 'w') do |file|
                front_matter = {
                    'layout' => 'annotation_by_tag',
                    'tag' => tag
                }
                file.write front_matter.to_yaml
                file.write  "\n---\n"
            end
        end

    end

    # Update jekyll site config with values from the TEI document
    # and necessary configurations for setting up jekyll collections
    # of volume pages and annotation content.
    # @param teidoc [TeiFacsimile]
    # @param configfile [String] path to existing config file to be updated
    def self.update_site_config(teidoc, configfile, opts={})
        siteconfig = YAML.load_file(configfile)

        # set site title and subtitle from the tei
        siteconfig['title'] = teidoc.title_statement.title
        siteconfig['tagline'] = teidoc.title_statement.subtitle

        # placeholder description for author to edit (todo: include annotation author name here?)
        siteconfig['description'] = 'An annotated digital edition created with <a href="http://readux.library.emory.edu/">Readux</a>'

        # add urls to readux volume and pdf

        # use first page (which should be the cover) as a default splash
        # image for the home page
        siteconfig['homepage_image'] = teidoc.pages[0].images_by_type['page'].url

        # add image dimensions to config so that thumbnail display can be tailored
        # to the current volume page size
        thumbnail_width, thumbnail_height = FastImage.size(teidoc.pages[0].images_by_type['thumbnail'].url)
        sm_thumbnail_width, sm_thumbnail_height = FastImage.size(teidoc.pages[0].images_by_type['small-thumbnail'].url)
        page_img_width, page_img_height = FastImage.size(teidoc.pages[0].images_by_type['page'].url)
        siteconfig['image_size'] = {
            'page' => {'width' => page_img_width, 'height' => page_img_height},
            'thumbnail' => {'width' => thumbnail_width, 'height' => thumbnail_height},
            'small-thumbnail' => {'width' => sm_thumbnail_width, 'height' => sm_thumbnail_height}
        }

        # add source publication information, including
        # urls to volume and pdf on readux
        original = teidoc.source_bibl['original']
        source_info = {'title' => original.title, 'author' => original.author,
            'date' => original.date,
            'url' => teidoc.source_bibl['digital'].references['digital-edition'].target,
            'pdf_url' => teidoc.source_bibl['digital'].references['pdf'].target,
            'via_readux' => true}

        # preliminary publication information for the annotated edition
        pub_info = {'title' => teidoc.title_statement.title + teidoc.title_statement.subtitle,
            'date' => Date.today.strftime("%Y"), # current year
            'author' => original.author,
            'editors' => [],
        }
        # add a reference to the tei xml, for display
        if opts.has_key?('tei_filename')
            pub_info['tei_xml'] = opts['tei_filename']
        end

        # add all annotator names to the document as editors
        # of the annotated edition; use username if name is empty
        teidoc.resp.each do |resp, name|
            pub_info['editors']  << (name.value != '' ? name.value : resp)
        end

        # configure collections specific to tei facsimile + annotation data
        siteconfig.merge!({
            'source_info' => source_info,
            'publication_info' => pub_info,
            'collections' => {
                # NOTE: annotations *must* come first, so content can
                # be rendered for display in volume pages templates
                'annotations' => {
                    'output' => true
                },
                'volume_pages' => {
                    'output' => true,
                    'permalink' => '/pages/:path/'
                },
            },
            'defaults' => [{
               'scope' => {
                    'path' => '',
                    'type' => 'volume_pages',
                },
                'values' => {
                    'layout' => 'volume_page',
                    'short_label' => 'p.',
                    'extra_js' => ['deepzoom.js', 'openseadragon.min.js',
                        'volume-page.js', 'hammer.min.js']
                }
              }]
        })
        # TODO:
        # - author information from resp statement?

        # NOTE: this generates a config file without any comments,
        # and removes existing comments - which is not very user-friendly;
        # look into generating/updating config with comments

        File.open(configfile, 'w') do |file|
            # write out updated site config
            file.write siteconfig.to_yaml
        end
    end

    # Import TEI facsimile page and annotation content into a jekyll site
    # @param filename [String] TEI filename to be imported
    def self.import(filename, opts={})
        teidoc = load_tei(filename)

        # generate a volume page document for every facsimile page in the TEI
        puts "** Writing volume pages" unless opts[:quiet]
        FileUtils.rm_rf(@volume_page_dir)
        Dir.mkdir(@volume_page_dir) unless File.directory?(@volume_page_dir)
        teidoc.pages.each do |teipage|
            output_page(teipage, **opts)
        end

        # generate an annotation document for every annotation in the TEI
        puts "** Writing annotations" unless opts[:quiet]
        FileUtils.rm_rf(@annotation_dir)
        Dir.mkdir(@annotation_dir) unless File.directory?(@annotation_dir)
        teidoc.annotations.each do |teinote|
            output_annotation(teinote, **opts)
        end

        output_tags(teidoc.tags, **opts)

        # copy annotated tei into jekyll site
        opts['tei_filename'] = 'tei.xml'
        FileUtils.copy_file(filename, opts['tei_filename'])

        if File.exist?(@configfile)
            puts '** Updating site config' unless opts[:quiet]
            update_site_config(teidoc, @configfile, opts)
        end


    end
end

require 'teifacsimile_to_jekyll/tei'

