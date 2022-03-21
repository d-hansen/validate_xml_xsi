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
      Params = [:type, :file, :line, :column, :message, :err]
      attr_reader *Params, :description
      def initialize(*args)
        Params.each.with_index { |param, idx| instance_variable_set("@#{param.to_s}", args[idx]) }
        @description = "#{@type.to_s} ERROR [#{@file}:#{@line}:#{@column}]: #{@message}".freeze
        super(@description)
      end
    end

    def self.parse_schema(xml_doc)
      unless xml_doc.is_a?(Nokogiri::XML::Document)
        raise DocumentError.new("not a Nokogiri::XML::Document (class: #{xml_doc.class.name})!"
      end
      ## Build an all-in-one XSD document that imports all of the separate schema locations
      xsd_doc = "<?xml version=\"1.0\"?>\n"
      xsd_doc << "<xsd:schema targetNamespace=\"http://www.w3.orig/XML/1998/namespace\"\n" \
                 "            xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"\n" \
                 "            version=\"1.0\">\n"
      ## Iterate over all the elements and find any xsi:schemaLocation attributes
      ## and build a hash of all of the namespaces and locations
      schemata_by_ns = {}
      xml_doc.search('//*[@xsi:schemaLocation]').each do |elem|
        elem['xsi:schemaLocation'].scan(/(\S+)\s+(\S+)/).each do |ns_set|
          if ns_loc = schemata_by_ns[ns_set.first]
            unless ns_loc.eql?(ns_set.last)
              raise DocumentError.new("MISMATCHING XMLNS XSI: #{ns_set.first} -> #{ns_loc} VS #{ns_set.last}")
            end
          else
            schemata_by_ns[ns_set.first] = ns_set.last
          end
        end
      end
      schemata_by_ns.each do |ns_href, ns_file|
        xsd_doc << "  <xsd:import namespace=\"#{ns_href}\" schemaLocation=\"#{ns_file}\"/>\n"
      end
      xsd_doc << "</xsd:schema>\n"
      Nokogiri::XML::Schema.new(xsd_doc)
    end

    def self.validate(xml_doc, xsd = nil)
      xml_doc = XML_XSI::parse(xml_doc) unless xml_doc.is_a?(Nokogiri::XML::Document)
      errors = []
      unless xsd.nil? || xsd.is_a?(Nokogiri::XML::Schema)
        raise DocumentError.new("Invalid XSD - not a Nokogiri::XML::Schema (class: #{xsd.class.name})!")
      end
      xsd = self.parse_schema(xml_doc) if xsd.nil?
      xsd.errors.each do |err|
        err_msg = (/ERROR: /.match(err.message)) ? $' : err.message
        errors << ValidationError.new(:XSD, err.file, err.line, err.column, err_msg, err)
      end
      errs = xsd.validate(xml_doc)
      errs.each do |err|
        err_msg = (/ERROR: /.match(err.message)) ? $' : err.message
        fname = (err.file.nil?) ? xml_doc.filename : err.file
        errors << ValidationError.new(:XML, fname, err.line, err.column, err_msg, err)
      end
      errors
    end
  end
end
