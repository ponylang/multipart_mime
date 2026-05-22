# multipart_mime

RFC 2046 streaming multipart MIME parser for Pony.

<!-- contributor-only -->
## Contributing with an AI assistant

This is a Pony project. The ponylang org maintains a set of LLM coding skills. Get set up with them before contributing:

- **Not set up yet?** Install them once:

  ```bash
  git clone https://github.com/ponylang/llm-skills.git
  cd llm-skills
  python install.py
  ```

- **Already set up?** Make sure you're on the latest. If you installed with the script above, `git pull` in the directory where you cloned `llm-skills` and the symlinked skills update automatically — if you set them up another way, refresh them however that setup expects.

See the [llm-skills README](https://github.com/ponylang/llm-skills) for details and other harnesses.

When you start working on this project, load the `pony-skills` skill — it tells your assistant which Pony skill to use for each task.

Read [CONTRIBUTING.md](CONTRIBUTING.md).
<!-- /contributor-only -->

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
