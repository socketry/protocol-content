# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/content"

require "stringio"

describe Protocol::Content::Parameters do
	BOUNDARY = "parameters-boundary"
	
	def parse_json(parameters, content)
		return parameters.parse("application/json", StringIO.new(content))
	end
	
	def multipart_body(*parts)
		body = parts.map do |headers, content|
			serialized_headers = headers.map{|name, value| "#{name}: #{value}"}.join("\n")
			"--#{BOUNDARY}\n#{serialized_headers}\n\n#{content}\n"
		end
		
		return (body.join + "--#{BOUNDARY}--\n").gsub("\n", "\r\n")
	end
	
	it "builds immutable parameter definitions" do
		parameters = subject.build do
			field "name", String
		end
		
		expect(parameters).to be(:frozen?)
		expect do
			parameters.field("age", Integer)
		end.to raise_exception(FrozenError)
	end
	
	it "filters unknown fields and converts declared fields" do
		parameters = subject.build do
			field "name", String
			field "age", Integer
		end
		
		result = parse_json(parameters, '{"name":"Samuel","age":"42","admin":true}')
		
		expect(result).to be(:valid?)
		expect(result.arguments).to be == {"name" => "Samuel", "age" => 42}
	end
	
	it "collects required, conversion, and unknown field errors" do
		parameters = subject.build(strict: true) do
			field "name", String, required: true
			field "age", Integer
		end
		
		result = parse_json(parameters, '{"age":"old","admin":true}')
		
		expect(result).not.to be(:valid?)
		expect(result.errors.map(&:path)).to be == [["name"], ["age"], ["admin"]]
		expect(result.errors.map(&:code)).to be == [:required, :invalid_type, :unknown]
	end
	
	it "distinguishes optional, required, and nullable fields" do
		parameters = subject.build do
			field "optional", String
			field "required", String, required: true
			field "nullable", String, nullable: true
		end
		
		result = parse_json(parameters, '{"required":null,"nullable":null}')
		
		expect(result.arguments).to be == {"nullable" => nil}
		expect(result.errors.map(&:path)).to be == [["required"]]
	end
	
	it "filters constrained nested parameters" do
		parameters = subject.build do
			nested "user", required: true do
				field "name", String
				field "age", Integer
			end
		end
		
		result = parse_json(parameters, '{"user":{"name":"Samuel","age":"42","admin":true}}')
		
		expect(result).to be(:valid?)
		expect(result.arguments).to be == {
			"user" => {"name" => "Samuel", "age" => 42}
		}
	end
	
	it "inherits strict validation in nested declarations" do
		parameters = subject.build(strict: true) do
			nested "user" do
				field "name", String
			end
		end
		
		result = parse_json(parameters, '{"user":{"name":"Samuel","admin":true}}')
		
		expect(result.errors.map(&:path)).to be == [["user", "admin"]]
		expect(result.errors.map(&:code)).to be == [:unknown]
	end
	
	it "accepts all values under an unconstrained nested parameter" do
		parameters = subject.build do
			nested "metadata"
		end
		
		result = parse_json(parameters, '{"metadata":{"count":1,"labels":["a","b"]}}')
		
		expect(result.arguments).to be == {
			"metadata" => {"count" => 1, "labels" => ["a", "b"]}
		}
	end
	
	it "raises an aggregate validation error" do
		parameters = subject.build do
			field "name", String, required: true
		end
		
		expect do
			parameters.parse!("application/json", StringIO.new("{}"))
		end.to raise_exception(subject::ValidationError) do |error|
			expect(error.result.errors.map(&:code)).to be == [:required]
		end
	end
	
	it "supports custom converters" do
		converter = Object.new
		def converter.convert(value)
			return value.upcase
		end
		
		parameters = subject.build do
			field "code", converter
		end
		result = parse_json(parameters, '{"code":"abc"}')
		
		expect(result.arguments).to be == {"code" => "ABC"}
	end
	
	it "reports a non-object content value" do
		parameters = subject.build do
			field "name", String
		end
		result = parse_json(parameters, "[]")
		
		expect(result.arguments).to be == {}
		expect(result.errors.first.path).to be == []
		expect(result.errors.first.code).to be == :invalid_type
	end
	
	it "returns an empty valid result for empty form content" do
		parameters = subject.build do
			field "name", String
		end
		
		result = parameters.parse("application/x-www-form-urlencoded", StringIO.new)
		
		expect(result).to be(:valid?)
		expect(result.arguments).to be == {}
	end
	
	it "inserts handled uploads using their nested form names" do
		parameters = subject.build(strict: true) do
			nested "user" do
				field "name", String
			end
		end
		body = multipart_body(
			[{"Content-Disposition" => 'form-data; name="user[name]"'}, "Samuel"],
			[
				{
					"Content-Disposition" => 'form-data; name="user[avatar]"; filename="avatar.txt"',
					"Content-Type" => "text/plain"
				},
				"avatar"
			]
		)
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		
		result = parameters.parse(media_type, StringIO.new(body)) do |name, upload|
			expect(name).to be == "user[avatar]"
			{name: upload.filename, content: upload.each.to_a.join}
		end
		
		expect(result).to be(:valid?)
		expect(result.arguments).to be == {
			"user" => {
				"name" => "Samuel",
				"avatar" => {name: "avatar.txt", content: "avatar"}
			}
		}
	end
	
	it "preserves nil returned by the upload handler" do
		parameters = subject.build{}
		body = multipart_body([
			{
				"Content-Disposition" => 'form-data; name="avatar"; filename="avatar.txt"',
				"Content-Type" => "text/plain"
			},
			"avatar"
		])
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		
		result = parameters.parse(media_type, StringIO.new(body)) do |_name, upload|
			upload.discard
			nil
		end
		
		expect(result.arguments).to be == {"avatar" => nil}
	end
	
	it "discards and omits unhandled uploads" do
		parameters = subject.build do
			field "name", String
		end
		body = multipart_body(
			[{"Content-Disposition" => 'form-data; name="name"'}, "Samuel"],
			[
				{
					"Content-Disposition" => 'form-data; name="avatar"; filename="avatar.txt"',
					"Content-Type" => "text/plain"
				},
				"avatar"
			]
		)
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		
		result = parameters.parse(media_type, StringIO.new(body))
		
		expect(result).to be(:valid?)
		expect(result.arguments).to be == {"name" => "Samuel"}
	end
end
