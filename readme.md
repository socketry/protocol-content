# Protocol::Content

Provides transport-independent abstractions for media-typed content representations.

[![Development Status](https://github.com/socketry/protocol-content/workflows/Test/badge.svg)](https://github.com/socketry/protocol-content/actions?workflow=Test)

## Usage

A representation associates encoded data with metadata describing that data. A parser selects an interpretation according to the representation's media type:

```ruby
require "protocol/content"
require "json"

parser = Protocol::Content::Parser.build do |parser|
	parser.register("application/json") do |representation|
		JSON.parse(representation.body.join)
	end
end

JSONRepresentation = Protocol::Content::Representation[parser]
```

Representations can be constructed symmetrically from request and response messages. The message only needs to expose `headers` and `body`:

```ruby
representation = JSONRepresentation.for(request)
representation["user"]["name"]

representation = JSONRepresentation.for(response)
representation.value
```

Parsing is lazy and memoized by each representation. Registered handlers receive the complete representation so they can inspect media-type parameters or stream the body when appropriate.

## Releases

Please see the [project releases](https://github.com/socketry/protocol-content/releases) for all releases.

## Contributing

We welcome contributions to this project.

1. Fork it.
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Commit your changes (`git commit -am 'Add some feature.'`).
4. Push to the branch (`git push origin my-new-feature`).
5. Create a new pull request.

### Running Tests

To run the test suite:

```shell
bundle exec sus
```

### Making Releases

To make a new release:

```shell
bundle exec bake gem:release:patch # or minor or major
```

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment or harmful behavior is not tolerated. If any issues arise, please inform the project maintainers.

## See Also

- [protocol-http](https://github.com/socketry/protocol-http) provides HTTP message abstractions.
- [protocol-media](https://github.com/socketry/protocol-media) provides media type abstractions.
- [async-rest](https://github.com/socketry/async-rest) provides asynchronous REST client abstractions.
