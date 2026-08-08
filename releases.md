# Releases

## v0.2.0

  - Add declarative content parameter filtering, conversion, validation, and upload handling.
  - Add exact enumeration validation and input mapping for content parameters.
  - Add field-specific upload media type and size constraints.

## v0.1.0

  - Add media-type parser dispatch for readable content.
  - Add JSON, URL-encoded form, and multipart form parsers with explicit convenient defaults.
  - Bound JSON input size and nesting depth using consistently named limits.
  - Add `ContentTooLargeError` for content parser limit violations.
  - Forward blocks to content handlers for incremental and streaming parsing.
