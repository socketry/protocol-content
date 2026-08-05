# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/content/json_parser"

require "stringio"

describe Protocol::Content::JSONParser do
	it "parses JSON" do
		parser = subject.new(symbolize_names: true)
		
		expect(parser.parse(StringIO.new('{"name":"Samuel"}'))).to be == {name: "Samuel"}
	end
	
	it "applies the encoded document size limit at its boundary" do
		parser = subject.new(size_limit: 4)
		
		expect(parser.parse(StringIO.new("[0]"))).to be == [0]
		expect(parser.parse(StringIO.new("null"))).to be_nil
		
		expect do
			parser.parse(StringIO.new("[1,2]"))
		end.to raise_exception(Protocol::Content::ContentTooLargeError, message: be =~ /exceeded limit of 4/)
	end
	
	it "rejects a valid document followed by content beyond the size limit" do
		parser = subject.new(size_limit: 4)
		
		expect do
			parser.parse(StringIO.new("null!"))
		end.to raise_exception(Protocol::Content::ContentTooLargeError, message: be =~ /exceeded limit of 4/)
	end
	
	it "allows the size limit to be disabled" do
		parser = subject.new(size_limit: nil)
		
		expect(parser.parse(StringIO.new("[1,2]"))).to be == [1, 2]
	end
	
	it "applies the document nesting depth limit at its boundary" do
		parser = subject.new(depth_limit: 2)
		
		expect(parser.parse(StringIO.new("[0]"))).to be == [0]
		expect(parser.parse(StringIO.new("[[0]]"))).to be == [[0]]
		
		expect do
			parser.parse(StringIO.new("[[[0]]]"))
		end.to raise_exception(Protocol::Content::ContentTooLargeError) do |error|
			expect(error.cause).to be_a(JSON::NestingError)
		end
	end
	
	it "limits document nesting depth by default" do
		json = ("[" * 33) + "null" + ("]" * 33)
		
		expect do
			subject.new.parse(StringIO.new(json))
		end.to raise_exception(Protocol::Content::ContentTooLargeError)
	end
	
	it "allows the depth limit to be disabled" do
		parser = subject.new(depth_limit: nil)
		json = ("[" * 101) + "null" + ("]" * 101)
		
		expect(parser.parse(StringIO.new(json))).to be_a(Array)
	end
end
