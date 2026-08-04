# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/content/default"

require "stringio"

describe Protocol::Content::Parser do
	BOUNDARY = "example-boundary"
	
	it "provides a frozen default parser" do
		parser = subject.default
		
		expect(parser).to be(:frozen?)
		expect(parser.parse("application/json", StringIO.new("{}"))).to be == {}
		expect(parser.parse("application/x-www-form-urlencoded", StringIO.new("name=Samuel"))).to be == {"name" => "Samuel"}
	end
	
	it "parses multipart form data by default" do
		body = <<~MULTIPART.gsub("\n", "\r\n")
			--#{BOUNDARY}
			Content-Disposition: form-data; name="name"
			
			Samuel
			--#{BOUNDARY}--
		MULTIPART
		
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		expect(subject.default.parse(media_type, StringIO.new(body))).to be == {"name" => "Samuel"}
	end
	
	it "streams multipart uploads through the caller's block" do
		body = <<~MULTIPART.gsub("\n", "\r\n")
			--#{BOUNDARY}
			Content-Disposition: form-data; name="file"; filename="hello.txt"
			Content-Type: text/plain
			
			hello
			--#{BOUNDARY}--
		MULTIPART
		
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		value = subject.default.parse(media_type, StringIO.new(body)) do |_name, upload|
			upload.each.to_a.join
		end
		
		expect(value).to be == {"file" => "hello"}
	end
	
	it "translates URL form limits" do
		body = StringIO.new((["a=1"] * 1025).join("&"))
		
		expect do
			subject.default.parse("application/x-www-form-urlencoded", body)
		end.to raise_exception(Protocol::Content::ContentTooLargeError) do |error|
			expect(error.cause).to be_a(Protocol::URL::LimitError)
		end
	end
	
	it "translates multipart limits" do
		parts = 129.times.map do |index|
			<<~PART
				--#{BOUNDARY}
				Content-Disposition: form-data; name="field#{index}"
				
				value
			PART
		end
		body = (parts.join + "--#{BOUNDARY}--\n").gsub("\n", "\r\n")
		media_type = "multipart/form-data; boundary=#{BOUNDARY}"
		
		expect do
			subject.default.parse(media_type, StringIO.new(body))
		end.to raise_exception(Protocol::Content::ContentTooLargeError) do |error|
			expect(error.cause).to be_a(Protocol::Multipart::LimitError)
		end
	end
	
	it "preserves errors raised by the caller's block" do
		expect do
			subject.default.parse("application/x-www-form-urlencoded", StringIO.new("a=1")) do
				raise RangeError, "Application range error!"
			end
		end.to raise_exception(RangeError, message: be == "Application range error!")
	end
	
	it "requires a multipart boundary" do
		expect do
			subject.default.parse("multipart/form-data", StringIO.new)
		end.to raise_exception(ArgumentError, message: be =~ /missing a boundary/)
	end
end
