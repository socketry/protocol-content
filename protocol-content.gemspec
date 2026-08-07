# frozen_string_literal: true

require_relative "lib/protocol/content/version"

Gem::Specification.new do |spec|
	spec.name = "protocol-content"
	spec.version = Protocol::Content::VERSION
	
	spec.summary = "Provides parsing for media-typed content."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/protocol-content"
	
	spec.metadata = {
		"bug_tracker_uri" => "https://github.com/socketry/protocol-content/issues",
		"changelog_uri" => "https://github.com/socketry/protocol-content/blob/main/releases.md",
		"documentation_uri" => "https://socketry.github.io/protocol-content/",
		"source_code_uri" => "https://github.com/socketry/protocol-content.git",
	}
	
	spec.files = Dir.glob(["{lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.3"
	
	spec.add_dependency "json", "~> 2.0"
	spec.add_dependency "protocol-media", "~> 0.1"
	spec.add_dependency "protocol-multipart", "~> 0.7"
	spec.add_dependency "protocol-url", "~> 0.10"
end
