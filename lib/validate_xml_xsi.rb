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
    def initialize(xml_doc)
      unless xml_doc.is_a?(Nokogiri::XML::Document)
        raise DocumentError.new("invalid Nokogiri::XML::Document - #{xml_doc.class.name}")
      end
      @document = xml_doc
      ## Determine default/top/root namespace
      target_ns_href = nil
      @document.namespaces.each do |ns_prefix, ns_href|
        target_ns_href = ns_href if ns_prefix.nil? || ns_prefix.empty? || ns_prefix.eql?('xmlns')
      end
      raise DocumentError.new("Unable to determine default (xmlns) namespace!") if target_ns_href.nil? || target_ns_href.empty?
      ## Build an all-in-one XSD document that imports all of the separate schema locations
      @xsd = "<?xml version=\"1.0\"?>\n"
      @xsd << "<xsd:schema xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"\n" \
                 "            targetNamespace=\"#{target_ns_href}\"\n" \
                 "            version=\"1.0\">\n"
      ## Include the default xml namespace
      schemata_by_ns = {}
      ## Iterate over all the elements and find any xsi:schemaLocation attributes
      ## and build a hash of all of the namespaces and locations
      @document.search('//*[@xsi:schemaLocation]').each do |elem|
        elem['xsi:schemaLocation'].scan(/(\S+)\s+(\S+)/).each do |ns_set|
          if ns_loc = schemata_by_ns[ns_set.first]
            unless ns_loc.eql?(ns_set.last)
              raise DocumentError.new("MISMATCHING namespace: #{ns_set.first} -> #{ns_loc} VS #{ns_set.last}")
            end
          else
            schemata_by_ns[ns_set.first] = ns_set.last
          end
        end
      end
      schemata_by_ns.each do |ns_href, ns_file|
        @xsd << (ns_href.eql?(target_ns_href) ?
                    "  <xsd:include schemaLocation=\"#{ns_file}\"/>\n" :
                    "  <xsd:import namespace=\"#{ns_href}\" schemaLocation=\"#{ns_file}\"/>\n")
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
  end
end
