use "pony_test"

class \nodoc\ _TestFormDataFieldName is UnitTest
  fun name(): String => "form_data/field_name"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("content-disposition"
            , "form-data; name=\"username\"") ]
        end)
    match \exhaustive\ FormData.field_name(headers)
    | let s: String => h.assert_eq[String]("username", s)
    | None => h.fail("expected field name")
    end

class \nodoc\ _TestFormDataFileName is UnitTest
  fun name(): String => "form_data/file_name"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("content-disposition"
            , "form-data; name=\"file\""
              + "; filename=\"photo.jpg\"") ]
        end)
    match \exhaustive\ FormData.file_name(headers)
    | let s: String =>
      h.assert_eq[String]("photo.jpg", s)
    | None => h.fail("expected file name")
    end

class \nodoc\ _TestFormDataNoFileName is UnitTest
  fun name(): String => "form_data/no file_name"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("content-disposition"
            , "form-data; name=\"field\"") ]
        end)
    match \exhaustive\ FormData.file_name(headers)
    | None => None
    | let s: String =>
      h.fail("expected None, got: " + s)
    end

class \nodoc\ _TestFormDataQuotedEscape is UnitTest
  fun name(): String =>
    "form_data/quoted string with escaping"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("content-disposition"
            , "form-data; name=\"field\""
              + "; filename=\"file\\\"name.txt\"") ]
        end)
    match \exhaustive\ FormData.file_name(headers)
    | let s: String =>
      h.assert_eq[String]("file\"name.txt", s)
    | None => h.fail("expected escaped file name")
    end

class \nodoc\ _TestFormDataContentType is UnitTest
  fun name(): String => "form_data/content_type"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [("content-type", "image/png")]
        end)
    match \exhaustive\ FormData.content_type(headers)
    | let s: String =>
      h.assert_eq[String]("image/png", s)
    | None => h.fail("expected content type")
    end

class \nodoc\ _TestFormDataNoDisposition is UnitTest
  fun name(): String =>
    "form_data/no content-disposition"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          Array[(String val, String val)]
        end)
    match \exhaustive\ FormData.field_name(headers)
    | None => None
    | let s: String =>
      h.fail("expected None, got: " + s)
    end

class \nodoc\ _TestFormDataContentDisposition is UnitTest
  fun name(): String =>
    "form_data/content_disposition raw value"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("content-disposition"
            , "form-data; name=\"x\"") ]
        end)
    match \exhaustive\
      FormData.content_disposition(headers)
    | let s: String =>
      h.assert_eq[String](
        "form-data; name=\"x\"", s)
    | None =>
      h.fail("expected content disposition")
    end

class \nodoc\ _TestFormDataUnterminatedQuote
  is UnitTest
  """
  An unterminated quoted string in Content-Disposition
  returns the content after the opening quote up to the
  end of the segment.
  """
  fun name(): String =>
    "form_data/unterminated quote"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("content-disposition"
            , "form-data; name=\"unterminated") ]
        end)
    match \exhaustive\ FormData.field_name(headers)
    | let s: String =>
      h.assert_eq[String]("unterminated", s)
    | None =>
      h.fail("expected value from unterminated quote")
    end

class \nodoc\ _TestCollectPartsBasic is UnitTest
  fun name(): String => "collect_parts/basic"

  fun apply(h: TestHelper) =>
    h.long_test(2_000_000_000)
    let cb =
      recover val
        {(parts: Array[CollectedPart val] val)(h) =>
          h.assert_eq[USize](2, parts.size())
          try
            h.assert_eq[USize](
              4, parts(0)?.body.size())
            h.assert_eq[USize](
              2, parts(1)?.body.size())
          else
            h.fail(
              "unexpected error accessing parts")
          end
          h.complete(true)
        }
      end
    let err_cb =
      recover val
        {(err: MultipartParseError)(h) =>
          h.fail(
            "unexpected error: " + err.string())
          h.complete(false)
        }
      end
    let n = CollectParts(cb, err_cb)
    let p =
      MultipartParser(n, "boundary")
    p.parse(
      _ToVal(
        "--boundary\r\n\r\nabcd"
          + "\r\n--boundary\r\n\r\nef"
          + "\r\n--boundary--"))

class \nodoc\ _TestFormDataCaseInsensitiveParam
  is UnitTest
  """
  Parameter names in Content-Disposition are
  case-insensitive.
  """
  fun name(): String =>
    "form_data/case-insensitive param name"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("content-disposition"
            , "form-data; NAME=\"user\"") ]
        end)
    match \exhaustive\ FormData.field_name(headers)
    | let s: String =>
      h.assert_eq[String]("user", s)
    | None =>
      h.fail("expected field name with uppercase")
    end

class \nodoc\ _TestFormDataUnquotedValue
  is UnitTest
  """
  Parameter values without quotes are returned as
  bare tokens.
  """
  fun name(): String =>
    "form_data/unquoted parameter value"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("content-disposition"
            , "form-data; name=fieldname") ]
        end)
    match \exhaustive\ FormData.field_name(headers)
    | let s: String =>
      h.assert_eq[String]("fieldname", s)
    | None =>
      h.fail("expected unquoted field name")
    end

class \nodoc\ _TestFormDataSemicolonInQuotes
  is UnitTest
  """
  Semicolons inside quoted strings are not treated as
  parameter delimiters.
  """
  fun name(): String =>
    "form_data/semicolon inside quotes"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("content-disposition"
            , "form-data; name=\"a;b\""
              + "; filename=\"file.txt\"") ]
        end)
    match \exhaustive\ FormData.field_name(headers)
    | let s: String =>
      h.assert_eq[String]("a;b", s)
    | None => h.fail("expected field name with ;")
    end
    match \exhaustive\ FormData.file_name(headers)
    | let s: String =>
      h.assert_eq[String]("file.txt", s)
    | None =>
      h.fail("expected filename after ;-in-quotes")
    end

class \nodoc\ _TestFormDataEmptyParamValue is UnitTest
  """
  A parameter with `name=` (no value after the equals sign)
  returns an empty string.
  """
  fun name(): String =>
    "form_data/empty parameter value"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("content-disposition"
            , "form-data; name=") ]
        end)
    match \exhaustive\ FormData.field_name(headers)
    | let s: String =>
      h.assert_eq[String]("", s)
    | None =>
      h.fail("expected empty string, got None")
    end

class \nodoc\ _TestCollectPartsZeroParts is UnitTest
  """
  CollectParts with an empty multipart message (close-delimiter
  only) delivers an empty array to the on_parts callback.
  """
  fun name(): String =>
    "collect_parts/zero parts"

  fun apply(h: TestHelper) =>
    h.long_test(2_000_000_000)
    let cb =
      recover val
        {(parts: Array[CollectedPart val] val)(h) =>
          h.assert_eq[USize](0, parts.size())
          h.complete(true)
        }
      end
    let err_cb =
      recover val
        {(err: MultipartParseError)(h) =>
          h.fail(
            "unexpected error: " + err.string())
          h.complete(false)
        }
      end
    let n = CollectParts(cb, err_cb)
    let p =
      MultipartParser(n, "boundary")
    p.parse(_ToVal("--boundary--"))

class \nodoc\ _TestCollectPartsError is UnitTest
  fun name(): String => "collect_parts/error"

  fun apply(h: TestHelper) =>
    h.long_test(2_000_000_000)
    let cb =
      recover val
        {(parts: Array[CollectedPart val] val)(h) =>
          h.fail("should not get parts on error")
          h.complete(false)
        }
      end
    let err_cb =
      recover val
        {(err: MultipartParseError)(h) =>
          h.assert_eq[String](
            "unexpected end of input",
            err.string())
          h.complete(true)
        }
      end
    let n = CollectParts(cb, err_cb)
    MultipartParser(n, "boundary")
      .> parse(
        _ToVal(
          "--boundary\r\n\r\nincomplete"))
      .> finish()

class \nodoc\ _TestCollectPartsMultipleChunks
  is UnitTest
  """
  CollectParts correctly concatenates body data
  delivered across multiple body_chunk calls.
  """
  fun name(): String =>
    "collect_parts/multiple body chunks"

  fun apply(h: TestHelper) =>
    h.long_test(2_000_000_000)
    let cb =
      recover val
        {(parts: Array[CollectedPart val] val)(h) =>
          try
            h.assert_eq[USize](1, parts.size())
            h.assert_eq[USize](
              10, parts(0)?.body.size())
            h.assert_eq[String](
              "abcdefghij",
              String.from_array(parts(0)?.body))
          else
            h.fail(
              "unexpected error accessing parts")
          end
          h.complete(true)
        }
      end
    let err_cb =
      recover val
        {(err: MultipartParseError)(h) =>
          h.fail(
            "unexpected error: " + err.string())
          h.complete(false)
        }
      end
    let n = CollectParts(cb, err_cb)
    // Feed in small chunks to force multiple
    // body_chunk deliveries
    MultipartParser(n, "boundary")
      .> parse(
        _ToVal("--boundary\r\n\r\nabcde"))
      .> parse(
        _ToVal("fghij\r\n--boundary--"))

class \nodoc\ _TestCollectPartsHeaders is UnitTest
  """
  CollectParts preserves headers on collected parts.
  """
  fun name(): String =>
    "collect_parts/headers preserved"

  fun apply(h: TestHelper) =>
    h.long_test(2_000_000_000)
    let cb =
      recover val
        {(parts: Array[CollectedPart val] val)(h) =>
          try
            h.assert_eq[USize](1, parts.size())
            let hdrs = parts(0)?.headers
            h.assert_eq[USize](2, hdrs.size())
            h.assert_eq[String](
              "text/plain",
              hdrs.get("Content-Type") as String)
            h.assert_eq[String](
              "form-data; name=\"f\"",
              hdrs.get("Content-Disposition")
                as String)
          else
            h.fail(
              "unexpected error accessing headers")
          end
          h.complete(true)
        }
      end
    let err_cb =
      recover val
        {(err: MultipartParseError)(h) =>
          h.fail(
            "unexpected error: " + err.string())
          h.complete(false)
        }
      end
    let n = CollectParts(cb, err_cb)
    MultipartParser(n, "boundary")
      .> parse(
        _ToVal(
          "--boundary\r\n"
            + "Content-Type: text/plain\r\n"
            + "Content-Disposition:"
            + " form-data; name=\"f\"\r\n"
            + "\r\ndata"
            + "\r\n--boundary--"))
