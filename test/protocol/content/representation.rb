# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/content"

require "protocol/http/request"
require "protocol/http/response"

require "json"

describe Protocol::Content::Representation do
	let(:parser) do
		Protocol::Content::Parser.build do |parser|
			parser.register("application/json") do |representation|
				JSON.parse(representation.body.join)
			end
		end
	end
	
	let(:representation_class) {subject[parser]}
	
	it "constructs a specialization with a parser" do
		expect(representation_class.parser).to be_equal(parser)
	end
	
	it "constructs from explicit representation attributes" do
		message = Object.new
		metadata = {}
		body = []
		content_type = Protocol::Media::Type.for("application/json")
		representation = subject.new(body, content_type, metadata: metadata, message: message, parser: parser)
		
		expect(representation.message).to be_equal(message)
		expect(representation.metadata).to be_equal(metadata)
		expect(representation.body).to be_equal(body)
		expect(representation.content_type).to be_equal(content_type)
		expect(representation.parser).to be_equal(parser)
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
		parser = Protocol::Content::Parser.build do |parser|
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
		parser = Protocol::Content::Parser.build do |parser|
			parser.register("application/x-empty") do
				count += 1
				nil
			end
		end
		
		content_type = Protocol::Media::Type.for("application/x-empty")
		representation = subject.new(nil, content_type, parser: parser)
		
		expect(representation.value).to be_nil
		expect(representation.value).to be_nil
		expect(count).to be == 1
	end
	
	it "parses content type parameters" do
		response = Protocol::HTTP::Response[200, {"content-type" => "application/json; charset=utf-8"}, ["{}"]]
		representation = representation_class.for(response)
		
		expect(representation.content_type.name).to be == "application/json"
		expect(representation.content_type.parameters).to be == {"charset" => "utf-8"}
		expect(representation.value).to be == {}
	end
	
	it "extracts the content type when adapting a message" do
		metadata = {"content-type" => "application/json"}
		message = Struct.new(:headers, :body).new(metadata, nil)
		representation = subject.for(message)
		metadata["content-type"] = "text/plain"
		
		expect(representation.content_type.name).to be == "application/json"
	end
	
	it "supports compatible media ranges" do
		parser = Protocol::Content::Parser.build do |parser|
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
		end.to raise_exception(Protocol::Content::UnsupportedMediaTypeError) do |error|
			expect(error.media_type.name).to be == "text/plain"
		end
	end
	
	it "rejects a missing content type" do
		response = Protocol::HTTP::Response[200, {}, ["Hello World"]]
		representation = representation_class.for(response)
		
		expect do
			representation.value
		end.to raise_exception(Protocol::Content::UnsupportedMediaTypeError, message: be == "Missing content type!")
	end
end
