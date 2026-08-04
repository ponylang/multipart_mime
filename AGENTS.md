# multipart_mime

An RFC 2046 streaming multipart MIME parser for Pony.

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

## Prose model

If you are running on an Anthropic model, use `claude-opus-4-6` for writing comments, documentation, and other prose. Prose quality from Anthropic models dropped starting with Opus 4.7 and has gotten worse with each subsequent release.

## Building and testing

```
make          # build + run tests
make test     # same as make
make examples # build all examples
make clean    # clean build artifacts and corral deps
```

Run a single test by name: `make test-one t="parser/single part"`.

## Architecture

`MultipartParser` is a thin public wrapper over the state machine in `_MultipartParserImpl`. The impl exposes its state fields publicly on purpose, so the state classes can reach them — don't privatize them to tidy up, or the state machine breaks; the wrapper is what keeps them off the library's public surface.

`_failed` means "stop all processing," and on the error path it also guards against delivering the error twice. The subtlety: an invalid boundary sets the state to `_Failed` but leaves `_failed = false`, so the error is delivered on the first `parse()` or `finish()` call rather than at construction — don't move that delivery into the constructor.

## Conventions

- `PartHeaders.create` expects already-lowercased header *names* (values are stored verbatim). The parser lowercases names for you, but a hand-built test fixture must.
- `_Unreachable()` for impossible code paths.
- `\nodoc\` on test classes.
