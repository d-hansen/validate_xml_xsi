#!/usr/bin/env ruby
require 'nokogiri'

class XML
  class Validation
    class Error
      Params = [:type, :file, :line, :column, :message, :err]
      attr_reader *Params, :description
      def initialize(*args)
        Params.each.with_index { |param, idx| instance_variable_set("@#{param.to_s}", args[idx]) }
        @description = "#{@type.to_s} ERROR [#{@file}:#{@line}:#{@column}]: #{@message}".freeze
      end
    end
  end

  def self.parse(obj)
    filename = nil
    obj = File::read(filename = obj) if obj.is_a?(String) && File::exist?(obj)
    xml_doc = Nokogiri::XML.parse(obj) { |cfg| cfg.strict.pedantic.nonet }
    xml_doc.instance_variable_set('@filename', filename)
    xml_doc.define_singleton_method(:filename) { instance_variable_get('@filename') }
    xml_doc
  end

  class Schema
    def self.validate(xml_doc)
      xml_doc = XML::parse(xml_doc) unless xml_doc.is_a?(Nokogiri::XML::Document)
      errors = []
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
              error "MISMATCHING XMLNS XSI: #{ns_set.first} -> #{ns_loc} VS #{ns_set.last}"
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
      xsd = Nokogiri::XML.Schema(xsd_doc)
      xsd.errors.each do |err|
        err_msg = (/ERROR: /.match(err.message)) ? $' : err.message
        errors << XML::Validation::Error.new(:XSD, err.file, err.line, err.column, err_msg, err)
      end
      errs = xsd.validate(xml_doc)
      errs.each do |err|
        err_msg = (/ERROR: /.match(err.message)) ? $' : err.message
        fname = (err.file.nil?) ? xml_doc.filename : err.file
        errors << XML::Validation::Error.new(:XML, fname, err.line, err.column, err_msg, err)
      end
      errors
    end
  end
end
