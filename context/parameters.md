# Content Parameters

This guide explains how to build a parameter model that interprets parsed content as operation-specific arguments using {ruby Protocol::Content::Parameters}.

## Declare Parameters

Parameter declarations define the input accepted by an operation without reproducing its database or domain model. Fields are optional by default, undeclared fields produce validation errors, and converted values are returned using string keys:

``` ruby
require "protocol/content"

parameters = Protocol::Content::Parameters.build do
	nested "user", required: true do
		field "name", String
		field "age", Integer
		upload "avatar"
	end
end
```

`required: true` requires the key to be present. It does not imply that the value may be `nil`; use `nullable: true` when `nil` is valid.

A nested declaration without a block accepts all key/value pairs beneath that key:

``` ruby
parameters = Protocol::Content::Parameters.build do
	nested "metadata"
end
```

Strictness is inherited by constrained nested declarations unless explicitly disabled. Build the parameters with `strict: false` when undeclared fields should instead be omitted.

## Declare Arrays

An array declaration without a block accepts and optionally converts each value:

``` ruby
parameters = Protocol::Content::Parameters.build do
	array "tags", String
	array "metadata"
end
```

Use a block to declare the fields accepted by each array element:

``` ruby
parameters = Protocol::Content::Parameters.build do
	array "users" do
		field "name", String, required: true
		field "age", Integer
	end
end
```

Validation errors for array elements include the element index in their path.

## Parse Parameters

{ruby Protocol::Content::Parameters::Model#parse} selects a content parser according to the media type, then filters, converts, and validates the parsed value:

``` ruby
result = parameters.parse(media_type, input)

if result.valid?
	user.update(result["user"])
else
	result.errors.each do |error|
		warn "#{error.path.join(".")}: #{error.code}"
	end
end
```

Validation errors are collected so an application can present all failures together. Each {ruby Protocol::Content::Parameters::Error} exposes a normalized `path`, machine-readable `code`, and additional `details`.

Use {ruby Protocol::Content::Parameters::Model#parse!} when invalid parameters should interrupt the operation. It returns the filtered argument hash or raises {ruby Protocol::Content::Parameters::ValidationError}, which retains the complete result:

``` ruby
arguments = parameters.parse!(media_type, input)
user.update(arguments["user"])
```

## Constrain Enumerations

Use an enumeration to accept an exact set of values:

``` ruby
parameters = Protocol::Content::Parameters.build do
	field "status", enumeration("draft", "published")
end
```

The hash form maps accepted input values to corresponding output values:

``` ruby
parameters = Protocol::Content::Parameters.build do
	field "enabled", enumeration("true" => true, "false" => false)
end
```

Enumeration matching is exact. Values not present in the enumeration produce an `invalid_type` error.

## Convert Fields

Built-in types match `String` values exactly and convert compatible values to `Integer` and `Float`. A custom converter can be supplied as any object responding to `#call`:

``` ruby
require "date"

date = ->(value){Date.iso8601(value)}

parameters = Protocol::Content::Parameters.build do
	field "date", date
end
```

A converter should return the converted value or raise `ArgumentError` or `TypeError`. Conversion failures are included in the result as `invalid_type` errors.

Reusable type conversions can be supplied to the builder. Converted values must match the declared type:

``` ruby
types = Protocol::Content::Parameters::TYPES.merge(
	Date => ->(value){Date.iso8601(value)}
)

parameters = Protocol::Content::Parameters.build(types:) do
	field "date", Date
end
```

## Handle Uploads

Uploads must be declared explicitly. Uploads not accepted by an upload declaration are consumed without invoking the upload handler and omitted from the resulting values. If the field name is also unknown, strict models report it as `unknown`; non-strict models silently discard it:

``` ruby
parameters = Protocol::Content::Parameters.build do
	nested "user" do
		upload "avatar",
			required: true,
			accept: ["image/jpeg", "image/png"],
			size_limit: 5 * 1024 * 1024
	end
	
	upload "pictures", multiple: true
end
```

When an upload handler is provided, its return value is inserted at the upload's nested form name:

``` ruby
result = parameters.parse(media_type, input) do |name, upload|
	stored = uploads.create(name, upload.filename, upload.headers)
	upload.copy_to(stored)
	
	stored
end
```

The yielded upload exposes `filename`, `headers`, `declared_media_type`, `media_type`, `size`, `each`, `copy_to`, and `save`. `save` creates a new file exclusively with private permissions and removes partial output when streaming fails. Always choose the destination path independently of the submitted filename.

The `accept:` option takes one or more {ruby Protocol::Media::Range media ranges}, including wildcards such as `image/*`; it does not accept filename-extension patterns. The upload's `declared_media_type` is supplied by the client. When it is absent or `application/octet-stream`, `media_type` is inferred from the submitted filename using {ruby Protocol::Media::Registry}. A specific declared media type takes precedence over the filename.

Both the declared media type and filename are untrusted metadata. Media range matching is useful for classification and early rejection, but it does not validate the uploaded bytes. Inspect, decode, or sanitize the content when its actual format matters. Field size limits complement the parser's transport-wide safety limits and are enforced even when the handler does not consume the upload itself.

For an upload named `user[avatar]`, the stored object is available as `result.dig("user", "avatar")`. An `upload "pictures", multiple: true` declaration accepts `pictures[]` and collects each handler result in `result["pictures"]`. Without an upload handler, uploads are consumed and omitted from the resulting arguments.

Upload handlers run while content is being parsed, before validation of the complete argument hierarchy finishes. Applications should therefore use provisional storage or remove stored uploads when the resulting parameters are invalid.
