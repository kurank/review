# = epubv3.rb -- EPUB version 3 producer.
#
# Copyright (c) 2010-2017 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'epubmaker/epubcommon'
require 'epubmaker/zip_exporter'

module EPUBMaker
  # EPUBv3 is EPUB version 3 producer.
  class EPUBv3 < EPUBCommon
    # Construct object with parameter hash +params+ and message resource hash +res+.
    def initialize(producer)
      super
      @opf_prefix = {}
      @producer.params['opf_prefix'].each { |k, v| @opf_prefix[k] = v } if @producer.params['opf_prefix'].present?
    end

    # Return opf file content.
    def opf
      @opf_metainfo = opf_metainfo
      @opf_manifest = opf_manifest
      @opf_toc = opf_tocx
      @package_attrs = ''

      if @opf_prefix && @opf_prefix.size > 0
        prefixes_str = @opf_prefix.map { |k, v| %Q(#{k}: #{v}) }.join(' ')
        @package_attrs << %Q( prefix="#{prefixes_str}")
      end

      tmplfile = File.expand_path('./opf/epubv3.opf.erb', ReVIEW::Template::TEMPLATE_DIR)
      ReVIEW::Template.load(tmplfile).result(binding)
    end

    def opf_metainfo
      s = ''
      %w[title language date type format source description relation coverage subject rights].each do |item|
        next unless @producer.params[item]
        if @producer.params[item].is_a?(Array)
          @producer.params[item].each_with_index do |v, i|
            if v.is_a?(Hash)
              s << %Q(    <dc:#{item} id="#{item}-#{i}">#{CGI.escapeHTML(v['name'])}</dc:#{item}>\n)
              v.each_pair do |name, val|
                next if name == 'name'
                s << %Q(    <meta refines="##{item}-#{i}" property="#{name}">#{CGI.escapeHTML(val)}</meta>\n)
              end
            else
              s << %Q(    <dc:#{item} id="#{item}-#{i}">#{CGI.escapeHTML(v.to_s)}</dc:#{item}>\n)
            end
          end
        elsif @producer.params[item].is_a?(Hash)
          s << %Q(    <dc:#{item} id="#{item}">#{CGI.escapeHTML(@producer.params[item]['name'])}</dc:#{item}>\n)
          @producer.params[item].each_pair do |name, val|
            next if name == 'name'
            s << %Q(    <meta refines="##{item}" property="#{name}">#{CGI.escapeHTML(val)}</meta>\n)
          end
        else
          s << %Q(    <dc:#{item} id="#{item}">#{CGI.escapeHTML(@producer.params[item].to_s)}</dc:#{item}>\n)
        end
      end

      s << %Q(    <meta property="dcterms:modified">#{@producer.params['modified']}</meta>\n)

      # ID
      if @producer.params['isbn'].nil?
        s << %Q(    <dc:identifier id="BookId">#{@producer.params['urnid']}</dc:identifier>\n)
      else
        s << %Q(    <dc:identifier id="BookId">#{@producer.params['isbn']}</dc:identifier>\n)
      end

      # creator (should be array)
      %w[a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-csl a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl aut].each do |role|
        next unless @producer.params[role]
        @producer.params[role].each_with_index do |v, i|
          if v.is_a?(Hash)
            s << %Q(    <dc:creator id="#{role}-#{i}">#{CGI.escapeHTML(v['name'])}</dc:creator>\n)
            s << %Q(    <meta refines="##{role}-#{i}" property="role" scheme="marc:relators">#{role.sub('a-', '')}</meta>\n)
            v.each_pair do |name, val|
              next if name == 'name'
              s << %Q(    <meta refines="##{role.sub('a-', '')}-#{i}" property="#{name}">#{CGI.escapeHTML(val)}</meta>\n)
            end
          else
            s << %Q(    <dc:creator id="#{role}-#{i}">#{CGI.escapeHTML(v)}</dc:creator>\n)
            s << %Q(    <meta refines="##{role}-#{i}" property="role" scheme="marc:relators">#{role.sub('a-', '')}</meta>\n)
          end
        end
      end

      # contributor (should be array)
      %w[adp ann arr art asn aqt aft aui ant bkp clb cmm csl dsr edt ill lyr mdc mus nrt oth pbd pbl pht prt red rev spn ths trc trl].each do |role|
        next unless @producer.params[role]
        @producer.params[role].each_with_index do |v, i|
          if v.is_a?(Hash)
            s << %Q(    <dc:contributor id="#{role}-#{i}">#{CGI.escapeHTML(v['name'])}</dc:contributor>\n)
            s << %Q(    <meta refines="##{role}-#{i}" property="role" scheme="marc:relators">#{role}</meta>\n)
            v.each_pair do |name, val|
              next if name == 'name'
              s << %Q(    <meta refines="##{role}-#{i}" property="#{name}">#{CGI.escapeHTML(val)}</meta>\n)
            end
          else
            s << %Q(    <dc:contributor id="#{role}-#{i}">#{CGI.escapeHTML(v)}</dc:contributor>\n)
            s << %Q(    <meta refines="##{role}-#{i}" property="role" scheme="marc:relators">#{role}</meta>\n)
          end

          if %w[prt pbl].include?(role)
            if v.is_a?(Hash)
              s << %Q(    <dc:publisher id="pub-#{role}-#{i}">#{CGI.escapeHTML(v['name'])}</dc:publisher>\n)
              s << %Q(    <meta refines="#pub-#{role}-#{i}" property="role" scheme="marc:relators">#{role}</meta>\n)
              v.each_pair do |name, val|
                next if name == 'name'
                s << %Q(    <meta refines="#pub-#{role}-#{i}" property="#{name}">#{CGI.escapeHTML(val)}</meta>\n)
              end
            else
              s << %Q(    <dc:publisher id="pub-#{role}-#{i}">#{CGI.escapeHTML(v)}</dc:publisher>\n)
              s << %Q(    <meta refines="#pub-#{role}-#{i}" property="role" scheme="marc:relators">prt</meta>\n)
            end
          end
        end
      end

      ## add custom <meta> element
      @producer.params['opf_meta'].each { |k, v| s << %Q(    <meta property="#{k}">#{CGI.escapeHTML(v)}</meta>\n) } if @producer.params['opf_meta'].present?

      s
    end

    def opf_manifest
      s = ''
      s << <<EOT
  <manifest>
    <item properties="nav" id="#{@producer.params['bookname']}-toc.#{@producer.params['htmlext']}" href="#{@producer.params['bookname']}-toc.#{@producer.params['htmlext']}" media-type="application/xhtml+xml"/>
    <item id="#{@producer.params['bookname']}" href="#{@producer.params['cover']}" media-type="application/xhtml+xml"/>
EOT

      if @producer.params['coverimage']
        @producer.contents.each do |item|
          next if !item.media.start_with?('image') || File.basename(item.file) != @producer.params['coverimage']
          s << %Q(    <item properties="cover-image" id="cover-#{item.id}" href="#{item.file}" media-type="#{item.media}"/>\n)
          item.id = nil
          break
        end
      end

      @producer.contents.each do |item|
        next if item.file =~ /#/ || item.id.nil? # skip subgroup, or id=nil (for cover)
        propstr = ''
        if item.properties.size > 0
          propstr = %Q( properties="#{item.properties.sort.uniq.join(' ')}")
        end
        s << %Q(    <item id="#{item.id}" href="#{item.file}" media-type="#{item.media}"#{propstr}/>\n)
      end
      s << %Q(  </manifest>\n)

      s
    end

    def opf_tocx
      if @producer.params['epubmaker']['cover_linear'] && @producer.params['epubmaker']['cover_linear'] != 'no'
        cover_linear = 'yes'
      else
        cover_linear = 'no'
      end

      s = ''
      if @producer.params['direction']
        s << %Q(  <spine page-progression-direction="#{@producer.params['direction']}">\n)
      else
        s << %Q(  <spine>\n)
      end
      s << %Q(    <itemref idref="#{@producer.params['bookname']}" linear="#{cover_linear}"/>\n)

      toc = nil
      @producer.contents.each do |item|
        next if item.media !~ /xhtml\+xml/ # skip non XHTML
        if toc.nil? && item.chaptype != 'pre'
          s << %Q(    <itemref idref="#{@producer.params['bookname']}-toc.#{@producer.params['htmlext']}" />\n) if @producer.params['toc']
          toc = true
        end
        s << %Q(    <itemref idref="#{item.id}"/>\n)
      end
      s << %Q(  </spine>\n)

      s
    end

    def ncx(indentarray)
      ncx_main = if @producer.params['epubmaker']['flattoc'].nil?
                   hierarchy_ncx('ol')
                 else
                   flat_ncx('ol', @producer.params['epubmaker']['flattocindent'])
                 end

      @body = <<EOT
  <nav xmlns:epub="http://www.idpf.org/2007/ops" epub:type="toc" id="toc">
  <h1 class="toc-title">#{CGI.escapeHTML(@producer.res.v('toctitle'))}</h1>
#{ncx_main}  </nav>
EOT

      @title = CGI.escapeHTML(@producer.res.v('toctitle'))
      @language = @producer.params['language']
      @stylesheets = @producer.params['stylesheet']
      tmplfile = File.expand_path('./html/layout-html5.html.erb', ReVIEW::Template::TEMPLATE_DIR)
      ReVIEW::Template.load(tmplfile).result(binding)
    end

    # Produce EPUB file +epubfile+.
    # +basedir+ points the directory has contents.
    # +tmpdir+ defines temporary directory.
    def produce(epubfile, basedir, tmpdir)
      produce_write_common(basedir, tmpdir)

      File.open("#{tmpdir}/OEBPS/#{@producer.params['bookname']}-toc.#{@producer.params['htmlext']}", 'w') { |f| @producer.ncx(f, @producer.params['epubmaker']['ncxindent']) }

      @producer.call_hook(@producer.params['epubmaker']['hook_prepack'], tmpdir)
      expoter = EPUBMaker::ZipExporter.new(tmpdir, @producer.params)
      expoter.export_zip(epubfile)
    end
  end
end
