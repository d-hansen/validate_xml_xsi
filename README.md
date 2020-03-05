# validate_xml_xsi

This gem validates XML against it's xsi using the xsi:schemaLocation elements to define the location of XSD documents.

It does this by first parsing the XML and searching for xsi:schemaLocation elements and then creating an XSD document that imports the XSD's identified in the XML.

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

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in the gemspec, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/d-hansen/validate_xml_xsi.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
