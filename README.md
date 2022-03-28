# validate_xml_xsi

This gem validates XML against it's XSD that is created from xsi:schemaLocation elements.

It does this by first parsing the XML and searching for elements that include xsi:schemaLocation attributes. It then creates an XSD schema document that includes the root namespace and further imports additional namespaces discovered in the XML.

It then validates the document against that constructed schema document and outputs any error messages.

Note: this gem utilizes the 'nokogiri' gem (which in turn relies on Gnome's libxml2) for the XML parsing and schema validation.

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
