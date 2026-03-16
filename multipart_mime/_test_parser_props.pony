use "pony_test"
use "pony_check"

class \nodoc\ _TestRoundtripProperty
  is Property1[_MultipartMessage val]
  fun name(): String => "parser/property: roundtrip"

  fun gen(): Generator[_MultipartMessage val] =>
    _MultipartMessageGen()

  fun property(
    sample: _MultipartMessage val,
    h: PropertyHelper)
    ?
  =>
    let collector: _PropCollector ref = _PropCollector
    let p = MultipartParser(collector, sample.boundary)
    p.parse(_ToVal(sample.encoded))
    h.assert_true(
      collector.finished_called,
      "finished should be called")
    h.assert_eq[USize](
      sample.parts.size(),
      collector.part_bodies.size())
    var i: USize = 0
    while i < sample.parts.size() do
      let expected = sample.parts(i)?
      let actual_body = collector.part_bodies(i)?
      let actual_hdrs = collector.part_headers(i)?
      h.assert_eq[USize](
        expected.headers.size(),
        actual_hdrs.size(),
        "header count mismatch for part "
          + i.string())
      var hi: USize = 0
      while hi < expected.headers.size() do
        let exp_name = expected.headers(hi)?._1
        let exp_val = expected.headers(hi)?._2
        var found = false
        for (ak, av) in actual_hdrs.values() do
          if (ak == exp_name.lower())
            and (av == exp_val)
          then
            found = true
            break
          end
        end
        h.assert_true(
          found,
          "header " + exp_name + ": "
            + exp_val
            + " not found in part "
            + i.string())
        hi = hi + 1
      end
      h.assert_eq[USize](
        expected.body.size(),
        actual_body.size(),
        "body size mismatch for part "
          + i.string())
      var j: USize = 0
      while j < expected.body.size() do
        h.assert_eq[U8](
          expected.body(j)?,
          actual_body(j)?,
          "body mismatch at byte "
            + j.string()
            + " in part " + i.string())
        j = j + 1
      end
      i = i + 1
    end

class \nodoc\ _TestChunkedRoundtripProperty
  is Property1[_ChunkedMessage val]
  fun name(): String =>
    "parser/property: chunked roundtrip"

  fun gen(): Generator[_ChunkedMessage val] =>
    _ChunkedMessageGen()

  fun property(
    sample: _ChunkedMessage val,
    h: PropertyHelper)
    ?
  =>
    let collector: _PropCollector ref = _PropCollector
    let p =
      MultipartParser(collector, sample.msg.boundary)
    for chunk in sample.chunks.values() do
      p.parse(_ToVal(chunk))
    end
    h.assert_true(
      collector.finished_called,
      "finished should be called")
    h.assert_eq[USize](
      sample.msg.parts.size(),
      collector.part_bodies.size())
    var i: USize = 0
    while i < sample.msg.parts.size() do
      let expected = sample.msg.parts(i)?
      let actual_body = collector.part_bodies(i)?
      let actual_hdrs = collector.part_headers(i)?
      h.assert_eq[USize](
        expected.headers.size(),
        actual_hdrs.size(),
        "header count mismatch for part "
          + i.string())
      var hi: USize = 0
      while hi < expected.headers.size() do
        let exp_name = expected.headers(hi)?._1
        let exp_val = expected.headers(hi)?._2
        var found = false
        for (ak, av) in actual_hdrs.values() do
          if (ak == exp_name.lower())
            and (av == exp_val)
          then
            found = true
            break
          end
        end
        h.assert_true(
          found,
          "header " + exp_name + ": "
            + exp_val
            + " not found in part "
            + i.string())
        hi = hi + 1
      end
      h.assert_eq[USize](
        expected.body.size(),
        actual_body.size(),
        "body size mismatch for part "
          + i.string())
      var j: USize = 0
      while j < expected.body.size() do
        h.assert_eq[U8](
          expected.body(j)?,
          actual_body(j)?,
          "body mismatch at byte "
            + j.string()
            + " in part " + i.string())
        j = j + 1
      end
      i = i + 1
    end

class \nodoc\ _TestBoundaryNeverInBody
  is Property1[_MultipartMessage val]
  fun name(): String =>
    "parser/property: boundary never in body"

  fun gen(): Generator[_MultipartMessage val] =>
    _MultipartMessageGen()

  fun property(
    sample: _MultipartMessage val,
    h: PropertyHelper)
  =>
    let checker: _BoundaryChecker ref =
      _BoundaryChecker(sample.boundary)
    let p = MultipartParser(checker, sample.boundary)
    p.parse(_ToVal(sample.encoded))
    h.assert_true(checker.finished_called)
    h.assert_false(
      checker.boundary_found,
      "boundary should never appear in body chunks")

class \nodoc\ _TestTruncationDetected
  is Property1[_MultipartMessage val]
  fun name(): String =>
    "parser/property: truncation detected"

  fun gen(): Generator[_MultipartMessage val] =>
    _MultipartMessageGen()

  fun property(
    sample: _MultipartMessage val,
    h: PropertyHelper)
  =>
    if sample.parts.size() == 0 then return end
    let close_len = sample.boundary.size() + 6
    if sample.encoded.size() <= close_len then
      return
    end
    let end_pos =
      sample.encoded.size().isize() -
        close_len.isize()
    let truncated: String val =
      sample.encoded.substring(0, end_pos)
    let collector: _PropCollector ref = _PropCollector
    let p = MultipartParser(collector, sample.boundary)
    p.parse(_ToVal(truncated))
    p.finish()
    h.assert_true(
      collector.error_called,
      "error should be called")
    h.assert_eq[String](
      "unexpected end of input",
      collector.error_msg)

class \nodoc\ _TestPreambleEpilogueIgnored
  is Property1[_MessageWithExtras val]
  fun name(): String =>
    "parser/property: preamble and epilogue ignored"

  fun gen(): Generator[_MessageWithExtras val] =>
    _MessageWithExtrasGen()

  fun property(
    sample: _MessageWithExtras val,
    h: PropertyHelper)
    ?
  =>
    let with_extras: String val =
      sample.preamble + "\r\n"
        + sample.msg.encoded
        + "\r\n" + sample.epilogue
    let collector: _PropCollector ref = _PropCollector
    let p =
      MultipartParser(collector, sample.msg.boundary)
    p.parse(_ToVal(with_extras))
    h.assert_true(collector.finished_called)
    h.assert_eq[USize](
      sample.msg.parts.size(),
      collector.part_bodies.size())
    var i: USize = 0
    while i < sample.msg.parts.size() do
      let expected = sample.msg.parts(i)?
      let actual_body = collector.part_bodies(i)?
      h.assert_eq[USize](
        expected.body.size(),
        actual_body.size(),
        "body size mismatch for part "
          + i.string())
      var j: USize = 0
      while j < expected.body.size() do
        try
          h.assert_eq[U8](
            expected.body(j)?,
            actual_body(j)?,
            "body mismatch at byte "
              + j.string()
              + " in part " + i.string())
        else
          h.fail(
            "body access error in part "
              + i.string())
        end
        j = j + 1
      end
      i = i + 1
    end

class \nodoc\ _TestInvalidInputProperty
  is Property1[_TruncatedMessage val]
  fun name(): String =>
    "parser/property: invalid input"

  fun gen(): Generator[_TruncatedMessage val] =>
    _TruncatedMessageGen()

  fun property(
    sample: _TruncatedMessage val,
    h: PropertyHelper)
  =>
    if sample.truncated.size() == 0 then return end
    let collector: _PropCollector ref = _PropCollector
    let p =
      MultipartParser(collector, sample.msg.boundary)
    p.parse(_ToVal(sample.truncated))
    p.finish()
    h.assert_true(
      collector.error_called,
      "error should be called on truncated input")
    h.assert_eq[String](
      "unexpected end of input",
      collector.error_msg)

class \nodoc\ val _PartData
  let headers: Array[(String val, String val)] val
  let body: String val

  new val create(
    headers': Array[(String val, String val)] val,
    body': String val)
  =>
    headers = headers'
    body = body'

class \nodoc\ val _MultipartMessage
  let boundary: String val
  let parts: Array[_PartData val] val
  let encoded: String val

  new val create(
    boundary': String val,
    parts': Array[_PartData val] val,
    encoded': String val)
  =>
    boundary = boundary'
    parts = parts'
    encoded = encoded'

class \nodoc\ val _ChunkedMessage
  let msg: _MultipartMessage val
  let chunks: Array[String val] val

  new val create(
    msg': _MultipartMessage val,
    chunks': Array[String val] val)
  =>
    msg = msg'
    chunks = chunks'

primitive \nodoc\ _MultipartMessageGen
  fun apply(): Generator[_MultipartMessage val] =>
    Generator[_MultipartMessage val](
      object is GenObj[_MultipartMessage val]
        fun generate(
          rnd: Randomness)
          : _MultipartMessage val^
        =>
          let bchars =
            "abcdefghijklmnopqrstuvwxyz"
              + "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
              + "0123456789'()+_,-./:=? "
          let blen = rnd.usize(1, 70)
          let boundary =
            recover val
              let s = String(blen)
              var bi: USize = 0
              while bi < blen do
                try
                  s.push(
                    bchars(
                      rnd.usize(
                        0,
                        bchars.size() - 1))?)
                else
                  s.push('x')
                end
                bi = bi + 1
              end
              try
                if s(s.size() - 1)? == ' ' then
                  s(s.size() - 1)? = 'x'
                end
              end
              s
            end
          let num_parts = rnd.usize(0, 4)
          let parts =
            recover iso
              Array[_PartData val](num_parts)
            end
          let encoded = recover iso String end
          var pi: USize = 0
          while pi < num_parts do
            if pi > 0 then
              encoded.append("\r\n")
            end
            encoded.append("--")
            encoded.append(boundary)
            // Random transport padding (LWSP before CRLF)
            var pk: USize = 0
            let pn = rnd.usize(0, 5)
            while pk < pn do
              if rnd.bool() then
                encoded.push(' ')
              else
                encoded.push('\t')
              end
              pk = pk + 1
            end
            encoded.append("\r\n")
            let num_hdrs = rnd.usize(0, 2)
            let hdrs =
              recover iso
                Array[(String val, String val)](
                  num_hdrs)
              end
            var hi: USize = 0
            while hi < num_hdrs do
              let hname =
                recover val
                  "X-Test-"
                    + rnd.usize(0, 999).string()
                end
              let hval =
                recover val
                  "value-"
                    + rnd.usize(0, 999).string()
                end
              encoded.append(hname)
              encoded.append(": ")
              encoded.append(hval)
              encoded.append("\r\n")
              hdrs.push((hname, hval))
              hi = hi + 1
            end
            encoded.append("\r\n")
            let body_len = rnd.usize(0, 300)
            let body =
              _BodyScrub.scrub(
                recover val
                  let s = String(body_len)
                  var bi: USize = 0
                  while bi < body_len do
                    s.push(rnd.u8(0, 255))
                    bi = bi + 1
                  end
                  s
                end,
                boundary)
            encoded.append(body)
            let frozen_hdrs
              : Array[(String val, String val)] val
              = consume hdrs
            parts.push(
              _PartData(frozen_hdrs, body))
            pi = pi + 1
          end
          if num_parts > 0 then
            encoded.append("\r\n")
          end
          encoded.append("--")
          encoded.append(boundary)
          encoded.append("--")
          let frozen_parts
            : Array[_PartData val] val
            = consume parts
          _MultipartMessage(
            boundary,
            frozen_parts,
            consume encoded)
      end)

primitive \nodoc\ _BodyScrub
  fun scrub(
    body: String val,
    boundary: String val)
    : String val
  =>
    let delim: String val = "\r\n--" + boundary
    if not body.contains(delim) then
      return body
    end
    let result = recover iso String(body.size()) end
    var i: USize = 0
    while i < body.size() do
      let remaining = body.size() - i
      if remaining >= delim.size() then
        var match_found = true
        var j: USize = 0
        while j < delim.size() do
          try
            if body(i + j)? != delim(j)? then
              match_found = false
              break
            end
          else
            match_found = false
            break
          end
          j = j + 1
        end
        if match_found then
          result.push('X')
          i = i + 1
        else
          try
            result.push(body(i)?)
          else
            _Unreachable()
          end
          i = i + 1
        end
      else
        try
          result.push(body(i)?)
        else
          _Unreachable()
        end
        i = i + 1
      end
    end
    consume result

primitive \nodoc\ _ChunkedMessageGen
  fun apply(): Generator[_ChunkedMessage val] =>
    Generator[_ChunkedMessage val](
      object is GenObj[_ChunkedMessage val]
        fun generate(
          rnd: Randomness)
          : _ChunkedMessage val^
        =>
          let msg =
            try
              _MultipartMessageGen()
                .generate_value(rnd)?
            else
              return _ChunkedMessage(
                _MultipartMessage(
                  "x",
                  recover val
                    Array[_PartData val]
                  end,
                  ""),
                recover val
                  Array[String val]
                end)
            end
          let encoded = msg.encoded
          if encoded.size() == 0 then
            return _ChunkedMessage(
              msg,
              recover val [encoded] end)
          end
          let num_splits = rnd.usize(1, 8)
          let splits = Array[USize](num_splits)
          var si: USize = 0
          while si < num_splits do
            splits.push(
              rnd.usize(0, encoded.size() - 1))
            si = si + 1
          end
          var i: USize = 1
          while i < splits.size() do
            var j = i
            while j > 0 do
              try
                if splits(j)? < splits(j - 1)?
                then
                  let tmp = splits(j)?
                  splits(j)? = splits(j - 1)?
                  splits(j - 1)? = tmp
                end
              end
              j = j - 1
            end
            i = i + 1
          end
          let chunks =
            recover iso Array[String val] end
          var prev: USize = 0
          for sp in splits.values() do
            if sp > prev then
              chunks.push(
                encoded.substring(
                  prev.isize(),
                  sp.isize()))
              prev = sp
            end
          end
          if prev < encoded.size() then
            chunks.push(
              encoded.substring(prev.isize()))
          end
          _ChunkedMessage(msg, consume chunks)
      end)

class \nodoc\ ref _PropCollector is MultipartNotify
  var finished_called: Bool = false
  var error_called: Bool = false
  var error_msg: String val = ""
  var part_bodies: Array[Array[U8] ref] ref =
    Array[Array[U8] ref]
  var part_headers: Array[PartHeaders val] ref =
    Array[PartHeaders val]
  var _current_body: (Array[U8] ref | None) = None

  fun ref part_begin(headers: PartHeaders val) =>
    let body = Array[U8]
    _current_body = body
    part_bodies.push(body)
    part_headers.push(headers)

  fun ref body_chunk(data: Array[U8] val) =>
    match _current_body
    | let body: Array[U8] ref =>
      for byte in data.values() do
        body.push(byte)
      end
    end

  fun ref part_end() =>
    _current_body = None

  fun ref finished() =>
    finished_called = true

  fun ref parse_error(err: MultipartParseError) =>
    error_called = true
    error_msg = err.string()

class \nodoc\ ref _BoundaryChecker is MultipartNotify
  let _boundary: String val
  var finished_called: Bool = false
  var boundary_found: Bool = false
  var _current_body: Array[U8] iso =
    recover iso Array[U8] end

  new ref create(boundary: String val) =>
    _boundary = boundary

  fun ref part_begin(headers: PartHeaders val) =>
    _current_body = recover iso Array[U8] end

  fun ref body_chunk(data: Array[U8] val) =>
    for byte in data.values() do
      _current_body.push(byte)
    end

  fun ref part_end() =>
    let body =
      (_current_body = recover iso Array[U8] end)
    let s =
      String.from_array(
        recover val consume body end)
    if s.contains("\r\n--" + _boundary) then
      boundary_found = true
    end

  fun ref finished() =>
    finished_called = true

class \nodoc\ val _MessageWithExtras
  let msg: _MultipartMessage val
  let preamble: String val
  let epilogue: String val

  new val create(
    msg': _MultipartMessage val,
    preamble': String val,
    epilogue': String val)
  =>
    msg = msg'
    preamble = preamble'
    epilogue = epilogue'

primitive \nodoc\ _MessageWithExtrasGen
  fun apply(): Generator[_MessageWithExtras val] =>
    Generator[_MessageWithExtras val](
      object is GenObj[_MessageWithExtras val]
        fun generate(
          rnd: Randomness)
          : _MessageWithExtras val^
        =>
          let msg =
            try
              _MultipartMessageGen()
                .generate_value(rnd)?
            else
              return _MessageWithExtras(
                _MultipartMessage(
                  "x",
                  recover val
                    Array[_PartData val]
                  end,
                  ""),
                "",
                "")
            end
          let pre_len = rnd.usize(0, 100)
          let preamble =
            recover val
              let s = String(pre_len)
              var i: USize = 0
              while i < pre_len do
                s.push(rnd.u8(32, 126))
                i = i + 1
              end
              s
            end
          let epi_len = rnd.usize(0, 100)
          let epilogue =
            recover val
              let s = String(epi_len)
              var i: USize = 0
              while i < epi_len do
                s.push(rnd.u8(32, 126))
                i = i + 1
              end
              s
            end
          _MessageWithExtras(
            msg, preamble, epilogue)
      end)

class \nodoc\ val _TruncatedMessage
  let msg: _MultipartMessage val
  let truncated: String val

  new val create(
    msg': _MultipartMessage val,
    truncated': String val)
  =>
    msg = msg'
    truncated = truncated'

primitive \nodoc\ _TruncatedMessageGen
  fun apply(): Generator[_TruncatedMessage val] =>
    Generator[_TruncatedMessage val](
      object is GenObj[_TruncatedMessage val]
        fun generate(
          rnd: Randomness)
          : _TruncatedMessage val^
        =>
          let msg =
            try
              _MultipartMessageGen()
                .generate_value(rnd)?
            else
              return _TruncatedMessage(
                _MultipartMessage(
                  "x",
                  recover val
                    Array[_PartData val]
                  end,
                  ""),
                "")
            end
          if msg.encoded.size() < 2 then
            return _TruncatedMessage(msg, "")
          end
          let cut =
            rnd.usize(1, msg.encoded.size() - 1)
          let truncated: String val =
            msg.encoded.substring(
              0, cut.isize())
          _TruncatedMessage(msg, truncated)
      end)
