# Protocol::Content

Provides transport-independent parsing for media-typed content.

[![Development Status](https://github.com/socketry/protocol-content/workflows/Test/badge.svg)](https://github.com/socketry/protocol-content/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/protocol-content/) for more details.

  - [Getting Started](https://socketry.github.io/protocol-content/guides/getting-started/index) - This guide explains how to parse media-typed content using built-in and custom parsers.
  - [Content Parameters](https://socketry.github.io/protocol-content/guides/parameters/index) - This guide explains how to interpret parsed content as operation-specific arguments.

## Releases

Please see the [project releases](https://socketry.github.io/protocol-content/releases/index) for all releases.

### v0.1.0

  - Add media-type parser dispatch for readable content.
  - Add JSON, URL-encoded form, and multipart form parsers with explicit convenient defaults.
  - Bound JSON input size and nesting depth using consistently named limits.
  - Add `ContentTooLargeError` for content parser limit violations.
  - Forward blocks to content handlers for incremental and streaming parsing.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature.'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create a new pull request.

### Running Tests

To run the test suite:

``` shell
bundle exec sus
```

### Making Releases

To make a new release:

``` shell
bundle exec bake gem:release:patch # or minor or major
```

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.

## See Also

  - [protocol-http](https://github.com/socketry/protocol-http) provides HTTP message abstractions.
  - [protocol-media](https://github.com/socketry/protocol-media) provides media type abstractions.
  - [async-rest](https://github.com/socketry/async-rest) provides asynchronous REST client abstractions.
