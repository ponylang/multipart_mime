"""
Multipart MIME parsing for Pony.

# Getting Started

There are two ways to use this library, depending on whether you need
streaming access to part bodies or prefer to work with complete parts.

## Streaming (recommended for large uploads)

Implement `MultipartNotify` and create a `MultipartParser`:

```pony
class ref MyHandler is MultipartNotify
  fun ref part_begin(headers: PartHeaders val) =>
    // Inspect headers to decide what to do with this part
    match FormData.field_name(headers)
    | let name: String => // ...
    end

  fun ref body_chunk(data: Array[U8] val) =>
    // Process body data incrementally
    None

  fun ref part_end() =>
    // Finalize the current part
    None

  fun ref finished() =>
    // All parts parsed successfully
    None

  fun ref parse_error(err: MultipartParseError) =>
    // Handle the error
    None

// Drive the parser with incoming data:
let parser = MultipartParser(MyHandler, boundary)
parser.parse(chunk1)
parser.parse(chunk2)
parser.finish()
```

## Buffered (simpler, for small payloads)

Use `CollectParts` to accumulate all parts in memory:

```pony
let notify = CollectParts(
  {(parts: Array[CollectedPart val] val) =>
    for part in parts.values() do
      match FormData.field_name(part.headers)
      | let name: String => // use name and part.body
      end
    end
  },
  {(err: MultipartParseError) =>
    // handle error
    None
  })
let parser = MultipartParser(notify, boundary)
parser.parse(data)
parser.finish()
```

Use `FormData` to extract form-data metadata (field names, filenames)
from part headers.

## Scope

This library parses the multipart body format. It does not:

- Decode Content-Transfer-Encoding (base64, quoted-printable) — body
  bytes are delivered raw
- Handle nested multipart recursion — create a second parser for
  nested parts
- Sanitize filenames — platform-specific, caller's responsibility
- Support `filename*` (RFC 5987) — prohibited for form-data by
  RFC 7578
- Apply multipart/digest Content-Type defaults — RFC 2046 section
  5.1.6 specifies message/rfc822, not text/plain, for digest subparts
- Tolerate bare LF line endings — strict CRLF per RFC 2046
- Extract the boundary from Content-Type headers — caller provides
  the boundary string directly
"""
