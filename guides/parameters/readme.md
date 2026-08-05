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

Uploads must be declared explicitly. Undeclared uploads are consumed and omitted without invoking the upload handler:

``` ruby
parameters = Protocol::Content::Parameters.build do
	nested "user" do
		upload "avatar", required: true
	end
	
	uploads "pictures"
end
```

When an upload handler is provided, its return value is inserted at the upload's nested form name:

``` ruby
result = parameters.parse(media_type, input) do |name, upload|
	stored = uploads.create(name, upload.filename, upload.headers)
	
	upload.each do |chunk|
		stored.write(chunk)
	end
	
	stored
end
```

For an upload named `user[avatar]`, the stored object is available as `result.dig("user", "avatar")`. An `uploads "pictures"` declaration accepts `pictures[]` and collects each handler result in `result["pictures"]`. Without an upload handler, uploads are consumed and omitted from the resulting arguments.

Upload handlers run while content is being parsed, before validation of the complete argument hierarchy finishes. Applications should therefore use provisional storage or remove stored uploads when the resulting parameters are invalid.
