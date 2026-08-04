# frozen_string_literal: true

require_relative "lib/protocol/content/version"

Gem::Specification.new do |spec|
	spec.name = "protocol-content"
	spec.version = Protocol::Content::VERSION
	
	spec.summary = "Provides abstractions for media-typed content representations."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/socketry/protocol-content"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/protocol-content/",
		"source_code_uri" => "https://github.com/socketry/protocol-content.git",
	}
	
	spec.files = Dir.glob(["{lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.3"
	
	spec.add_dependency "protocol-media", "~> 0.1"
end
