# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/rest"

describe Protocol::REST do
	it "has a version" do
		expect(Protocol::REST::VERSION).to be =~ /^\d+\.\d+\.\d+$/
	end
	
	it "provides representations" do
		expect(Protocol::REST::Representation).to be_a(Class)
		expect(Protocol::REST::Representation::Parser).to be_a(Class)
	end
end
