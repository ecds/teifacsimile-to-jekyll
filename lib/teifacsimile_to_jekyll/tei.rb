require 'fileutils'
require 'nokogiri'
require 'erb'


# TEI namespace
TEI_NAMESPACE = "http://www.tei-c.org/ns/1.0"
$TEI_NS = {'t' => TEI_NAMESPACE}


# TODO: convert :list option to :array

# simple class for more object-oriented and readable access
# to reading xml
class XmlObject
    attr_accessor :el

    # Initialize a new XmlObject from parsed xml
    # @param xmlelement [Nokogiri::XML::Document]
    def initialize(xmlelement)
        @el = xmlelement
    end


    # xpath namespaces; when extending, set namespaces for use in
    # attribute accessor xpaths
    def xpath_ns
        {}
    end

    # convert xml element to the configured type; currently
    # supports Integer, Float; uses element content, if present
    def convert_el(el, opts = {})
        if el == nil
            return nil
        end

        if opts[:as]
            opts[:as].new(el)
        else
            if defined? el.content
                content = el.content
            else
                content = el
            end

            if opts[:type] == Integer
                content.to_i
            elsif opts[:type] == Float
                content.to_f
            else
                content
            end
        end
    end

    # xml attribute reader for simple, object-oriented access to xml data
    # @param attr_name property name to be used for access
    # @param opts [Hash] options for configuring the property
    # @option opts [String] :xpath xpath for selecting content from the document
    # @option opts [Boolean] :list set True for a list of results
    # @option opts [Boolean] :hash set True for Hash of results; requires
    #    :hash_key_xpath
    # @option opts [String] :hash_key_xpath relative xpath for determining
    #    hash keys, when hash return is configured
    # @option opts [Type] :type conversion type, currently supports Integer, Float
    def self.xml_attr_reader(attr_name, opts = {})
        attr_name = attr_name.to_s
        define_method(attr_name) do
            els = @el.xpath(opts[:xpath], self.xpath_ns)
            if opts[:list]
                content = []
                els.each do |el|
                    content << self.convert_el(el, opts)
                end
                return content
            elsif opts[:hash] and opts[:hash_key_xpath]
                content = {}
                els.each do |el|
                    hash_key = self.convert_el(el.at_xpath(opts[:hash_key_xpath]))
                    content[hash_key] =self.convert_el(el, opts)
                end
                return content
            else
                # some xpaths return a list, but others
                # (like count) just return a value;
                # handling here to avoid complication with hash key results
                # in convert_el method
                if defined? els.first
                    el = els.first()
                else
                    el = els
                end
                self.convert_el(el, opts)
            end
        end
    end

end

# Base TEI xmlobject class with TEI namespace defined
class TeiXmlObject < XmlObject
    def xpath_ns
        $TEI_NS
    end
end

# TEI title statement
class TeiTitleStatement < TeiXmlObject
    # @!attribute title
    #   @return [String] main title
    xml_attr_reader :title, :xpath => './/t:title[@type="main"]'
    # @!attribute subtitle
    #   @return [String] sub title
    xml_attr_reader :subtitle, :xpath => './/t:title[@type="sub"]'
end

# TEI reference
class TeiRef < TeiXmlObject
    # @!attribute type
    #   @return [String]
    xml_attr_reader :type, :xpath => '@type'
    # @!attribute target
    #   @return [String] target url
    xml_attr_reader :target, :xpath => '@target'
end

# Bibliographic source
class TeiBibl < TeiXmlObject
    # @!attribute type
    #   @return [String]
    xml_attr_reader :type, :xpath => '@type'
    # @!attribute title
    #   @return [String]
    xml_attr_reader :title, :xpath => 't:title'
    # @!attribute date
    #   @return [String]
    xml_attr_reader :date, :xpath => 't:date'
    # @!attribute author
    #   @return [String]
    xml_attr_reader :author, :xpath => 't:author'
    # @!attribute references
    #   @return [Hash] references, keyed on type
    xml_attr_reader :references, :xpath => 't:ref', :as => TeiRef, :hash => true,
        :hash_key_xpath => '@type'
end

# Graphic element
class TeiGraphic < TeiXmlObject
    # @!attribute rend
    #   @return [String] rend attribute
    xml_attr_reader :rend, :xpath => '@rend'
    # @!attribute url
    #   @return [String]
    xml_attr_reader :url, :xpath => '@url'
end

class TeiAnchor < TeiXmlObject
    # @!attribute id
    #   @return [String]
    xml_attr_reader :id, :xpath => '@xml:id'
    # @!attribute type
    #   @return [String]
    xml_attr_reader :type, :xpath => '@type'

    xml_attr_reader :preceding_text, :xpath => 'preceding-sibling::text()[last()]'
    xml_attr_reader :following_text, :xpath => '(following-sibling::text()|following-sibling::t:line/text())[1]'

    # associated annotation id, for image-annotation-highlight zones
    def annotation_id
        if ['text-annotation-highlight-start',
            'text-annotation-highlight-end'].include? self.type
            self.id.gsub(/^highlight-(start|end)-/, '')
        end
    end

    def to_s
        "#<TeiAnchor id=#{self.id}>"
    end

end

# TEI Zone
class TeiZone < TeiXmlObject
    # @!attribute id
    #   @return [String]
    xml_attr_reader :id, :xpath => '@xml:id'
    # @!attribute n
    #   @return [String]
    xml_attr_reader :n, :xpath => '@n'
    # @!attribute type
    #   @return [String]
    xml_attr_reader :type, :xpath => '@type'
    # @!attribute ulx
    #   @return [Float] upper left x coordinate
    xml_attr_reader :ulx, :xpath => '@ulx', :type => Float
    # @!attribute uly
    #   @return [Float] upper left y coordinate
    xml_attr_reader :uly, :xpath => '@uly', :type => Float
    # @!attribute lrx
    #   @return [Float] lower right x coordinate
    xml_attr_reader :lrx, :xpath => '@lrx', :type => Float
    # @!attribute lry
    #   @return [Float] lower right y coordinate
    xml_attr_reader :lry, :xpath => '@lry', :type => Float
    # @!attribute href
    #   @return [String]
    xml_attr_reader :href, :xpath => '@xlink:href'  # maybe not needed?
    # @!attribute text
    #   @return [String] text content
    xml_attr_reader :text, :xpath => 't:line|t:w'
    # @!attribute word_zones
    #   @return [Array#TeiZone] list of word zones within this zone
    xml_attr_reader :word_zones, :xpath => './/t:zone[@type="string"]',
        :as => TeiZone, :list => true

    # @!attribute parent
    #   @return [TeiZone] immediate ancestor zone
    xml_attr_reader :parent, :xpath => 'ancestor::t:zone[1]', :as => TeiZone
    # @!attribute page
    #   @return [TeiZone] parent page as TeiZone
    xml_attr_reader :page, :xpath => 'ancestor::t:surface[@type="page"]',
        :as => TeiZone
    # not exactly a zone, but same attributes we care about (type, id, ulx/y, lrx/y)

    # @!attribute preceding_start_anchors
    #   @return [List#TeiAnchor] all highlight start anchors before this zone
    xml_attr_reader :preceding_start_anchors,
        :xpath => '(t:w/preceding::t:anchor|preceding::t:anchor)' + \
                '[@type="text-annotation-highlight-start"]',
        :as => TeiAnchor, :list => true

    # @!attribute following_end_anchors
    #   @return [List#TeiAnchor] all highlight end anchors after this zone
    xml_attr_reader :following_end_anchors,
        :xpath => '(t:w/following::t:anchor|following::t:anchor)' + \
                '[@type="text-annotation-highlight-end"]',
        :as => TeiAnchor, :list => true

    # @!attribute anchors
    #   @return [List#TeiAnchor] anchors inside this zone
    xml_attr_reader :anchors, :xpath => './/t:anchor', :as => TeiAnchor,
        :list => true

    # zone width
    def width
        self.lrx - self.ulx
    end

    # zone height
    def height
        self.lry - self.uly
    end

    # average height
    def avg_height
        '''Calculated average height of word zones in the current zone
        (i.e. in a text line)'''
        unless self.word_zones.empty?
            word_heights = []
            self.word_zones.each do |w|
                word_heights << w.height
            end
            return word_heights.inject{ |sum, el| sum + el }.to_f / word_heights.size
        end
    end

    # size of the longer edge of this zone
    def long_edge
        # return the size of the longer edge of this zone
        [self.width, self.height].max
    end

    # single page size
    # FIXME: should be configured somewhere
    # (we happen to know this is current readux full page size...)
    SINGLE_PAGE_SIZE = 1000


    # generate html style and data attributes to position
    # the ocr text based on coordinates in the TEI
    # (logic adapted from readux)
    def css_style()
        styles = {}
        data = {}
        # determine scale from original page size to current display size,
        # for non-relative styles (i.e. font sizes)
        scale = SINGLE_PAGE_SIZE.to_f / self.page.long_edge.to_f

        # utility method for generating percents for display in
        # css styles
        def percent(a, b)
            # a as percentage of b
            # ensure both are cast to float, divide, then multiply by 100
            return (a.to_f / b.to_f) * 100
        end

        if ['textLine', 'line'].include? self.type
            # text lines are absolutely positioned boxes
            styles['left'] = '%.2f%%' % percent(self.ulx, self.page.width)
            styles['top'] = '%.2f%%' % percent(self.uly, self.page.height)

            # width relative to page size
            styles['width'] = '%.2f%%' % percent(self.width, self.page.width)
            styles['height'] = '%.2f%%' % percent(self.height, self.page.height)

            # TODO: figure out how to determine this from ocr/teifacsimile
            # rather than assuming
            styles['text-align'] = 'left'

            # set pixel-based font size for browsers that don't support viewport based sizes.
            # for mets-alto, use average height of words in the line to calculate font size
            # for abbyy ocr, no word zones exist, so just use line height
            styles['font-size'] = '%.2fpx' % ((self.avg_height || self.height) * scale)

            # calculate font size as percentage of page height;
            # this will be used by javascript to calculate as % of viewport height
            data['vhfontsize'] = '%.2f' % percent(self.lry - self.uly, self.page.height)

        elsif self.type == 'string'
            # set width & height relative to *parent* line, not the whole page
            styles['width'] = '%.2f%%' % percent(self.width, self.parent.width)
            styles['height'] = '%.2f%%' % percent(self.height, self.parent.height)

            # position words absolutely within the line
            styles['left'] = '%.2f%%' % percent(self.ulx - self.parent.ulx, self.parent.width)

        elsif self.type == 'image-annotation-highlight'
            # image annotation zone; similar to line logic, but without font calculations

            # image highlights are absolutely positioned boxes
            styles['left'] = '%.2f%%' % percent(self.ulx, self.page.width)
            styles['top'] = '%.2f%%' % percent(self.uly, self.page.height)

            # size relative to page size
            styles['width'] = '%.2f%%' % percent(self.width, self.page.width)
            styles['height'] = '%.2f%%' % percent(self.height, self.page.height)

        end

        # construct html style and data attribute string
        attrs = ''
        unless styles.empty?
            attrs += 'style="%s"' % styles.map { |k, v| "#{k}:#{v}"}.join(';')
        end
        unless data.empty?
            attrs += ' ' + data.map { |k, v | "data-#{k}=\"#{v}\""}.join(' ')
        end

        return attrs
    end

    # associated annotation id, for image-annotation-highlight zones
    def annotation_id
        if self.type == 'image-annotation-highlight'
            self.id.gsub(/^highlight-/, '')
        elsif self.highlighted?
            # FIXME: might be surprising to return a list here...
            self.annotation_ids
        end
    end

    # ids for all highlight start anchors that come before this zone
    def preceding_start_anchor_ids
        ids = []
        self.preceding_start_anchors.each do |anchor|
            ids << anchor.annotation_id
        end
        return ids
    end

    # ids for all highlight end anchors that come after this zone
    def following_end_anchor_ids
        ids = []
        self.following_end_anchors.each do |anchor|
            ids << anchor.annotation_id
        end
        return ids
    end

    # ids for any annotations that cover this zone
    # calculated by checking for matches in preceding start and following
    # end annotation ids
    def annotation_ids
        # annotation ids for any start/end text highlights that cover this zone
        self.preceding_start_anchor_ids & self.following_end_anchor_ids
    end

    # check if the current zone should be highlighted, based on whether
    # it falls between any matching start and end highlight anchor tags
    def highlighted?
        if self.annotation_ids.empty?
            return false
        else
            return true
        end
    end

    # if this zone is fully included within one or more text annotations,
    # return html tags needed to associate it with the appropriate annotations
    def begin_annotation_data
        tags = ''
        # multiple highlights are handled with nested span tags
        if self.highlighted?
            for id in self.annotation_ids
                tags += '<span class="annotator-hl" data-annotation-id="%s">' % id
            end
            tags
        else
            # text should be wrapped in a single span, even if there is no
            # annotation data needed
            '<span>'
        end
    end

    def end_annotation_data
        tags = ''
        # multiple highlights are handled with nested span tags
        if self.highlighted?
            for id in self.annotation_ids
                tags += '</span>'
            end
            tags
        else
            '</span>'
        end
    end

    # check if this zone is partially highlighted
    # (one or more anchors fall inside the text content of the zone)
    def partially_highlighted?
        return self.anchors.size > 0
    end

    # output text for this zone with span markers for any partial
    # highlights included within the text
    def annotated_text
        if self.partially_highlighted?
            text = ''
            # if text is partially highlighted, loop through anchors
            # and output text relative to them
            self.anchors.each_with_index do |anchor, index|
                # leading text before any annotation anchor
                if index == 0
                    # if first anchor is an end, create an annotation start
                    if anchor.type == 'text-annotation-highlight-end'
                        text << "<span class=\"annotator-hl\" data-annotation-id=\"#{anchor.annotation_id}\">"
                    end
                    # text before the first anchor, if any
                    if anchor.preceding_text
                        text << anchor.preceding_text
                    end
                end
                # start or end an annotation highlight as appropriate
                if anchor.type == 'text-annotation-highlight-start'
                    text << "<span class=\"annotator-hl\" data-annotation-id=\"#{anchor.annotation_id}\">"
                elsif anchor.type == 'text-annotation-highlight-end'
                    text << "</span>"
                end
                # text after the anchor, if any
                if anchor.following_text
                    text << anchor.following_text
                end
            end
            text
        else
            self.text
        end
    end

end

# Single page of a TEI facsimile
class TeiFacsimilePage < TeiXmlObject
    # @!attribute id
    #   @return [String]
    xml_attr_reader :id, :xpath => '@xml:id'
    # @!attribute n
    #   @return [String]
    xml_attr_reader :n, :xpath => '@n'
    # @!attribute images
    #   @return [List#TeiGraphic]
    xml_attr_reader :images, :xpath => 't:graphic', :list => true,
        :as => TeiGraphic

    # @!attribute images_by_type
    #   @return [Hash#TeiGraphic] images as a hash, keyed on rend attribute
    xml_attr_reader :images_by_type, :xpath => 't:graphic', :hash => true,
        :as => TeiGraphic, :hash_key_xpath => '@rend'

    # @!attribute annotation_count
    #   @return [Integer] number of annotations on this page
    xml_attr_reader :annotation_count, :type => Integer,
        :xpath => 'count(.//t:anchor[@type="text-annotation-highlight-start"]
            |.//t:zone[@type="image-annotation-highlight"])'

    # @!attribute lines
    #   @return [List#TeiZone] text line zones
    xml_attr_reader :lines, :xpath => './/t:zone[@type="textLine" or @type="line"]',
        :as => TeiZone, :list => true

    # @!attribute word_zones
    #   @return [List#TeiZone] text word zones
    xml_attr_reader :word_zones, :xpath => './/t:zone[@type="string"]',
        :as => TeiZone, :list => true

    # @!attribute image_highlight_zones
    #   @return [List#TeiZone] zones for image annotation highlights
    xml_attr_reader :image_highlight_zones, :xpath => 't:zone[@type="image-annotation-highlight"]',
        :as => TeiZone, :list => true

    # template to position ocr text over the image
    # (logic adapted from readux)
    def template()
        # template to position ocr text over the image
        # - logic adapted from readux
        # TODO: pull template out into a separate file?
        %{
        <% for line in self.lines %>
        <div class="ocr-line <% if line.word_zones.empty? %>ocrtext<% end %>" <% if line.id %>id="<%= line.id %>"<% end %>
            <%= line.css_style %>>
            <% for zone in line.word_zones %>
            <div class="ocr-zone ocrtext" <%= zone.css_style %>>
               <%= zone.begin_annotation_data %>{% raw %}<%= zone.annotated_text %>{% endraw %}<%= zone.end_annotation_data %>
            </div>
            <% end %>
            <% if line.word_zones.empty?  %>
               <%= line.begin_annotation_data %>{% raw %}<%= line.annotated_text %>{% endraw %}<%= line.end_annotation_data %>
            <% end %>
        </div>
        <% end %>
        <% for img_highlight in self.image_highlight_zones %>
            <span class="annotator-hl image-annotation-highlight"
                data-annotation-id="<%= img_highlight.annotation_id %>"
                <%= img_highlight.css_style %>>
            </span>
        <% end %>
      }
    end

    # html for page text content using the #template
    # (logic adapted from readux)
    def html()
        return ERB.new(self.template()).result(binding)
    end

end

# TEI note
class TeiNote < TeiXmlObject
    attr_accessor :start_target, :end_target
    # @!attribute id
    #   @return [String]
    xml_attr_reader :id, :xpath => '@xml:id'
    # @!attribute author
    #   @return [String]
    xml_attr_reader :author, :xpath => '@resp'
    # @!attribute target
    #   @return [String]
    xml_attr_reader :target, :xpath => '@target'
    # @!attribute ana
    #   @return [String]
    xml_attr_reader :ana, :xpath => '@ana'
    # @!attribute markdown
    #   @return [String] content of the note in markdown format
    xml_attr_reader :markdown, :xpath => './/t:code[@lang="markdown"]'

    def tags
        if self.ana
            self.ana.split(' ').map { |s| s.gsub(/^#/, '')}
        else
            []
        end
    end

    # is this note a range target?
    #   @return [Boolean]
    def range_target?
        return self.target.start_with?('#range')
    end

    # page annotated by this note
    #   @return [TeiFacsimilePage]
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

    # annotation id
    def annotation_id
        self.id.gsub(/^annotation-/, '')
    end

end

# TeiInterp element within an interpGrp
class TeiInterp < TeiXmlObject
    # @!attribute id
    #   @return [String]
    xml_attr_reader :id, :xpath => '@xml:id'
    # @!attribute value
    #   @return [String]
    xml_attr_reader :value, :xpath => '@value'
end

# TEI facsimile document
class TeiFacsimile < TeiXmlObject
    # @!attribute title_statement
    #   @return [TeiTitleStatement]
    xml_attr_reader :title_statement, :xpath => '//t:teiHeader/t:fileDesc/t:titleStmt',
        :as => TeiTitleStatement

    # @!attribute source_bibl
    #   @return [Hash#TeiBibl] hash keyed on type attribute
    xml_attr_reader :source_bibl, :xpath => '//t:teiHeader/t:fileDesc/t:sourceDesc/t:bibl',
        :as => TeiBibl, :hash => true, :hash_key_xpath => '@type'

    # @!attribute pages
    #   @return [List#TeiFacsimilePage]
    xml_attr_reader :pages, :xpath => '//t:facsimile/t:surface[@type="page"]',
        :as => TeiFacsimilePage, :list => true

    # @!attribute annotations
    #   @return [List#TeiNote]
    xml_attr_reader :annotations, :xpath => '//t:note[@type="annotation"]',
        :as => TeiNote, :list => true

    # @!attribute tags
    #   @return [Hash#TeiInterp]
    xml_attr_reader :tags, :xpath => '//t:back/t:interpGrp[@type="tags"]/t:interp',
        :as => TeiInterp, :hash => true, :hash_key_xpath => '@xml:id'

end

# Utility method to load a file as TeiFacsimile
# @param filename
# @return [TeiFacsimile]
def load_tei(filename)
    teixml = Nokogiri::XML(File.open(filename)) do |config|
      config.options = Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NONET
    end
    TeiFacsimile.new(teixml)
end

