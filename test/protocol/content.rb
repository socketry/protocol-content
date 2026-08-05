# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/content"

describe Protocol::Content do
	it "has a version" do
		expect(Protocol::Content::VERSION).to be =~ /^\d+\.\d+\.\d+$/
	end
	
end
