Gem::Specification.new do |spec|
  spec.name          = "validate_xml_xsi"
  spec.version       = "0.3.0"
  spec.authors       = ["David Hansen"]
  spec.email         = ["david@hansen4.net"]

  spec.summary       = %q{Validate XML against it's embedded XSI elements that define the XSD's.}
  spec.homepage      = "https://github.com/d-hansen/validate_xml_xsi"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/d-hansen/validate_xml_xsi"
  spec.metadata["changelog_uri"] = "https://github.com/d-hansen/validate_xml_xsi/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 2.1"
  spec.add_development_dependency "rake", ">= 13.0"

  spec.add_dependency "nokogiri", ">= 1.13.2"
end
