# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/content"

describe Protocol::Content::Parser do
	it "requires a callable handler" do
		parser = subject.new
		
		expect do
			parser.register("application/json", Object.new)
		end.to raise_exception(ArgumentError, message: be =~ /respond to #call/)
	end
	
	it "rejects a handler and block together" do
		parser = subject.new
		handler = proc{}
		
		expect do
			parser.register("application/json", handler){}
		end.to raise_exception(ArgumentError, message: be =~ /either a handler or a block/)
	end
	
	it "freezes parsers built with a block" do
		parser = subject.build do |parser|
			parser.register("application/json"){}
		end
		
		expect(parser).to be(:frozen?)
		expect do
			parser.register("text/plain"){}
		end.to raise_exception(FrozenError)
	end
end
