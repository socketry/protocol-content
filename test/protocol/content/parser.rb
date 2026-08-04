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
	
	it "parses content using a compatible handler" do
		media_type = nil
		input = Object.new
		parser = subject.build do |parser|
			parser.register("text/*") do |candidate, parsed_media_type|
				media_type = parsed_media_type
				candidate
			end
		end
		
		expect(parser.parse("text/plain; charset=utf-8", input)).to be_equal(input)
		expect(media_type.name).to be == "text/plain"
		expect(media_type.parameters).to be == {"charset" => "utf-8"}
	end
	
	it "forwards a block to the content handler" do
		parser = subject.build do |parser|
			parser.register("text/plain") do |input, _media_type, &block|
				block.call(input)
			end
		end
		
		value = parser.parse("text/plain", "hello") do |input|
			input.upcase
		end
		
		expect(value).to be == "HELLO"
	end
	
	it "rejects unsupported media types" do
		parser = subject.new
		
		expect do
			parser.parse("text/plain", Object.new)
		end.to raise_exception(Protocol::Content::UnsupportedMediaTypeError) do |error|
			expect(error.media_type.name).to be == "text/plain"
		end
	end
	
	it "rejects a missing media type" do
		parser = subject.new
		
		expect do
			parser.parse(nil, Object.new)
		end.to raise_exception(Protocol::Content::UnsupportedMediaTypeError, message: be == "Missing media type!")
	end
end
