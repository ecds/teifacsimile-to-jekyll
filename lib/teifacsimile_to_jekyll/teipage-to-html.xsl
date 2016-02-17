<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  version="1.1" exclude-result-prefixes="tei xs">

  <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
    <desc>Stylesheet for generating HTML from a TEI facsimile page.</desc>
  </doc>

  <!-- number (in sequence) for the current page -->
  <xsl:param name="SINGLE_PAGE_SIZE" select="1000" as="xs:float"/>

  <xsl:output indent="yes" method="html" encoding="utf-8" omit-xml-declaration="yes"/>
  <xsl:strip-space elements="*"/>

  <xsl:template match="tei:zone[@type='line'] | tei:zone[@type='textLine']">
    <div>
        <xsl:attribute name="class">ocr-line<xsl:if test="count(.//tei:w) = 0"> ocrtext</xsl:if></xsl:attribute>
        <xsl:call-template name="css-styles"/>
        <xsl:choose>
            <xsl:when test="count(.//tei:w)"> <!-- word-level content -->
                <xsl:apply-templates select=".//tei:zone[@type='string']"/>
            </xsl:when>
            <xsl:otherwise>
              <span>  <!-- line-level content only -->
                <xsl:apply-templates select="tei:line/text()"/>
              </span>
            </xsl:otherwise>
        </xsl:choose>
    </div>
  </xsl:template>

  <!-- single word of text within a line (from mets/alto ocr) -->
  <xsl:template match="tei:zone[@type='string']">
    <span class="ocr-zone ocrtext">
        <xsl:call-template name="css-styles"/>
        <xsl:apply-templates select="tei:w/text()"/>
    </span>
  </xsl:template>

  <xsl:template name="css-styles">
    <!-- scale from original page size to view size -->
    <xsl:variable name="page" select="ancestor::tei:surface[@type='page']"/>
    <xsl:variable name="page_width" select="$page/@lrx - $page/@ulx" as="xs:float"/>
    <xsl:variable name="page_height" select="$page/@lry - $page/@uly" as="xs:float"/>
    <xsl:variable name="long_edge">
        <xsl:call-template name="maximum">
            <xsl:with-param name="a" select="$page_width"/>
            <xsl:with-param name="b" select="$page_height"/>
        </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="scale"><xsl:value-of select="$SINGLE_PAGE_SIZE div $long_edge"/></xsl:variable>

    <xsl:variable name="lrx" select="@lrx" as="xs:float"/>
    <xsl:variable name="ulx" select="@ulx" as="xs:float"/>
    <xsl:variable name="lry" select="@lry" as="xs:float"/>
    <xsl:variable name="uly" select="@uly" as="xs:float"/>

    <xsl:attribute name="style">
        <xsl:if test="contains('textLine line image-annotation-highlight', @type)">
            <!-- lines and image highlights are positioned & sized relative to the page -->

            <xsl:value-of select="concat('left:', format-number($ulx div $page_width, '##.##%'), ';')"/>
            <xsl:value-of select="concat('top:', format-number($uly div $page_height, '##.##%'), ';')"/>
            <xsl:value-of select="concat('width:', format-number(($lrx - $ulx) div $page_width, '##.##%'), ';')"/>
            <xsl:value-of select="concat('height:', format-number(($lry - $uly) div $page_height, '##.##%'), ';')"/>
        </xsl:if>

        <!-- lines have additional font styles -->
        <xsl:if test="contains('textLine line', @type)">
            <!-- currently assuming left aligned, unclear if info is in ocr/tei -->
            <xsl:text>text-align:left;</xsl:text>
            <!-- Set pixel-based font size for browsers that don't support viewport based sizes.
              For mets-alto, use average height of words in the line to calculate font size.
              For abbyy ocr, no word zones exist, so just use line height. -->
              <xsl:variable name="font-height">
                <xsl:choose>
                    <xsl:when test="tei:zone[@type='string']">
                        <xsl:value-of select="sum((tei:w/@lry) - sum(tei:w/@uly)) div count(tei:w)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$lry - $uly"/>
                    </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>

            <xsl:value-of select="concat('font-size:', format-number($font-height * $scale, '##.##'), 'px')"/>

       </xsl:if>

       <xsl:if test="@type = 'string'">
            <!-- words are positioned relative to parent item (i.e. line) -->
            <xsl:variable name="parent" select="ancestor::tei:zone[1]"/>
            <xsl:variable name="parent_width" select="$parent/@lrx - $parent/@ulx" as="xs:float"/>
            <xsl:variable name="parent_height" select="$parent/@lry - $parent/@uly" as="xs:float"/>
            <xsl:variable name="parent_ulx" select="$parent/@ulx" as="xs:float"/>

            <xsl:value-of select="concat('width:', format-number(($lrx - $ulx) div $parent_width, '##.##%'), ';')"/>
            <xsl:value-of select="concat('height:', format-number(($lry - $uly) div $parent_height, '##.##%'), ';')"/>
            <!-- positioned absolutely within the line -->
            <xsl:value-of select="concat('left:', format-number(($ulx - $parent_ulx) div $page_width, '##.##%'))"/>
        </xsl:if>
    </xsl:attribute>

    <xsl:if test="contains('textLine line', @type)">
        <xsl:attribute name="data-vhfontsize">
            <!-- calculate font size as percentage of page height;
           this will be used by javascript to calculate as % of viewport height -->
           <xsl:value-of select="format-number((($lry - $uly) div $page_height)*100, '##.##')"/>
       </xsl:attribute>
    </xsl:if>

  </xsl:template>

  <xsl:template match="tei:zone[@type='image-annotation-highlight']">
     <!--<tei:zone type="image-annotation-highlight" ulx="745.185" uly="1173.054" lrx="1377.9052" lry="1875.063" xml:id="highlight-30351770-1e9e-42be-a3f2-7376290b5c40"/> -->
    <xsl:variable name="annotation_id"><xsl:value-of select="substring-after(@xml:id, 'highlight-')"/></xsl:variable>
    <span class="annotator-hl image-annotation-highlight">
        <xsl:attribute name="data-annotation-id"><xsl:value-of select="$annotation_id"/></xsl:attribute>
        <xsl:call-template name="css-styles"/>
        <a class="to-annotation">
         <xsl:attribute name="href"><xsl:value-of select="concat('#', $annotation_id)"/></xsl:attribute>
         <xsl:attribute name="name"><xsl:value-of select="concat('hl-', $annotation_id)"/></xsl:attribute>
       </a>
    </span>
  </xsl:template>

  <xsl:template match="text()">
    <!-- identify active highlights: start anchors before the current text with matching end anchors after -->
      <!-- find any highlight anchors before and after current text -->
      <xsl:variable name="preceding-start-anchors"
            select="preceding::tei:anchor[@type='text-annotation-highlight-start']"/>

      <xsl:variable name="following-end-anchors"
           select="following::tei:anchor[@type='text-annotation-highlight-end']"/>

      <xsl:variable name="highlights"
          select="$preceding-start-anchors[@next = $following-end-anchors/@xml:id]"/>

    <xsl:choose>
        <xsl:when test="count($highlights)">
            <xsl:call-template name="highlighted-text">
              <xsl:with-param name="highlights" select="$highlights"/>
            </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
        <xsl:apply-templates select="." mode="raw-text"/>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <xsl:template name="highlighted-text">
    <xsl:param name="highlights"/>
     <xsl:choose>
      <xsl:when test="count($highlights) != 0">
        <span class="annotator-hl">
            <xsl:attribute name="data-annotation-id"><xsl:value-of select="substring-after($highlights/@xml:id, 'highlight-start-')"/></xsl:attribute>

            <xsl:call-template name="highlighted-text">
              <xsl:with-param name="highlights" select="$highlights[position() &gt; 1]"/>
            </xsl:call-template>

        </span>
      </xsl:when>
      <xsl:otherwise>
          <xsl:apply-templates select="." mode="raw-text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

    <xsl:template match="text()" mode="raw-text">
        <xsl:text>{% raw %}</xsl:text><xsl:value-of select="."/><xsl:text>{% endraw %}</xsl:text>
    </xsl:template>

    <!-- workaround for xslt 1.0 and no max function -->
    <xsl:template name="maximum">
        <xsl:param name="a"/>
        <xsl:param name="b"/>
        <xsl:choose>
            <xsl:when test="$a > $b">
                <xsl:value-of select="$a"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$b"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>

