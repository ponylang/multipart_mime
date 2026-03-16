use "pony_test"

primitive \nodoc\ _ToVal
  fun apply(s: String val): Array[U8] val =>
    s.array()

class \nodoc\ _TestSinglePart is UnitTest
  fun name(): String => "parser/single part"

  fun apply(h: TestHelper) =>
    let expected_body: Array[U8] val =
      "hello".array()
    let n =
      _CollectNotify(h
        where expect_parts' = 1,
        expect_bodies' = [expected_body])
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "Content-Type: text/plain\r\n"
          + "\r\nhello\r\n--boundary--"))
    h.assert_true(
      n.finished_called,
      "finished should be called")
    h.assert_false(
      n.error_called,
      "no error on success")

class \nodoc\ _TestMultipleParts is UnitTest
  fun name(): String => "parser/multiple parts"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 3)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n\r\npart1"
          + "\r\n--boundary\r\n\r\npart2"
          + "\r\n--boundary\r\n\r\npart3"
          + "\r\n--boundary--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)
    h.assert_eq[USize](3, n.parts_received)

class \nodoc\ _TestEmptyBody is UnitTest
  fun name(): String => "parser/empty body"

  fun apply(h: TestHelper) =>
    let expected_body: Array[U8] val =
      Array[U8]
    let n =
      _CollectNotify(h
        where expect_parts' = 1,
        expect_bodies' = [expected_body])
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "Content-Type: text/plain\r\n"
          + "\r\n\r\n--boundary--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)

class \nodoc\ _TestNoHeaders is UnitTest
  fun name(): String => "parser/no headers"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nbody"
          + "\r\n--boundary--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)
    h.assert_eq[USize](0, n.last_header_count)

class \nodoc\ _TestPreambleDiscarded is UnitTest
  fun name(): String => "parser/preamble discarded"

  fun apply(h: TestHelper) =>
    let expected_body: Array[U8] val =
      "body".array()
    let n =
      _CollectNotify(h
        where expect_parts' = 1,
        expect_bodies' = [expected_body])
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "This is preamble text.\r\n"
          + "--boundary\r\n\r\nbody"
          + "\r\n--boundary--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)

class \nodoc\ _TestEpilogueIgnored is UnitTest
  fun name(): String => "parser/epilogue ignored"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nbody"
          + "\r\n--boundary--"
          + "\r\nThis is epilogue."))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)

class \nodoc\ _TestTransportPadding is UnitTest
  fun name(): String => "parser/transport padding"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary  \t \r\n\r\nbody"
          + "\r\n--boundary--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)

class \nodoc\ _TestIncrementalFeeding is UnitTest
  fun name(): String => "parser/incremental feeding"

  fun apply(h: TestHelper) =>
    let expected_body: Array[U8] val =
      "hello".array()
    let n =
      _CollectNotify(h
        where expect_parts' = 1,
        expect_bodies' = [expected_body])
    let p = MultipartParser(n, "boundary")
    let msg =
      "--boundary\r\n"
        + "Content-Type: text/plain\r\n"
        + "\r\nhello\r\n--boundary--"
    // Feed one byte at a time
    for byte in msg.values() do
      p.parse(recover val [byte] end)
    end
    h.assert_true(
      n.finished_called,
      "finished should be called")
    h.assert_false(
      n.error_called,
      "no error on success")

class \nodoc\ _TestPartialBoundaryInBody is UnitTest
  fun name(): String =>
    "parser/partial boundary match in body"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let p = MultipartParser(n, "abc")
    p.parse(
      _ToVal(
        "--abc\r\n\r\nsome\r\n--abtext"
          + "\r\n--abc--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)

class \nodoc\ _TestInvalidBoundaryEmpty is UnitTest
  fun name(): String =>
    "parser/invalid boundary empty"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = InvalidBoundary)
    let p = MultipartParser(n, "")
    p.parse(_ToVal(""))
    h.assert_true(
      n.error_called,
      "error should be delivered for empty boundary")

class \nodoc\ _TestInvalidBoundaryTooLong is UnitTest
  fun name(): String =>
    "parser/invalid boundary too long"

  fun apply(h: TestHelper) =>
    let long =
      recover val String(71) .> append("a" * 71) end
    let n =
      _CollectNotify(
        h where expect_error' = InvalidBoundary)
    let p = MultipartParser(n, long)
    p.parse(_ToVal(""))
    h.assert_true(
      n.error_called,
      "error should be delivered for long boundary")

class \nodoc\ _TestInvalidBoundaryBadChar is UnitTest
  fun name(): String =>
    "parser/invalid boundary bad character"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = InvalidBoundary)
    let p = MultipartParser(n, "bound@ry")
    p.parse(_ToVal(""))
    h.assert_true(
      n.error_called,
      "error should be delivered for bad chars")

class \nodoc\ _TestMalformedHeaderNoColon is UnitTest
  fun name(): String =>
    "parser/malformed header no colon"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = MalformedHeader)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "this is not a header\r\n"
          + "\r\n\r\n--boundary--"))
    h.assert_true(
      n.error_called, "error should be delivered")

class \nodoc\ _TestMalformedHeaderObsFold is UnitTest
  fun name(): String =>
    "parser/malformed header obs-fold"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = MalformedHeader)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "Content-Type: text/plain\r\n"
          + "  continuation\r\n"
          + "\r\n\r\n--boundary--"))
    h.assert_true(
      n.error_called, "error should be delivered")

class \nodoc\ _TestUnexpectedEndInHeaders is UnitTest
  fun name(): String =>
    "parser/unexpected end in headers"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = UnexpectedEnd)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "Content-Type: text/plain\r\n"))
    p.finish()
    h.assert_true(
      n.error_called, "error should be delivered")

class \nodoc\ _TestUnexpectedEndInBody is UnitTest
  fun name(): String =>
    "parser/unexpected end in body"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = UnexpectedEnd)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nhello world"))
    p.finish()
    // part_begin + part_end must be balanced
    h.assert_true(
      n.part_end_called,
      "part_end should be called on truncation")
    h.assert_true(
      n.error_called, "error should be delivered")

class \nodoc\ _TestUnexpectedEndInPreamble is UnitTest
  fun name(): String =>
    "parser/unexpected end in preamble"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = UnexpectedEnd)
    let p = MultipartParser(n, "boundary")
    p.parse(_ToVal("preamble text"))
    p.finish()
    h.assert_true(
      n.error_called, "error should be delivered")

class \nodoc\ _TestHeadersTooLarge is UnitTest
  fun name(): String => "parser/headers too large"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = HeadersTooLarge)
    let small_config =
      MultipartConfig(where max_header_size' = 20)
    let p =
      MultipartParser(n, "boundary", small_config)
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "X-Very-Long-Header-Name:"
          + " very long value here\r\n"
          + "\r\n\r\n--boundary--"))
    h.assert_true(
      n.error_called, "error should be delivered")

class \nodoc\ _TestPartBodyTooLarge is UnitTest
  fun name(): String => "parser/part body too large"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = PartBodyTooLarge)
    let small_config =
      MultipartConfig(
        where max_part_body_size' = 5)
    let p =
      MultipartParser(n, "boundary", small_config)
    p.parse(
      _ToVal(
        "--boundary\r\n\r\n0123456789"
          + "\r\n--boundary--"))
    h.assert_true(
      n.error_called, "error should be delivered")

class \nodoc\ _TestTooManyParts is UnitTest
  fun name(): String => "parser/too many parts"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = TooManyParts)
    let small_config =
      MultipartConfig(where max_parts' = 1)
    let p =
      MultipartParser(n, "boundary", small_config)
    p.parse(
      _ToVal(
        "--boundary\r\n\r\np1"
          + "\r\n--boundary\r\n\r\np2"
          + "\r\n--boundary--"))
    h.assert_true(
      n.error_called, "error should be delivered")

class \nodoc\ _TestStop is UnitTest
  fun name(): String => "parser/stop"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 0)
    let p = MultipartParser(n, "boundary")
    p.stop()
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nbody"
          + "\r\n--boundary--"))
    h.assert_eq[USize](0, n.parts_received)

class \nodoc\ _TestEmptyMultipart is UnitTest
  fun name(): String =>
    "parser/empty multipart (close-delimiter only)"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 0)
    let p = MultipartParser(n, "boundary")
    p.parse(_ToVal("--boundary--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)
    h.assert_eq[USize](0, n.parts_received)

class \nodoc\ _TestMaxBoundaryLength is UnitTest
  fun name(): String =>
    "parser/max boundary length (70 chars)"

  fun apply(h: TestHelper) =>
    let boundary =
      recover val String(70) .> append("a" * 70) end
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let p = MultipartParser(n, boundary)
    let msg =
      recover val
        let s = Array[U8]
        for c in "--".values() do
          s.push(c)
        end
        for c in boundary.values() do
          s.push(c)
        end
        for c in
          "\r\n\r\nbody\r\n--".values()
        do
          s.push(c)
        end
        for c in boundary.values() do
          s.push(c)
        end
        for c in "--".values() do
          s.push(c)
        end
        s
      end
    p.parse(msg)
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)

class \nodoc\ _TestMultipleHeaders is UnitTest
  fun name(): String => "parser/multiple headers"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "Content-Type: text/plain\r\n"
          + "Content-Disposition:"
          + " form-data; name=\"field\"\r\n"
          + "X-Custom: value\r\n"
          + "\r\nbody\r\n--boundary--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)
    h.assert_eq[USize](3, n.last_header_count)

class \nodoc\ _TestCrlfOwnership is UnitTest
  """
  The CRLF before the boundary belongs to the
  boundary, not the body.
  """
  fun name(): String => "parser/CRLF ownership"

  fun apply(h: TestHelper) =>
    let expected_body: Array[U8] val =
      "body".array()
    let n =
      _CollectNotify(h
        where expect_parts' = 1,
        expect_bodies' = [expected_body])
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nbody"
          + "\r\n--boundary--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)

class \nodoc\ _TestFinishAfterComplete is UnitTest
  fun name(): String =>
    "parser/finish after complete parse is no-op"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nbody"
          + "\r\n--boundary--"))
    p.finish() // Should be a no-op
    h.assert_true(n.finished_called)
    h.assert_false(
      n.error_called,
      "no error after clean finish")

class \nodoc\ _TestTransportPaddingBetweenParts is UnitTest
  fun name(): String =>
    "parser/transport padding between parts"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 2)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n\r\npart1"
          + "\r\n--boundary  \t\r\n"
          + "\r\npart2"
          + "\r\n--boundary--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)
    h.assert_eq[USize](2, n.parts_received)

class \nodoc\ _TestBodyAtExactLimit is UnitTest
  fun name(): String =>
    "parser/body at exact size limit"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let config =
      MultipartConfig(
        where max_part_body_size' = 5)
    let p =
      MultipartParser(n, "boundary", config)
    p.parse(
      _ToVal(
        "--boundary\r\n\r\n01234"
          + "\r\n--boundary--"))
    h.assert_true(
      n.finished_called,
      "5-byte body at 5-byte limit should succeed")
    h.assert_false(n.error_called)

class \nodoc\ _TestFinishWithoutParse is UnitTest
  fun name(): String =>
    "parser/finish without any parse calls"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = UnexpectedEnd)
    let p = MultipartParser(n, "boundary")
    p.finish()
    h.assert_true(
      n.error_called,
      "error should be delivered")

class \nodoc\ _TestBinaryBodyData is UnitTest
  fun name(): String =>
    "parser/binary body with null and high bytes"

  fun apply(h: TestHelper) =>
    let binary_body: Array[U8] val =
      [as U8: 0x00; 0x01; 0xFF; 0x80; 0x7F]
    let n =
      _CollectNotify(h
        where expect_parts' = 1,
        expect_bodies' = [binary_body])
    let p = MultipartParser(n, "boundary")
    let msg =
      recover val
        let a = Array[U8]
        for c in "--boundary\r\n\r\n".values() do
          a.push(c)
        end
        a.push(0x00)
        a.push(0x01)
        a.push(0xFF)
        a.push(0x80)
        a.push(0x7F)
        for c in "\r\n--boundary--".values() do
          a.push(c)
        end
        a
      end
    p.parse(msg)
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)

class \nodoc\ _TestStopMidPart is UnitTest
  """
  Calling stop() mid-part silently stops event delivery.
  No part_end or finished callback fires — the caller is
  responsible for cleanup.
  """
  fun name(): String => "parser/stop mid-part"

  fun apply(h: TestHelper) =>
    let n = _StopOnBody(h)
    let p = MultipartParser(n, "boundary")
    n.set_parser(p)
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nsome body data"
          + "\r\n--boundary--"))
    h.assert_true(
      n.begin_called,
      "part_begin should be called")
    h.assert_false(
      n.end_called,
      "part_end should not fire after stop")
    h.assert_false(
      n.finished_called,
      "finished should not fire after stop")

class \nodoc\ _TestStopFromPartBegin is UnitTest
  """
  Calling stop() from part_begin suppresses all further
  events for that part — no body_chunk, part_end, or
  finished.
  """
  fun name(): String => "parser/stop from part_begin"

  fun apply(h: TestHelper) =>
    let n = _StopOnPartBegin(h)
    let p = MultipartParser(n, "boundary")
    n.set_parser(p)
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nsome body data"
          + "\r\n--boundary--"))
    h.assert_true(
      n.begin_called,
      "part_begin should be called")
    h.assert_false(
      n.body_called,
      "body_chunk should not fire after stop")
    h.assert_false(
      n.end_called,
      "part_end should not fire after stop")
    h.assert_false(
      n.finished_called,
      "finished should not fire after stop")

class \nodoc\ _TestStopFromPartEnd is UnitTest
  """
  Calling stop() from part_end at an inter-part boundary
  prevents any further part_begin or finished events.
  """
  fun name(): String => "parser/stop from part_end"

  fun apply(h: TestHelper) =>
    let n = _StopOnPartEnd(h)
    let p = MultipartParser(n, "boundary")
    n.set_parser(p)
    p.parse(
      _ToVal(
        "--boundary\r\n\r\npart1"
          + "\r\n--boundary\r\n\r\npart2"
          + "\r\n--boundary--"))
    h.assert_eq[USize](
      1,
      n.parts_begun,
      "only first part_begin should fire")
    h.assert_eq[USize](
      1,
      n.parts_ended,
      "only first part_end should fire")
    h.assert_false(
      n.finished_called,
      "finished should not fire after stop")

class \nodoc\ _TestMalformedBoundaryLine is UnitTest
  """
  A boundary line with transport padding exceeding the
  256-byte cap produces MalformedBoundaryLine.
  """
  fun name(): String =>
    "parser/malformed boundary line (excessive padding)"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = MalformedBoundaryLine)
    let p = MultipartParser(n, "boundary")
    let msg =
      recover val
        let a = Array[U8]
        for c in "--boundary".values() do
          a.push(c)
        end
        var i: USize = 0
        while i < 257 do
          a.push(' ')
          i = i + 1
        end
        a.push('')
        a.push('
')
        for c in "
body
--boundary--".values() do
          a.push(c)
        end
        a
      end
    p.parse(msg)
    h.assert_true(
      n.error_called,
      "error should be delivered")

class \nodoc\ _TestPreambleTooLarge is UnitTest
  fun name(): String => "parser/preamble too large"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = PreambleTooLarge)
    let config =
      MultipartConfig(
        where max_preamble_size' = 20)
    let p =
      MultipartParser(n, "boundary", config)
    // Preamble exceeds 20-byte limit. The scan
    // reaches the end of the buffer without finding
    // a boundary, and the limit fires.
    p.parse(
      _ToVal(
        "This preamble is way too long"
          + " for the limit."))
    h.assert_true(
      n.error_called,
      "error should be delivered")

class \nodoc\ _TestMalformedBoundaryTermination is UnitTest
  """
  Regression test: boundary at position 0 followed by
  invalid bytes (not `--` or CRLF) previously caused an
  infinite loop because the position-0 check was
  unconditional on re-entry.
  """
  fun name(): String =>
    "parser/malformed boundary termination"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = UnexpectedEnd)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal("--boundaryGARBAGE"))
    p.finish()
    h.assert_true(
      n.error_called,
      "error should be delivered")

// Test helper: collects events for verification
class \nodoc\ ref _CollectNotify is MultipartNotify
  let _h: TestHelper
  let _expect_parts: USize
  let _expect_error: (MultipartParseError | None)
  let _expect_bodies:
    (Array[Array[U8] val] val | None)
  var parts_received: USize = 0
  var finished_called: Bool = false
  var error_called: Bool = false
  var part_end_called: Bool = false
  var last_header_count: USize = 0
  var _current_body: Array[U8] ref = Array[U8]
  var _body_index: USize = 0

  new ref create(
    h: TestHelper,
    expect_parts': USize = 0,
    expect_error':
      (MultipartParseError | None) = None,
    expect_bodies':
      (Array[Array[U8] val] val | None) = None)
  =>
    _h = h
    _expect_parts = expect_parts'
    _expect_error = expect_error'
    _expect_bodies = expect_bodies'

  fun ref part_begin(headers: PartHeaders val) =>
    parts_received = parts_received + 1
    last_header_count = headers.size()
    _current_body = Array[U8]

  fun ref body_chunk(data: Array[U8] val) =>
    for byte in data.values() do
      _current_body.push(byte)
    end

  fun ref part_end() =>
    part_end_called = true
    match _expect_bodies
    | let bodies: Array[Array[U8] val] val =>
      if _body_index < bodies.size() then
        try
          let expected = bodies(_body_index)?
          _h.assert_eq[USize](
            expected.size(),
            _current_body.size(),
            "body size mismatch for part "
              + _body_index.string())
          let check_len =
            expected.size().min(
              _current_body.size())
          var i: USize = 0
          while i < check_len do
            _h.assert_eq[U8](
              expected(i)?,
              _current_body(i)?,
              "body byte mismatch at "
                + i.string())
            i = i + 1
          end
        else
          _h.fail(
            "body comparison error for part "
              + _body_index.string())
        end
      end
    end
    _body_index = _body_index + 1

  fun ref finished() =>
    finished_called = true
    _h.assert_eq[USize](
      _expect_parts,
      parts_received,
      "expected " + _expect_parts.string()
        + " parts, got "
        + parts_received.string())

  fun ref parse_error(err: MultipartParseError) =>
    error_called = true
    match _expect_error
    | let expected: MultipartParseError =>
      _h.assert_eq[String](
        expected.string(), err.string())
    end

class \nodoc\ ref _StopOnBody is MultipartNotify
  """
  Test helper that calls stop() on the first body_chunk,
  verifying re-entrant stop behavior and callback balance.
  """
  let _h: TestHelper
  var _parser: (MultipartParser ref | None) = None
  var begin_called: Bool = false
  var end_called: Bool = false
  var finished_called: Bool = false

  new ref create(h: TestHelper) =>
    _h = h

  fun ref set_parser(p: MultipartParser ref) =>
    _parser = p

  fun ref part_begin(headers: PartHeaders val) =>
    begin_called = true

  fun ref body_chunk(data: Array[U8] val) =>
    match _parser
    | let p: MultipartParser ref => p.stop()
    end

  fun ref part_end() =>
    end_called = true

  fun ref finished() =>
    finished_called = true

class \nodoc\ ref _StopOnPartBegin is MultipartNotify
  """
  Test helper that calls stop() on the first part_begin,
  verifying re-entrant stop from part_begin.
  """
  let _h: TestHelper
  var _parser: (MultipartParser ref | None) = None
  var begin_called: Bool = false
  var body_called: Bool = false
  var end_called: Bool = false
  var finished_called: Bool = false

  new ref create(h: TestHelper) =>
    _h = h

  fun ref set_parser(p: MultipartParser ref) =>
    _parser = p

  fun ref part_begin(headers: PartHeaders val) =>
    begin_called = true
    match _parser
    | let p: MultipartParser ref => p.stop()
    end

  fun ref body_chunk(data: Array[U8] val) =>
    body_called = true

  fun ref part_end() =>
    end_called = true

  fun ref finished() =>
    finished_called = true

class \nodoc\ ref _StopOnPartEnd is MultipartNotify
  """
  Test helper that calls stop() on the first part_end at
  an inter-part boundary, verifying no further events fire.
  """
  let _h: TestHelper
  var _parser: (MultipartParser ref | None) = None
  var parts_begun: USize = 0
  var parts_ended: USize = 0
  var finished_called: Bool = false

  new ref create(h: TestHelper) =>
    _h = h

  fun ref set_parser(p: MultipartParser ref) =>
    _parser = p

  fun ref part_begin(headers: PartHeaders val) =>
    parts_begun = parts_begun + 1

  fun ref part_end() =>
    parts_ended = parts_ended + 1
    match _parser
    | let p: MultipartParser ref => p.stop()
    end

  fun ref finished() =>
    finished_called = true

class \nodoc\ _TestParseAfterFinish is UnitTest
  """
  Calling parse() after finish() is a no-op — no events
  are delivered and no errors occur.
  """
  fun name(): String =>
    "parser/parse after finish is no-op"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nbody"
          + "\r\n--boundary--"))
    p.finish()
    h.assert_true(n.finished_called)
    // Reset tracking and parse more data
    let parts_before = n.parts_received
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nextra"
          + "\r\n--boundary--"))
    h.assert_eq[USize](
      parts_before,
      n.parts_received,
      "no new parts after finish")

class \nodoc\ _TestParseAfterError is UnitTest
  """
  Calling parse() after an error is a no-op — no
  duplicate error callbacks fire.
  """
  fun name(): String =>
    "parser/parse after error is no-op"

  fun apply(h: TestHelper) =>
    let n = _ErrorCounter(h)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "not a header\r\n"
          + "\r\n\r\n--boundary--"))
    h.assert_eq[USize](
      1,
      n.error_count,
      "exactly one error")
    // Feed more data — should be ignored
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nbody"
          + "\r\n--boundary--"))
    h.assert_eq[USize](
      1,
      n.error_count,
      "still one error after second parse")

class \nodoc\ _TestBodySizeLimitChunked is UnitTest
  """
  Body size limit is enforced across multiple parse()
  calls, not just within a single chunk.
  """
  fun name(): String =>
    "parser/body size limit across chunks"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = PartBodyTooLarge)
    let config =
      MultipartConfig(
        where max_part_body_size' = 10)
    let p =
      MultipartParser(n, "boundary", config)
    // First chunk: 6 bytes of body (under limit)
    p.parse(_ToVal("--boundary\r\n\r\n012345"))
    h.assert_false(
      n.error_called,
      "no error after first chunk")
    // Second chunk: 6 more bytes (total 12, over limit)
    p.parse(
      _ToVal("678901\r\n--boundary--"))
    h.assert_true(
      n.error_called,
      "error after exceeding limit")

class \nodoc\ _TestStopFromParseError is UnitTest
  """
  Calling stop() from within parse_error() is a harmless
  no-op since the parser is already in a failed state.
  """
  fun name(): String =>
    "parser/stop from parse_error is no-op"

  fun apply(h: TestHelper) =>
    let n = _StopOnError(h)
    let p = MultipartParser(n, "boundary")
    n.set_parser(p)
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "not a header\r\n"
          + "\r\n\r\n--boundary--"))
    h.assert_true(
      n.error_called,
      "error should fire")
    // Parser should still be in a clean failed
    // state — no crash, no double error
    p.parse(_ToVal("more data"))

class \nodoc\ _TestStopDuringFinishBodyTooLarge
  is UnitTest
  """
  Calling stop() from part_end() during finish()'s
  body-too-large path suppresses the parse_error
  callback, honoring the stop contract.
  """
  fun name(): String =>
    "parser/stop from part_end during "
      + "finish body-too-large"

  fun apply(h: TestHelper) =>
    let n = _StopOnPartEndNoError(h)
    let config =
      MultipartConfig(
        where max_part_body_size' = 5)
    let p =
      MultipartParser(n, "boundary", config)
    n.set_parser(p)
    // Start a part with a body that will exceed the
    // limit when finish() flushes
    p.parse(
      _ToVal(
        "--boundary\r\n\r\n0123456789"))
    p.finish()
    h.assert_true(
      n.end_called,
      "part_end should fire")
    h.assert_false(
      n.error_called,
      "parse_error should not fire after stop")

class \nodoc\ _TestStopDuringParseBodyTooLarge
  is UnitTest
  """
  Calling stop() from part_end() during parse()'s
  body-too-large error path suppresses the parse_error
  callback, honoring the stop contract.
  """
  fun name(): String =>
    "parser/stop from part_end during "
      + "parse body-too-large"

  fun apply(h: TestHelper) =>
    let n = _StopOnPartEndNoError(h)
    let config =
      MultipartConfig(
        where max_part_body_size' = 5)
    let p =
      MultipartParser(n, "boundary", config)
    n.set_parser(p)
    // Body is 10 bytes — exceeds limit during parse()
    p.parse(
      _ToVal(
        "--boundary\r\n\r\n0123456789"
          + "\r\n--boundary--"))
    h.assert_true(
      n.end_called,
      "part_end should fire")
    h.assert_false(
      n.error_called,
      "parse_error should not fire after stop")

// Test helper: counts errors for duplicate-error tests
class \nodoc\ ref _ErrorCounter is MultipartNotify
  let _h: TestHelper
  var error_count: USize = 0

  new ref create(h: TestHelper) =>
    _h = h

  fun ref parse_error(err: MultipartParseError) =>
    error_count = error_count + 1

// Test helper: calls stop() from parse_error callback
class \nodoc\ ref _StopOnError is MultipartNotify
  let _h: TestHelper
  var _parser: (MultipartParser ref | None) = None
  var error_called: Bool = false

  new ref create(h: TestHelper) =>
    _h = h

  fun ref set_parser(p: MultipartParser ref) =>
    _parser = p

  fun ref parse_error(err: MultipartParseError) =>
    error_called = true
    match _parser
    | let p: MultipartParser ref => p.stop()
    end

class \nodoc\ _TestInvalidBoundaryTrailingSpace
  is UnitTest
  """
  A boundary with a trailing space is rejected per
  RFC 2046 section 5.1.1.
  """
  fun name(): String =>
    "parser/invalid boundary trailing space"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = InvalidBoundary)
    let p = MultipartParser(n, "boundary ")
    p.parse(_ToVal(""))
    h.assert_true(
      n.error_called,
      "error should be delivered for trailing space")

class \nodoc\ _TestValidBoundaryInternalSpace
  is UnitTest
  """
  A boundary with internal spaces is valid per
  RFC 2046 section 5.1.1.
  """
  fun name(): String =>
    "parser/valid boundary with internal space"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let p = MultipartParser(n, "ab cd")
    p.parse(
      _ToVal(
        "--ab cd\r\n\r\nbody"
          + "\r\n--ab cd--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)

class \nodoc\ _TestStopFromFinished is UnitTest
  """
  Calling stop() from within the finished() callback
  is harmless — the parser is already at a terminal
  state and no further events fire.
  """
  fun name(): String =>
    "parser/stop from finished"

  fun apply(h: TestHelper) =>
    let n = _StopOnFinished(h)
    let p = MultipartParser(n, "boundary")
    n.set_parser(p)
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nbody"
          + "\r\n--boundary--"))
    h.assert_true(
      n.finished_called,
      "finished should fire")
    h.assert_false(
      n.error_called,
      "no error after stop from finished")
    // Parse more data — should be ignored
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nextra"
          + "\r\n--boundary--"))
    h.assert_eq[USize](
      1,
      n.parts_begun,
      "no new parts after stop")

class \nodoc\ _TestHeaderEmptyValue is UnitTest
  """
  A header with no value after the colon (or only
  whitespace) produces an empty string value.
  """
  fun name(): String =>
    "parser/header with empty value"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "X-Empty:\r\n"
          + "X-Whitespace:   \r\n"
          + "\r\nbody\r\n--boundary--"))
    h.assert_true(n.finished_called)
    h.assert_false(n.error_called)
    h.assert_eq[USize](2, n.last_header_count)

class \nodoc\ _TestMalformedHeaderWhitespaceBeforeColon
  is UnitTest
  """
  A header with whitespace before the colon is rejected
  per RFC 7230 section 3.2.4.
  """
  fun name(): String =>
    "parser/malformed header whitespace before colon"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = MalformedHeader)
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "Content-Type : text/plain\r\n"
          + "\r\nbody\r\n--boundary--"))
    h.assert_true(
      n.error_called,
      "error should be delivered for space before colon")

// Test helper: calls stop() from finished callback
class \nodoc\ ref _StopOnFinished is MultipartNotify
  let _h: TestHelper
  var _parser: (MultipartParser ref | None) = None
  var finished_called: Bool = false
  var error_called: Bool = false
  var parts_begun: USize = 0

  new ref create(h: TestHelper) =>
    _h = h

  fun ref set_parser(p: MultipartParser ref) =>
    _parser = p

  fun ref part_begin(headers: PartHeaders val) =>
    parts_begun = parts_begun + 1

  fun ref finished() =>
    finished_called = true
    match _parser
    | let p: MultipartParser ref => p.stop()
    end

  fun ref parse_error(err: MultipartParseError) =>
    error_called = true

class \nodoc\ _TestMalformedBoundaryLineBody is UnitTest
  """
  Excessive transport padding on a boundary between parts (in the
  body state) produces MalformedBoundaryLine.
  """
  fun name(): String =>
    "parser/malformed boundary line in body"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = MalformedBoundaryLine)
    let p = MultipartParser(n, "boundary")
    let msg =
      recover val
        let a = Array[U8]
        // First part
        for c in
          "--boundary\r\n\r\npart1\r\n--boundary"
            .values()
        do
          a.push(c)
        end
        // 257 bytes of transport padding
        var i: USize = 0
        while i < 257 do
          a.push(' ')
          i = i + 1
        end
        for c in
          "\r\n\r\npart2\r\n--boundary--".values()
        do
          a.push(c)
        end
        a
      end
    p.parse(msg)
    h.assert_true(
      n.error_called,
      "error should be delivered")

class \nodoc\ _TestHeadersTooLargePending is UnitTest
  """
  HeadersTooLarge is triggered when no CRLF has been found
  yet but accumulated pending bytes exceed the limit. This
  tests the slow-drip path rather than the complete-header
  path.
  """
  fun name(): String =>
    "parser/headers too large (pending bytes)"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = HeadersTooLarge)
    let small_config =
      MultipartConfig(where max_header_size' = 20)
    let p =
      MultipartParser(n, "boundary", small_config)
    // Send boundary and header start, but no CRLF
    // to terminate the header line — just a long
    // stream of header bytes without a line ending
    p.parse(
      _ToVal("--boundary\r\n"))
    p.parse(
      _ToVal(
        "X-Very-Long-Header-Name-That"
          + "-Exceeds-The-Limit"))
    h.assert_true(
      n.error_called,
      "error should be delivered for pending bytes")

class \nodoc\ _TestTransportPaddingAtCap is UnitTest
  """
  Transport padding at exactly 256 bytes (the cap) should
  succeed. This is a boundary condition test.
  """
  fun name(): String =>
    "parser/transport padding at 256-byte cap"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(h where expect_parts' = 1)
    let p = MultipartParser(n, "boundary")
    let msg =
      recover val
        let a = Array[U8]
        for c in "--boundary".values() do
          a.push(c)
        end
        var i: USize = 0
        while i < 256 do
          a.push(' ')
          i = i + 1
        end
        for c in
          "\r\n\r\nbody\r\n--boundary--".values()
        do
          a.push(c)
        end
        a
      end
    p.parse(msg)
    h.assert_true(
      n.finished_called,
      "256 bytes of padding should succeed")
    h.assert_false(n.error_called)

class \nodoc\ _TestInvalidBoundaryFinishOnly is UnitTest
  """
  Calling finish() without parse() on an invalid-boundary
  parser should report InvalidBoundary, not UnexpectedEnd.
  """
  fun name(): String =>
    "parser/invalid boundary finish-only"

  fun apply(h: TestHelper) =>
    let n =
      _CollectNotify(
        h where expect_error' = InvalidBoundary)
    let p = MultipartParser(n, "")
    p.finish()
    h.assert_true(
      n.error_called,
      "error should be delivered")

// Test helper: calls stop() from part_end,
// tracks whether parse_error fires
class \nodoc\ ref _StopOnPartEndNoError
  is MultipartNotify
  let _h: TestHelper
  var _parser: (MultipartParser ref | None) = None
  var end_called: Bool = false
  var error_called: Bool = false

  new ref create(h: TestHelper) =>
    _h = h

  fun ref set_parser(p: MultipartParser ref) =>
    _parser = p

  fun ref part_end() =>
    end_called = true
    match _parser
    | let p: MultipartParser ref => p.stop()
    end

  fun ref parse_error(err: MultipartParseError) =>
    error_called = true

class \nodoc\ _TestCallbackOrdering is UnitTest
  """
  Records the exact sequence of callback events and asserts
  the expected order for a two-part message.
  """
  fun name(): String =>
    "parser/callback ordering"

  fun apply(h: TestHelper) =>
    let n = _SequenceNotify
    let p = MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n"
          + "Content-Type: text/plain\r\n"
          + "\r\nfirst"
          + "\r\n--boundary\r\n"
          + "\r\nsecond"
          + "\r\n--boundary--"))
    let expected: Array[String val] val =
      [ "part_begin"
        "body_chunk"
        "part_end"
        "part_begin"
        "body_chunk"
        "part_end"
        "finished" ]
    h.assert_eq[USize](
      expected.size(),
      n.events.size(),
      "event count mismatch")
    var i: USize = 0
    while i < expected.size().min(n.events.size()) do
      try
        h.assert_eq[String](
          expected(i)?,
          n.events(i)?,
          "event " + i.string() + " mismatch")
      else
        h.fail(
          "event comparison error at "
            + i.string())
      end
      i = i + 1
    end

// Test helper: records callback event names in order
class \nodoc\ ref _SequenceNotify is MultipartNotify
  embed events: Array[String val] =
    Array[String val]

  new ref create() =>
    None

  fun ref part_begin(headers: PartHeaders val) =>
    events.push("part_begin")

  fun ref body_chunk(data: Array[U8] val) =>
    events.push("body_chunk")

  fun ref part_end() =>
    events.push("part_end")

  fun ref finished() =>
    events.push("finished")

  fun ref parse_error(err: MultipartParseError) =>
    events.push("parse_error")

class \nodoc\ _TestStopFromBodyChunkDuringFinish
  is UnitTest
  """
  Calling stop() from body_chunk during finish() flush
  prevents part_end and parse_error from firing.
  """
  fun name(): String =>
    "parser/stop from body_chunk during finish"

  fun apply(h: TestHelper) =>
    let n = _StopOnBodyDuringFinish(h)
    let p = MultipartParser(n, "boundary")
    n.set_parser(p)
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nsome body data"))
    // No close delimiter — finish() will flush body
    // and then report UnexpectedEnd
    p.finish()
    h.assert_true(
      n.body_called,
      "body_chunk should fire during flush")
    h.assert_false(
      n.end_called,
      "part_end should not fire after stop")
    h.assert_false(
      n.error_called,
      "parse_error should not fire after stop")

// Test helper: calls stop() from body_chunk
class \nodoc\ ref _StopOnBodyDuringFinish
  is MultipartNotify
  let _h: TestHelper
  var _parser: (MultipartParser ref | None) = None
  var body_called: Bool = false
  var end_called: Bool = false
  var error_called: Bool = false

  new ref create(h: TestHelper) =>
    _h = h

  fun ref set_parser(p: MultipartParser ref) =>
    _parser = p

  fun ref body_chunk(data: Array[U8] val) =>
    body_called = true
    match _parser
    | let p: MultipartParser ref => p.stop()
    end

  fun ref part_end() =>
    end_called = true

  fun ref parse_error(err: MultipartParseError) =>
    error_called = true
