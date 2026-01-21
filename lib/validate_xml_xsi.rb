#!/usr/bin/env ruby
require 'nokogiri'

class XML_XSI
  def self.parse(obj)
    filename = nil
    obj = File::read(filename = obj) if obj.is_a?(String) && File::exist?(obj)
    xml_doc = Nokogiri::XML.parse(obj) { |cfg| cfg.strict.pedantic.nonet }
    xml_doc.instance_variable_set('@filename', filename)
    xml_doc.define_singleton_method(:filename) { instance_variable_get('@filename') }
    xml_doc
  end

  class Schema
    class DocumentError < StandardError; end
    class ValidationError < StandardError
      attr_reader :type, :file, :line, :column, :level, :message, :description, :error
      def initialize(type, err, filename = nil)
        @type = type
        @error = err
        @file = filename.nil? ? @error.file : filename
        @line = @error.line
        @column = @error.column
        if /((?:ERROR)|(?:WARNING)): /.match(@error.message)
          @level = $1
          @message = $'
          @description = "#{@type.to_s} #{@level.to_s} [#{@file}:#{@line}:#{@column}]: #{@message}".freeze
        else
          @level = ''
          @message = @error.message
          @description = "#{@type.to_s} #{@message}".freeze
        end
        super(@description)
      end
    end

    attr_reader :xsd
    def initialize(xml_doc, parent_xml_doc = nil)
      unless xml_doc.is_a?(Nokogiri::XML::Document)
        raise DocumentError.new("invalid Nokogiri::XML::Document - #{xml_doc.class.name}")
      end
      unless parent_xml_doc.nil? || parent_xml_doc.is_a?(Nokogiri::XML::Document)
        raise DocumentError.new("invalid parent Nokogiri::XML::Document - #{parent_xml_doc.class.name}")
      end
      @document = xml_doc
      ## Determine default/top/root namespace
      target_ns_href = nil
      @document.namespaces.each do |ns_prefix, ns_href|
        target_ns_href = ns_href if ns_prefix.nil? || ns_prefix.empty? || ns_prefix.eql?('xmlns')
      end
      if target_ns_href.nil? || target_ns_href.empty?
        raise DocumentError.new("Unable to determine a default (xmlns) namespace!")
      end

      ## Determine schema locations, optionally inheriting their location declarations from a parent document
      schema_locations = parent_xml_doc.nil? ? {} : self.class.find_schema_locations(parent_xml_doc)
      schema_locations.merge!(self.class.find_schema_locations(@document))

      ## If we still don't have a file location for the target namespace, attempt to look for
      ## one based on the name of the root node (assuming that where the namespace was declared).
      if !schema_locations.include?(target_ns_href) &&
          @document.root.namespace.href.eql?(target_ns_href)
        root_file_xsd = "#{@document.root.name}.xsd"
        schema_locations[target_ns_href] = root_file_xsd if File.exist?(root_file_xsd)
      end

      unless schema_locations.include?(target_ns_href)
        ## XXX - Another possibility would be to default to a file named after the node name declaring the xmlns
        raise DocumentError.new("Unable to locate a source/file for the default (xmlns) namespace schema!")
      end

      ## Build an all-in-one XSD document that imports all of the separate schema locations
      @xsd = "<?xml version=\"1.0\"?>\n"
      @xsd << "<xsd:schema xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"\n" \
                 "            targetNamespace=\"#{target_ns_href}\"\n" \
                 "            version=\"1.0\">\n"

      ## Minimally we need the target namespace location or we have nothing to include
      target_ns_file = schema_locations.delete(target_ns_href)
      @xsd << "  <xsd:include schemaLocation=\"#{target_ns_file}\"/>\n" unless target_ns_file.nil?

      ## Now add imports for the other defined schemaLocations
      schema_locations.each do |ns_href, ns_file|
        @xsd << "  <xsd:import namespace=\"#{ns_href}\" schemaLocation=\"#{ns_file}\"/>\n"
      end
      @xsd << "</xsd:schema>\n"

      ## Create the Schema objects
      @schema = Nokogiri::XML::Schema.new(@xsd)
    end

    def validate
      errors = []
      @schema.errors.each do |err|
        errors << ValidationError.new(:XSD, err)
      end
      errs = @schema.validate(@document)
      errs.each do |err|
        fname = (err.file.nil?) ? @document.filename : err.file
        errors << ValidationError.new(:XML, err, fname)
      end
      errors
    end

    def self.find_schema_locations(xml_doc)
      ## Include the default xml namespace
      schema_locations = {}

      ## Determine if the document has reference to the namespace "http://www.w3.org/2001/XMLSchema-instance"
      ## which is used for defining schemaLocations
      xsi_prefix = xml_doc.namespaces.invert['http://www.w3.org/2001/XMLSchema-instance']&.delete_prefix('xmlns:')

      ## Iterate over all the elements and find any xsi:schemaLocation attributes
      ## and build a hash of all of the namespaces and locations
      unless xsi_prefix.nil?
        xsi_loc = "#{xsi_prefix}:schemaLocation"
        xml_doc.search("//*[@#{xsi_loc}]").each do |elem|
          elem[xsi_loc].scan(/(\S+)\s+(\S+)/).each do |ns_set|
            if ns_loc = schema_locations[ns_set.first]
              unless ns_loc.eql?(ns_set.last)
                raise DocumentError.new("MISMATCHING namespace: #{ns_set.first} -> #{ns_loc} VS #{ns_set.last}")
              end
            else
              schema_locations[ns_set.first] = ns_set.last
            end
          end
        end
      end
      schema_locations
    end
  end
end
