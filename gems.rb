# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

source "https://rubygems.org"

gemspec

group :maintenance, optional: true do
	gem "bake-modernize"
	gem "bake-gem"
	gem "bake-releases"
	
	gem "utopia-project", "~> 0.18"
	gem "decode"
end

group :test do
	gem "covered"
	gem "sus"
	
	gem "bake-test"
end

gem "rubocop", "~> 1.88", group: :test
gem "rubocop-md", "~> 2.0", group: :test
gem "rubocop-socketry", "~> 0.11.0", group: :test
