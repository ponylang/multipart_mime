# multipart_mime

RFC 2046 streaming multipart MIME parser for Pony.

## Building

```
make          # build and run tests
make test     # same as above
make examples # build all examples
make clean    # clean build artifacts and corral deps
```

Run a single test: `make test-one t="parser/callback ordering"`

## Architecture

Single package `multipart_mime` with a trait-based state machine:

- `MultipartParser` — public API wrapper, delegates to `_MultipartParserImpl`
- `_MultipartParserImpl` — internal parser with public fields (accessed by state classes in the same package; hidden from library users by the wrapper)
- `_ParserState` — interface for state classes: `_ExpectPreamble`, `_ExpectPartHeaders`, `_ExpectPartBody`, `_Epilogue`, `_Failed`
- `_ParseResult` — union type returned by state transitions: `_ParseContinue | _ParseNeedMore | MultipartParseError`

The `_failed` flag on `_MultipartParserImpl` has dual meaning: "an error has been delivered" and "stop all processing." The initial `_Failed` state (invalid boundary) starts with `_failed = false` — the error is delivered on the first `parse()` or `finish()` call.

## Conventions

- `_Unreachable` primitive for impossible code paths (mort pattern with project issues URL)
- `PartHeaders.create` takes lowercased name/value pairs — the parser lowercases automatically, but the public constructor lets downstream code build test fixtures
- Error types are a closed union of primitives (`MultipartParseError`), not a marker trait
- All test classes have `\nodoc\` on the declaration line
- Tests in `_test*.pony` files; property-based tests in `_test_parser_props.pony`
- `CollectParts` tests are colocated with `FormData` tests in `_test_form_data.pony`
