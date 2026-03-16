use "pony_test"

class \nodoc\ _TestPartHeadersCaseInsensitive is UnitTest
  fun name(): String =>
    "part_headers/case-insensitive lookup"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("content-type", "text/plain")
            ("x-custom", "value") ]
        end)
    h.assert_eq[String](
      "text/plain",
      try headers.get("Content-Type") as String
      else ""
      end)
    h.assert_eq[String](
      "text/plain",
      try headers.get("content-type") as String
      else ""
      end)
    h.assert_eq[String](
      "text/plain",
      try headers.get("CONTENT-TYPE") as String
      else ""
      end)

class \nodoc\ _TestPartHeadersGetAll is UnitTest
  fun name(): String => "part_headers/get_all"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [ ("x-multi", "a")
            ("x-other", "b")
            ("x-multi", "c") ]
        end)
    let all = headers.get_all("X-Multi")
    h.assert_eq[USize](2, all.size())
    try
      h.assert_eq[String]("a", all(0)?)
      h.assert_eq[String]("c", all(1)?)
    else
      h.fail(
        "unexpected error accessing get_all results")
    end

class \nodoc\ _TestPartHeadersMissing is UnitTest
  fun name(): String =>
    "part_headers/missing header returns None"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          Array[(String val, String val)]
        end)
    match \exhaustive\ headers.get("X-Missing")
    | None => None
    | let s: String =>
      h.fail("expected None, got: " + s)
    end

class \nodoc\ _TestPartHeadersSize is UnitTest
  fun name(): String => "part_headers/size"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [("a", "1"); ("b", "2"); ("c", "3")]
        end)
    h.assert_eq[USize](3, headers.size())

class \nodoc\ _TestPartHeadersValues is UnitTest
  fun name(): String =>
    "part_headers/values iteration"

  fun apply(h: TestHelper) =>
    let headers =
      PartHeaders(
        recover val
          [("a", "1"); ("b", "2")]
        end)
    var count: USize = 0
    for (k, v) in headers.values() do
      count = count + 1
    end
    h.assert_eq[USize](2, count)
