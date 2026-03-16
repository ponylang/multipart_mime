# Examples

Each subdirectory is a self-contained Pony program demonstrating a different part of the multipart_mime library. Ordered from simplest to most involved.

## [collect-parts](collect-parts/)

Collects all parts from a multipart message using the `CollectParts` convenience handler. Parts are buffered in memory and delivered as an array when parsing finishes. Start here if you're new to the library.

## [parse-form-data](parse-form-data/)

Parses a multipart/form-data message and prints each field's name, filename, content type, and body. Demonstrates `MultipartParser` with a custom `MultipartNotify` implementation and the `FormData` helper for extracting field metadata from `PartHeaders`.

## [custom-config](custom-config/)

Restricts parser limits using `MultipartConfig` to reject oversized parts early. Demonstrates setting `max_part_body_size` and `max_parts` to enforce upload constraints, and shows how the parser delivers a `PartBodyTooLarge` error when a part exceeds the limit.

## [early-stop](early-stop/)

Stops parsing as soon as a target field is found, using `stop()` to skip remaining parts. Demonstrates early termination from within a `part_end` callback and the cleanup responsibilities that come with it.

## [incremental-parse](incremental-parse/)

Feeds a multipart message to the parser in small fixed-size chunks, simulating data arriving over a network connection. Demonstrates that the parser handles arbitrarily chunked input and delivers the same events regardless of how the data is split.
