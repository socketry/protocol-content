# frozen_string_literal: true

require_relative "lib/protocol/rest/version"

Gem::Specification.new do |spec|
	spec.name = "protocol-rest"
	spec.version = Protocol::REST::VERSION
	
	spec.summary = "Provides abstractions for REST representations."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/socketry/protocol-rest"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/protocol-rest/",
		"source_code_uri" => "https://github.com/socketry/protocol-rest.git",
	}
	
	spec.files = Dir.glob(["{lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.3"
	
	spec.add_dependency "protocol-media", "~> 0.1"
end
