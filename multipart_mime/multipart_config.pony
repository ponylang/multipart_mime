class val MultipartConfig
  """
  Limits applied during multipart parsing.

  Defaults are suitable for typical multipart/form-data uploads:
  8 KiB header block per part, 10 MiB body per part, 100 parts maximum,
  8 KiB preamble limit.
  """
  let max_header_size: USize
  let max_part_body_size: USize
  let max_parts: USize
  let max_preamble_size: USize

  new val create(
    max_header_size': USize = 8192,
    max_part_body_size': USize = 10_485_760,
    max_parts': USize = 100,
    max_preamble_size': USize = 8192)
  =>
    """
    Create a configuration with the given limits. All parameters
    are optional and default to values suitable for typical
    multipart/form-data uploads.
    """
    max_header_size = max_header_size'
    max_part_body_size = max_part_body_size'
    max_parts = max_parts'
    max_preamble_size = max_preamble_size'
