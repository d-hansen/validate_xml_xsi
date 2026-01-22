#!/usr/bin/env ruby
require 'nokogiri'

## Monkey-patch Nokogiri::XML::SyntaxError::aggregate to also keep the ENTIRE LIST of errors - ARGH!
Nokogiri::XML::SyntaxError.class_eval do
  class << self
    alias_method :orig_aggregate, :aggregate
    def aggregate(errors)
      agg_err = orig_aggregate(errors)
      agg_err.instance_variable_set(:@aggregate, errors)
      agg_err.define_singleton_method(:aggregate) { instance_variable_get(:@aggregate) }
      agg_err
    end
  end
end

class XML_XSI
  def self.parse(obj)
    filename = nil
    obj = File::read(filename = obj) if obj.is_a?(String) && File::exist?(obj)
    xml_doc = Nokogiri::XML.parse(obj) { |cfg| cfg.strict.pedantic.nonet }
    xml_doc.instance_variable_set('@filename', filename)
    xml_doc.define_singleton_method(:filename) { instance_variable_get('@filename') }
    xml_doc
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
              raise Schema::DocumentError.new("MISMATCHING namespace: #{ns_set.first} -> #{ns_loc} VS #{ns_set.last}")
            end
          else
            schema_locations[ns_set.first] = ns_set.last
          end
        end
      end
    end
    schema_locations
  end

  class Schema
    class DocumentError < StandardError; end
    class NamespaceError < StandardError
      def initialize
        super("Unable to determine default/target (xmlns) namespace!")
      end
    end
    class LocationError < StandardError
      attr_reader :ns_href
      def initialize(ns_href = nil)
        @ns_href = ns_href
        msg = ns_href.nil? ?
          "No schema locations defined or provided" :
          "No location for the default (xmlns) namespace schema: #{ns_href}"
        super(msg)
      end
    end
    ## Unified Error reportign class for both XSD and XML errors
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

    class Erroneous
      attr_reader :errors
      def initialize(ex)
        errs = ex.respond_to?(:aggregate) ? ex.aggregate : [ex]
        @errors = errs.map { |err| ValidationError.new(:XSD, err) }
      end
    end

    attr_reader :xsd
    def initialize(xml_doc, schema_locations = {})
      raise ArgumentError.new("Provided schema locations must be a Hash") unless schema_locations.is_a?(Hash)
      unless xml_doc.is_a?(Nokogiri::XML::Document)
        raise DocumentError.new("invalid Nokogiri::XML::Document - #{xml_doc.class.name}")
      end
      @document = xml_doc
      ## Determine default/top/root namespace
      @ns_href = nil
      @document.namespaces.each do |ns_prefix, ns_href|
        @ns_href = ns_href if ns_prefix.nil? || ns_prefix.empty? || ns_prefix.eql?('xmlns')
      end
      raise NamespaceError.new if @ns_href.nil? || @ns_href.empty?

      ## Determine schema locations found in the source document
      schema_locations.merge!(XML_XSI::find_schema_locations(@document))

      raise LocationError.new if schema_locations.empty?
      raise LocationError.new(@ns_href) unless schema_locations.include?(@ns_href)

      ## Build an all-in-one XSD document that imports all of the separate schema locations
      @xsd = "<?xml version=\"1.0\"?>\n"
      @xsd << "<xsd:schema xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"\n" \
              "            targetNamespace=\"#{@ns_href}\"\n" \
              "            version=\"1.0\">\n"

      ## Minimally we need the target namespace location or we have nothing to include
      @xsi_file = schema_locations.delete(@ns_href)
      @xsd << "  <xsd:include schemaLocation=\"#{@xsi_file}\"/>\n" unless @xsi_file.nil?

      ## Now add imports for the other defined schemaLocations
      schema_locations.each do |ns_href, ns_file|
        @xsd << "  <xsd:import namespace=\"#{ns_href}\" schemaLocation=\"#{ns_file}\"/>\n"
      end
      @xsd << "</xsd:schema>\n"

      ## Create the Schema objects
      begin
        @schema = Nokogiri::XML::Schema.new(@xsd)
      rescue Nokogiri::XML::SyntaxError => ex
        ## Trap the errors so we can finish initialization and then
        ## report the errors in a sane manner
        @schema = Erroneous.new(ex)
      end
    end

    def errors; @schema.errors; end

    def validate
      errs = @schema.validate(@document)
      errs.map do |err|
        fname = err.file.nil? ? @document.filename : err.file
        ValidationError.new(:XML, err, fname)
      end
    end
  end
end
