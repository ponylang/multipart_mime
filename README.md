# multipart_mime

A streaming multipart MIME parser for Pony, implementing RFC 2046.

## Status

multipart_mime is in development and has not yet been released.

## Installation

* Install [corral](https://github.com/ponylang/corral)
* `corral add github.com/ponylang/multipart_mime.git --version 0.1.0`
* `corral fetch` to fetch your dependencies
* `use "multipart_mime"` to include this package
* `corral run -- ponyc` to compile your application

## Usage

The simplest way to parse a multipart message is with `CollectParts`, which buffers all parts in memory and delivers them as an array:

```pony
use "multipart_mime"

actor Main
  new create(env: Env) =>
    let notify = CollectParts(
      {(parts: Array[CollectedPart val] val)(env) =>
        for part in parts.values() do
          match FormData.field_name(part.headers)
          | let name: String =>
            env.out.print(name + " = "
              + String.from_array(part.body))
          end
        end
      },
      {(err: MultipartParseError)(env) =>
        env.out.print("Error: " + err.string())
      })
    let parser = MultipartParser(notify, boundary)
    parser.parse(data)
    parser.finish()
```

For large uploads or streaming use cases, implement `MultipartNotify` directly to handle body data incrementally. See the [examples](examples/) for both approaches, custom configuration, and early termination.

## RFC Conformance

This parser follows RFC 2046 with a few deliberate deviations.

**Stricter than the RFC:**

* Transport padding after a boundary is capped at 256 bytes. RFC 2046 allows unlimited LWSP but that is a DoS vector via unbounded buffer growth.
* Configurable size limits on part headers, part bodies, preamble, and total part count. The RFC has no size limits.

**Modernized header handling (RFC 7230 over RFC 822):**

RFC 2046 references RFC 822 for header syntax. We follow the stricter rules from RFC 7230 instead:

* Obsolete header folding (continuation lines starting with whitespace) is rejected.
* Whitespace between the header field name and the colon is rejected.

**More permissive than the RFC:**

* Header field names are not validated as RFC 7230 tokens. Any byte sequence before the colon is accepted (except whitespace immediately before it). In practice, real-world headers are ASCII names, but the parser does not enforce this.

## API Documentation

[https://ponylang.github.io/multipart_mime](https://ponylang.github.io/multipart_mime)
