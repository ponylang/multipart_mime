primitive InvalidBoundary
  """
  The boundary string is invalid per RFC 2046: empty, longer than 70
  characters, or contains a character outside the allowed set.
  """
  fun string(): String iso^ => "invalid boundary".clone()

primitive MalformedHeader
  """
  A part header line is syntactically invalid — missing the colon
  separator or uses obsolete folding (line starting with linear
  whitespace).
  """
  fun string(): String iso^ => "malformed header".clone()

primitive HeadersTooLarge
  """
  The accumulated header bytes for a single part exceed the configured
  `max_header_size` limit.
  """
  fun string(): String iso^ => "headers too large".clone()

primitive PartBodyTooLarge
  """
  A part's body exceeds the configured `max_part_body_size` limit.
  """
  fun string(): String iso^ => "part body too large".clone()

primitive TooManyParts
  """
  The number of parts exceeds the configured `max_parts` limit.
  """
  fun string(): String iso^ => "too many parts".clone()

primitive PreambleTooLarge
  """
  The preamble data before the first boundary exceeds the configured
  `max_preamble_size` limit.
  """
  fun string(): String iso^ => "preamble too large".clone()

primitive MalformedBoundaryLine
  """
  A boundary line has excessive transport padding or is otherwise
  structurally invalid beyond what the boundary string itself allows.
  """
  fun string(): String iso^ =>
    "malformed boundary line".clone()

primitive UnexpectedEnd
  """
  The input stream ended before the close delimiter was found.
  """
  fun string(): String iso^ => "unexpected end of input".clone()

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
