# validate_xml_xsi

This gem validates XML against it's xsi using the xsi:schemaLocation elements to define the location of XSD documents.

It does this by first parsing the XML and searching for xsi:schemaLocation elements and then creating a schema document that imports the XSD's identified in the XML.

It then validates the document against that schema and outputs any error messages.

Note: this gem utilizes the 'nokogiri' gem for XML parsing and schema validation.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'validate_xml_xsi'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install validate_xml_xsi

## Usage

validate_xml_xsi <xmlfiles>

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/d-hansen/validate_xml_xsi.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
