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
	
	it "builds immutable parameter models" do
		parameters = subject.build do
			field "name", String
		end
		
		expect(parameters).to be_a(subject::Model)
		expect(parameters).to be(:frozen?)
	end
	
	it "filters unknown fields and converts declared fields" do
		parameters = subject.build do
			field "name", String
			field "age", Integer
		end
		
		result = parse_json(parameters, '{"name":"Samuel","age":"42","admin":true}')
		
		expect(result).to be(:valid?)
		expect(result.value).to be == {"name" => "Samuel", "age" => 42}
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
		
		expect(result.value).to be == {"nullable" => nil}
		expect(result.errors.map(&:path)).to be == [["required"]]
	end
	
	it "matches string fields and converts floating point fields" do
		parameters = subject.build do
			field "name", String
			field "ratio", Float
		end
		
		result = parse_json(parameters, '{"name":123,"ratio":"1.5"}')
		
		expect(result.value).to be == {"ratio" => 1.5}
		expect(result.errors.map(&:path)).to be == [["name"]]
	end
	
	it "rejects values without a type conversion" do
		type = Class.new
		parameters = subject.build do
			field "value", type
		end
		
		result = parse_json(parameters, '{"value":"invalid"}')
		
		expect(result.errors.map(&:code)).to be == [:invalid_type]
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
		expect(result.value).to be == {
			"user" => {"name" => "Samuel", "age" => 42}
		}
		expect(result.dig("user", "age")).to be == 42
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
		
		expect(result.value).to be == {
			"metadata" => {"count" => 1, "labels" => ["a", "b"]}
		}
	end
	
	it "validates required, nullable, and invalid nested parameters" do
		parameters = subject.build do
			nested "required", required: true
			nested "nullable", nullable: true
			nested "nonnullable"
			nested "invalid"
		end
		
		result = parse_json(parameters, '{"nullable":null,"nonnullable":null,"invalid":"value"}')
		
		expect(result.value).to be == {"nullable" => nil}
		expect(result.errors.map(&:path)).to be == [["required"], ["nonnullable"], ["invalid"]]
		expect(result.errors.map(&:code)).to be == [:required, :invalid_type, :invalid_type]
	end
	
	it "rejects duplicate declarations" do
		expect do
			subject.build do
				field "name", String
				upload "name"
			end
		end.to raise_exception(ArgumentError, message: be =~ /already declared/)
	end
	
	it "accepts and converts array values" do
		parameters = subject.build do
			array "tags", String
			array "metadata"
		end
		
		result = parse_json(parameters, '{"tags":["one",2],"metadata":[{"enabled":true},[1,2]]}')
		
		expect(result.value).to be == {
			"tags" => ["one"],
			"metadata" => [{"enabled" => true}, [1, 2]],
		}
		expect(result.errors.map(&:path)).to be == [["tags", 1]]
	end
	
	it "validates nested array values" do
		parameters = subject.build(strict: true) do
			array "users", required: true do
				field "name", String, required: true
				field "age", Integer
			end
		end
		
		result = parse_json(parameters, '{"users":[{"name":"Samuel","age":"42"},{"age":"old","admin":true},null]}')
		
		expect(result.value).to be == {
			"users" => [{"name" => "Samuel", "age" => 42}, {}, {}],
		}
		expect(result.errors.map(&:path)).to be == [
			["users", 1, "name"],
			["users", 1, "age"],
			["users", 1, "admin"],
			["users", 2],
		]
	end
	
	it "validates array shape, nullability, and element conversion" do
		parameters = subject.build do
			array "required", required: true
			array "nullable", nullable: true
			array "nonnullable"
			array "invalid"
			array "numbers", Integer
		end
		
		result = parse_json(parameters, '{"nullable":null,"nonnullable":null,"invalid":{},"numbers":["1","bad",null]}')
		
		expect(result.value).to be == {"nullable" => nil, "numbers" => [1]}
		expect(result.errors.map(&:path)).to be == [["required"], ["nonnullable"], ["invalid"], ["numbers", 1], ["numbers", 2]]
	end
	
	it "parses URL-encoded arrays" do
		parameters = subject.build do
			array "tags", String
			array "users" do
				field "name", String
				field "age", Integer
			end
		end
		input = StringIO.new("tags[]=one&tags[]=two&users[][name]=Alice&users[][age]=30&users[][name]=Bob")
		
		result = parameters.parse("application/x-www-form-urlencoded", input)
		
		expect(result.value).to be == {
			"tags" => ["one", "two"],
			"users" => [{"name" => "Alice", "age" => 30}, {"name" => "Bob"}],
		}
	end
	
	it "rejects an array element type with nested fields" do
		expect do
			subject.build do
				array "values", String do
					field "name", String
				end
			end
		end.to raise_exception(ArgumentError, message: be =~ /element type and nested fields/)
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
	
	it "returns valid arguments from parse!" do
		parameters = subject.build do
			field "name", String
		end
		
		expect(parameters.parse!("application/json", StringIO.new('{"name":"Samuel"}'))).to be == {"name" => "Samuel"}
	end
	
	it "supports custom converters" do
		converter = ->(value){value.upcase}
		
		parameters = subject.build do
			field "code", converter
		end
		result = parse_json(parameters, '{"code":"abc"}')
		
		expect(result.value).to be == {"code" => "ABC"}
	end
	
	it "supports custom type mappings" do
		type = Class.new
		types = subject::TYPES.merge(type => ->(_value){type.new})
		
		parameters = subject.build(types:) do
			field "value", type
		end
		result = parse_json(parameters, '{"value":"custom"}')
		
		expect(result["value"]).to be_a(type)
	end
	
	it "collects custom converter failures" do
		converter = ->(_value){raise ArgumentError}
		parameters = subject.build do
			field "code", converter
		end
		
		result = parse_json(parameters, '{"code":"abc"}')
		
		expect(result.value).to be == {}
		expect(result.errors.map(&:code)).to be == [:invalid_type]
	end
	
	it "rejects implicit integer conversion" do
		parameters = subject.build do
			field "age", Integer
		end
		
		result = parse_json(parameters, '{"age":true}')
		
		expect(result.value).to be == {}
		expect(result.errors.map(&:code)).to be == [:invalid_type]
	end
	
	it "reports a non-object content value" do
		parameters = subject.build do
			field "name", String
		end
		result = parse_json(parameters, "[]")
		
		expect(result.value).to be == {}
		expect(result.errors.first.path).to be == []
		expect(result.errors.first.code).to be == :invalid_type
	end
	
	it "returns an empty valid result for empty form content" do
		parameters = subject.build do
			field "name", String
		end
		
		result = parameters.parse("application/x-www-form-urlencoded", StringIO.new)
		
		expect(result).to be(:valid?)
		expect(result.value).to be == {}
	end
	
	it "inserts handled uploads using their nested form names" do
		parameters = subject.build(strict: true) do
			nested "user" do
				field "name", String
				upload "avatar"
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
		expect(result.value).to be == {
			"user" => {
				"name" => "Samuel",
				"avatar" => {name: "avatar.txt", content: "avatar"}
			}
		}
	end
	
	it "inserts handled uploads into array elements" do
		parameters = subject.build do
			array "users" do
				field "name", String
				upload "avatar"
			end
		end
		body = multipart_body(
			[{"Content-Disposition" => 'form-data; name="users[][name]"'}, "Samuel"],
			[
				{
					"Content-Disposition" => 'form-data; name="users[][avatar]"; filename="avatar.txt"',
					"Content-Type" => "text/plain"
				},
				"avatar"
			]
		)
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		
		result = parameters.parse(media_type, StringIO.new(body)) do |_name, upload|
			{name: upload.filename, content: upload.each.to_a.join}
		end
		
		expect(result.value).to be == {
			"users" => [{
				"name" => "Samuel",
				"avatar" => {name: "avatar.txt", content: "avatar"},
			}],
		}
	end
	
	it "collects handled upload arrays" do
		parameters = subject.build do
			uploads "pictures"
		end
		body = multipart_body(
			[{
				"Content-Disposition" => 'form-data; name="pictures[]"; filename="one.txt"',
				"Content-Type" => "text/plain"
			}, "one"],
			[{
				"Content-Disposition" => 'form-data; name="pictures[]"; filename="two.txt"',
				"Content-Type" => "text/plain"
			}, "two"]
		)
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		
		result = parameters.parse(media_type, StringIO.new(body)) do |_name, upload|
			{filename: upload.filename, content: upload.each.to_a.join}
		end
		
		expect(result.value).to be == {
			"pictures" => [
				{filename: "one.txt", content: "one"},
				{filename: "two.txt", content: "two"},
			],
		}
	end
	
	it "supports nested upload arrays" do
		parameters = subject.build do
			nested "gallery" do
				uploads "pictures"
			end
		end
		body = multipart_body([{
			"Content-Disposition" => 'form-data; name="gallery[pictures][]"; filename="picture.txt"',
			"Content-Type" => "text/plain"
		}, "picture"])
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		
		result = parameters.parse(media_type, StringIO.new(body)) do |_name, upload|
			upload.each.to_a.join
		end
		
		expect(result.value).to be == {"gallery" => {"pictures" => ["picture"]}}
	end
	
	it "preserves nil returned by the upload handler" do
		parameters = subject.build do
			upload "avatar"
		end
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
		
		expect(result.value).to be == {"avatar" => nil}
	end
	
	it "does not pass undeclared uploads to the handler" do
		parameters = subject.build(strict: true) do
			field "name", String
		end
		body = multipart_body([
			{
				"Content-Disposition" => 'form-data; name="avatar"; filename="avatar.txt"',
				"Content-Type" => "text/plain"
			},
			"avatar"
		])
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		called = false
		
		result = parameters.parse(media_type, StringIO.new(body)) do
			called = true
		end
		
		expect(called).to be == false
		expect(result.value).to be == {}
		expect(result.errors.map(&:path)).to be == [["avatar"]]
		expect(result.errors.map(&:code)).to be == [:unknown]
	end
	
	it "rejects undeclared nested uploads" do
		parameters = subject.build(strict: true) do
			nested "user" do
				field "name", String
			end
		end
		body = multipart_body([
			{
				"Content-Disposition" => 'form-data; name="user[avatar]"; filename="avatar.txt"',
				"Content-Type" => "text/plain"
			},
			"avatar"
		])
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		
		result = parameters.parse(media_type, StringIO.new(body)) do
			raise "The handler should not be called!"
		end
		
		expect(result.value).to be == {"user" => {}}
		expect(result.errors.map(&:path)).to be == [["user", "avatar"]]
	end
	
	it "validates upload declarations" do
		parameters = subject.build do
			upload "avatar", required: true
		end
		
		missing = parse_json(parameters, "{}")
		invalid = parse_json(parameters, '{"avatar":"not an upload"}')
		
		expect(missing.errors.map(&:code)).to be == [:required]
		expect(invalid.errors.map(&:code)).to be == [:invalid_type]
	end
	
	it "requires handled uploads" do
		parameters = subject.build do
			upload "avatar", required: true
		end
		body = multipart_body([
			{
				"Content-Disposition" => 'form-data; name="avatar"; filename="avatar.txt"',
				"Content-Type" => "text/plain"
			},
			"avatar"
		])
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		
		result = parameters.parse(media_type, StringIO.new(body))
		
		expect(result.value).to be == {}
		expect(result.errors.map(&:code)).to be == [:required]
	end
	
	it "requires at least one handled upload in a collection" do
		parameters = subject.build do
			uploads "pictures", required: true
		end
		body = multipart_body([{
			"Content-Disposition" => 'form-data; name="pictures[]"; filename="picture.txt"',
			"Content-Type" => "text/plain"
		}, "picture"])
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		
		result = parameters.parse(media_type, StringIO.new(body))
		
		expect(result.value).to be == {"pictures" => []}
		expect(result.errors.map(&:code)).to be == [:required]
	end
	
	it "rejects regular values in upload collections" do
		parameters = subject.build do
			uploads "pictures", required: true
		end
		
		missing = parse_json(parameters, "{}")
		invalid_shape = parse_json(parameters, '{"pictures":"picture"}')
		invalid_item = parse_json(parameters, '{"pictures":["picture"]}')
		
		expect(missing.errors.map(&:code)).to be == [:required]
		expect(invalid_shape.errors.map(&:path)).to be == [["pictures"]]
		expect(invalid_item.value).to be == {"pictures" => []}
		expect(invalid_item.errors.map(&:path)).to be == [["pictures", 0], ["pictures"]]
	end
	
	it "rejects uploads targeting non-upload declarations" do
		parameters = subject.build do
			field "title", String
			nested "metadata"
			array "attachments"
			array "users" do
				upload "avatar"
			end
		end
		body = multipart_body(
			[{
				"Content-Disposition" => 'form-data; name="title"; filename="title.txt"',
				"Content-Type" => "text/plain"
			}, "title"],
			[{
				"Content-Disposition" => 'form-data; name="metadata[avatar]"; filename="avatar.txt"',
				"Content-Type" => "text/plain"
			}, "avatar"],
			[{
				"Content-Disposition" => 'form-data; name="attachments[]"; filename="attachment.txt"',
				"Content-Type" => "text/plain"
			}, "attachment"],
			[{
				"Content-Disposition" => 'form-data; name="users[avatar]"; filename="avatar.txt"',
				"Content-Type" => "text/plain"
			}, "avatar"]
		)
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		
		result = parameters.parse(media_type, StringIO.new(body)) do
			raise "The handler should not be called!"
		end
		
		expect(result.value).to be == {"metadata" => {}, "attachments" => []}
		expect(result.errors.map(&:path)).to be == [["users"]]
	end
	
	it "discards and omits declared uploads without a handler" do
		parameters = subject.build(strict: true) do
			field "name", String
			upload "avatar"
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
		expect(result.value).to be == {"name" => "Samuel"}
	end
end
