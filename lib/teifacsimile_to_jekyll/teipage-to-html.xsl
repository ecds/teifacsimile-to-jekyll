<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  version="2.0" exclude-result-prefixes="tei xs">

  <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
    <desc>Stylesheet for generating HTML from a TEI facsimile page.</desc>
  </doc>

  <!-- number (in sequence) for the current page -->
  <xsl:param name="SINGLE_PAGE_SIZE" select="1000" as="xs:float"/>

  <xsl:output indent="yes" method="html" encoding="utf-8" omit-xml-declaration="yes"/>
  <xsl:strip-space elements="*"/>
<!--
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
                <a href="#<%= img_highlight.annotation_id %>"
                  name="hl-<%= img_highlight.annotation_id %>" class="to-annotation"></a>

            </span>
        <% end %>
    -->



  <xsl:template match="tei:zone[@type='line']">

      <xsl:comment>page size is <xsl:value-of select="$SINGLE_PAGE_SIZE"/></xsl:comment>

    <div>
        <xsl:attribute name="class">ocr-line<xsl:if test="count(.//tei:w) = 0"> ocrtext</xsl:if></xsl:attribute>
        <xsl:call-template name="css-styles"/>
        <xsl:choose>
            <xsl:when test="count(.//tei:w)">
                <xsl:apply-templates select=".//tei:w"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="tei:line/text()"/>
                <!-- {% raw %}<xsl:value-of select="."/>{% endraw %} -->
            </xsl:otherwise>
        </xsl:choose>
    </div>
  </xsl:template>

  <xsl:template match="tei:w">
    <div class="ocr-zone ocrtext"> <!-- css todo -->
        <xsl:call-template name="css-styles"/>
        <xsl:apply-templates select="text()"/>
            <!-- {% raw %}<xsl:value-of select="."/>{% endraw %} -->
<!--  TODO       <%= zone.begin_annotation_data %>{% raw %}<%= zone.annotated_text %>{% endraw %}<%= zone.end_annotation_data %> -->
    </div>
  </xsl:template>

  <xsl:template name="css-styles">
    <!-- scale from original page size to view size -->
    <xsl:variable name="page" select="ancestor::tei:surface[@type='page']"/>
    <xsl:variable name="page_width" select="xs:float($page/@lrx - $page/@ulx)"/>
    <xsl:variable name="page_height" select="xs:float($page/@lry - $page/@uly)"/>
    <xsl:variable name="scale"><xsl:value-of select="$SINGLE_PAGE_SIZE div max(($page_width, $page_height))"/></xsl:variable>
    <xsl:attribute name="style">
        <xsl:if test="contains('textLine line image-annotation-highlight', @type)">
            <!-- lines and image highlights are positioned & sized relative to the page -->
            <xsl:value-of select="concat('left:', format-number(xs:float(@ulx) div $page_width, '##.##%'), ';')"/>
            <xsl:value-of select="concat('top:', format-number(xs:float(@uly) div $page_height, '##.##%'), ';')"/>
            <xsl:value-of select="concat('width:', format-number(xs:float(@lrx) - xs:float(@ulx) div $page_width, '##.##%'), ';')"/>
            <xsl:value-of select="concat('height:', format-number(xs:float(@lry) - xs:float(@uly) div $page_height, '##.##%'), ';')"/>

        </xsl:if>

    </xsl:attribute>
  </xsl:template>

  <xsl:template match="tei:zone[@type='image-annotation-highlight']">
     <!--<tei:zone type="image-annotation-highlight" ulx="745.185" uly="1173.054" lrx="1377.9052" lry="1875.063" xml:id="highlight-30351770-1e9e-42be-a3f2-7376290b5c40"/> -->
    <xsl:variable name="annotation_id"><xsl:value-of select="substring-after(@xml:id, 'highlight-')"/></xsl:variable>
    <span class="annotator-hl image-annotation-highlight">
        <xsl:attribute name="data-annotation-id"><xsl:value-of select="$annotation_id"/></xsl:attribute>
        <!-- css todo -->
        <a class="to-annotation">
         <xsl:attribute name="href"><xsl:value-of select="concat('#', $annotation_id)"/></xsl:attribute>
         <xsl:attribute name="name"><xsl:value-of select="concat('hl-', $annotation_id)"/></xsl:attribute>
       </a>
    </span>
  </xsl:template>

  <xsl:template match="tei:line/text() | tei:w/text()">
    <!-- highlight-start-4d9797fb-0038-46c0-ba94-4851969ba076"/>Theologi^ftudia omniexpartepro-</tei:line> -->

        <xsl:variable name="preceding-start-anchors"
        select="parent::node()/tei:w/preceding::tei:anchor|parent::node()/preceding::tei:anchor[@type='text-annotation-highlight-start']"/>

    <xsl:variable name="following_end_anchors"
        select="(parent::node()/tei:w/following::tei:anchor|parent::node()/following::tei:anchor)[@type='text-annotation-highlight-end']"/>

    <xsl:choose>
        <xsl:when test="count($preceding-start-anchors) and count($following_end_anchors)">
    <xsl:variable name="highlights"
        select="$preceding-start-anchors[contains(@xml:id, substring-after($following_end_anchors/@xml:id, 'highlight-end-'))]"/>
    <!-- todo: handle multiple highlights -->
        <span class="annotator-hl">
            <xsl:attribute name="data-annotation-id"><xsl:value-of select="substring-after($highlights/@xml:id, 'highlight-start-')"/></xsl:attribute>
            <xsl:apply-templates select="." mode="raw-text"/>
        </span>
    </xsl:when>
    <xsl:otherwise>
        <xsl:apply-templates select="." mode="raw-text"/>
    </xsl:otherwise>
    </xsl:choose>

  </xsl:template>

    <xsl:template match="text()" mode="raw-text">
        <span><xsl:text>{% raw %}</xsl:text><xsl:value-of select="."/><xsl:text>{% endraw %}</xsl:text></span>
    </xsl:template>

</xsl:stylesheet>

