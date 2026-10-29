primitive InvalidBoundary
  """
  The boundary string is invalid per RFC 2046: empty, longer than 70
  characters, ends with a space, or contains a character outside the
  allowed set.
  """
  fun string(): String => "invalid boundary"

primitive MalformedHeader
  """
  A part header line does not conform to RFC 7230 header field syntax:
  missing the colon separator, has whitespace before the colon, or uses
  obsolete folding (line starting with linear whitespace).
  """
  fun string(): String => "malformed header"

primitive HeadersTooLarge
  """
  The accumulated header bytes for a single part exceed the configured
  `max_header_size` limit.
  """
  fun string(): String => "headers too large"

primitive PartBodyTooLarge
  """
  A part's body exceeds the configured `max_part_body_size` limit.
  """
  fun string(): String => "part body too large"

primitive TooManyParts
  """
  The number of parts exceeds the configured `max_parts` limit.
  """
  fun string(): String => "too many parts"

primitive PreambleTooLarge
  """
  The preamble data before the first boundary exceeds the configured
  `max_preamble_size` limit.
  """
  fun string(): String => "preamble too large"

primitive MalformedBoundaryLine
  """
  A boundary line has excessive transport padding or is otherwise
  structurally invalid beyond what the boundary string itself allows.
  """
  fun string(): String =>
    "malformed boundary line"

primitive UnexpectedEnd
  """
  The input stream ended before the close delimiter was found.
  """
  fun string(): String => "unexpected end of input"

type MultipartParseError is
  ( InvalidBoundary
  | MalformedHeader
  | HeadersTooLarge
  | PartBodyTooLarge
  | TooManyParts
  | PreambleTooLarge
  | MalformedBoundaryLine
  | UnexpectedEnd )
  """
  Union of all parse errors that can occur during multipart parsing.
  Each variant is a primitive implementing `Stringable`.
  """
