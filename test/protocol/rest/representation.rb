# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/rest/representation"

require "protocol/http/request"
require "protocol/http/response"

require "json"

describe Protocol::REST::Representation do
	let(:parser) do
		Protocol::REST::Representation::Parser.build do |parser|
			parser.register("application/json") do |representation|
				JSON.parse(representation.body.join)
			end
		end
	end
	
	let(:representation_class) {subject[parser]}
	
	it "constructs a specialization with a parser" do
		expect(representation_class.parser).to be_equal(parser)
	end
	
	it "parses an inbound request representation" do
		request = Protocol::HTTP::Request["QUERY", "/users", {"content-type" => "application/json"}, ['{"user":{"name":"Samuel"}}']]
		representation = representation_class.for(request)
		
		expect(representation.message).to be_equal(request)
		expect(representation.metadata).to be_equal(request.headers)
		expect(representation["user"]["name"]).to be == "Samuel"
	end
	
	it "parses an inbound response representation" do
		response = Protocol::HTTP::Response[200, {"content-type" => "application/json"}, ['{"status":"okay"}']]
		representation = representation_class.for(response)
		
		expect(representation.message).to be_equal(response)
		expect(representation.metadata).to be_equal(response.headers)
		expect(representation["status"]).to be == "okay"
	end
	
	it "parses the value once" do
		count = 0
		parser = Protocol::REST::Representation::Parser.build do |parser|
			parser.register("text/plain") do |representation|
				count += 1
				representation.body.join
			end
		end
		
		response = Protocol::HTTP::Response[200, {"content-type" => "text/plain"}, ["Hello World"]]
		representation = subject.for(response, parser: parser)
		
		expect(representation.value).to be == "Hello World"
		expect(representation.value).to be == "Hello World"
		expect(count).to be == 1
	end
	
	it "memoizes nil values" do
		count = 0
		parser = Protocol::REST::Representation::Parser.build do |parser|
			parser.register("application/x-empty") do
				count += 1
				nil
			end
		end
		
		representation = subject.new(metadata: {"content-type" => "application/x-empty"}, parser: parser)
		
		expect(representation.value).to be_nil
		expect(representation.value).to be_nil
		expect(count).to be == 1
	end
	
	it "accepts an existing value without parsing" do
		value = {"name" => "Samuel"}
		representation = subject.new(value: value)
		
		expect(representation.value).to be_equal(value)
		expect(representation["name"]).to be == "Samuel"
	end
	
	it "parses content type parameters" do
		response = Protocol::HTTP::Response[200, {"content-type" => "application/json; charset=utf-8"}, ["{}"]]
		representation = representation_class.for(response)
		
		expect(representation.content_type.name).to be == "application/json"
		expect(representation.content_type.parameters).to be == {"charset" => "utf-8"}
		expect(representation.value).to be == {}
	end
	
	it "supports compatible media ranges" do
		parser = Protocol::REST::Representation::Parser.build do |parser|
			parser.register("text/*") do |representation|
				representation.body.join
			end
		end
		
		response = Protocol::HTTP::Response[200, {"content-type" => "text/plain"}, ["Hello World"]]
		representation = subject.for(response, parser: parser)
		
		expect(representation.value).to be == "Hello World"
	end
	
	it "rejects unsupported media types" do
		response = Protocol::HTTP::Response[200, {"content-type" => "text/plain"}, ["Hello World"]]
		representation = representation_class.for(response)
		
		expect do
			representation.value
		end.to raise_exception(Protocol::REST::UnsupportedMediaTypeError) do |error|
			expect(error.media_type.name).to be == "text/plain"
		end
	end
	
	it "rejects a missing content type" do
		response = Protocol::HTTP::Response[200, {}, ["Hello World"]]
		representation = representation_class.for(response)
		
		expect do
			representation.value
		end.to raise_exception(Protocol::REST::UnsupportedMediaTypeError, message: be == "Missing content type!")
	end
end
