## v0.2.4

* Fix some silly syntax errors

## v0.2.3

* Rename XML_XSI::Schema::parse_schema to just XML_XSI::Schema::parse

## v0.2.2

* Break out parsing of the schema from validation so we can reference the schema if we need to.

## v0.2.1

* Update namespace to XML_XSI in bin/validate_xml_xsi utility

## v0.2.0

* Change namespace to XML_XSI and rename/promote Validation::Error to Schema::ValidationError < StandardError.

## v0.1.4

* Change module XML, Validation, & Schema to be classes instead.

## v0.1.3

* Rev Nokogiri requirement to >= 1.13.2 for CVE-2021-30560 & CVE-2022-23308

## v0.1.1

* Rev Nokogiri requirement to ~> 1.12.5 for CVE-2021-41098

## v0.1.0

* Initial release

