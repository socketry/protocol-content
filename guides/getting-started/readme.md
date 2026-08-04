# Getting Started

This guide explains how to parse media-typed content using built-in and custom parsers.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add protocol-content
~~~

## Parse Content

A {ruby Protocol::Content::Parser} selects an interpretation according to the media type:

``` ruby
require "protocol/content"
require "json"

parser = Protocol::Content::Parser.build do |parser|
	parser.register("application/json") do |input|
		JSON.parse(input.read)
	end
end

value = File.open("document.json") do |input|
	parser.parse("application/json", input)
end
```

The caller owns media-type extraction and adapts the encoded body to a readable IO-like input. This keeps parsing independent of request, response, and transport abstractions. Registered handlers receive the readable input and parsed {ruby Protocol::Media::Type}. Applications decide whether and where parsed values should be memoized.

## Parse Protocol HTTP Bodies

A `Protocol::HTTP::Body::Readable` can be adapted to a readable stream using `#to_io`. The caller must close that stream after parsing, passing through any parser error:

``` ruby
media_type = request.headers["content-type"]
input = request.body.to_io

begin
	value = parser.parse(media_type, input)
rescue => error
	raise
ensure
	input.close_read(error)
end
```

This example specifically assumes a `Protocol::HTTP` body. The stream's `#close_read` method releases its input buffer and invokes `#close(error)` on the underlying body. Generic IO-like parser inputs do not necessarily provide this interface.

## Default Parsers

The default parser supports JSON, URL-encoded forms, and multipart forms with bounded defaults:

``` ruby
require "protocol/content/default"

value = Protocol::Content::Parser.default.parse(
	media_type,
	input,
)
```

The format libraries are included as dependencies, so these defaults are available from a normal installation.

## Configure Limits

Format parsers can be configured explicitly for endpoint-specific limits:

``` ruby
require "protocol/content/json_parser"

json_parser = Protocol::Content::JSONParser.new(
	size_limit: 4 * 1024 * 1024,
	depth_limit: 32,
)

parser = Protocol::Content::Parser.build do |parser|
	parser.register("application/json") do |input|
		json_parser.parse(input)
	end
end
```

Limits are inclusive. Content at the configured limit is accepted, while content exceeding it raises {ruby Protocol::Content::ContentTooLargeError}.

## Stream Multipart Uploads

Multipart fields can be collected into {ruby Protocol::URL::FormData::Nested} while file uploads are streamed to application-managed storage. The value returned by the block is assigned to the nested result:

``` ruby
require "protocol/content/default"

form_data = Protocol::Content::Parser.default.parse(media_type, input) do |name, value|
	case value
	when Protocol::Multipart::FormData::Upload
		upload = uploads.create(name, value.filename, value.headers)
		
		value.each do |chunk|
			upload.write(chunk)
		end
		
		upload
	when String
		value
	end
end
```

Here, `uploads` represents an application storage interface. The parser yields a `String` for each buffered field and a {ruby Protocol::Multipart::FormData::Upload} for each file upload. The value returned by the block is stored in the nested result.

An upload can only be read during its block invocation. After the block returns, the parser consumes and discards any unread upload bytes while continuing to enforce the upload and total size limits. Applications must therefore consume uploads within the block when they need to persist their contents.
