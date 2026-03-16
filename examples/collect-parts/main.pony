use "../../multipart_mime"

actor Main
  new create(env: Env) =>
    // In real usage, extract the boundary from the Content-Type header
    // (e.g. "multipart/form-data; boundary=formboundary123").
    let boundary = "formboundary123"
    let msg =
      "--formboundary123\r\n"
        + "Content-Disposition:"
        + " form-data; name=\"greeting\"\r\n"
        + "\r\n"
        + "Hello, world!\r\n"
        + "--formboundary123\r\n"
        + "Content-Disposition:"
        + " form-data; name=\"count\"\r\n"
        + "\r\n"
        + "42\r\n"
        + "--formboundary123--"
    let out = env.out
    let notify =
      CollectParts(
      {(parts: Array[CollectedPart val] val)(out) =>
        out.print(
          parts.size().string() + " parts collected:")
        for part in parts.values() do
          match FormData.field_name(part.headers)
          | let name: String =>
            out.print("  " + name + " = "
              + String.from_array(part.body))
          end
        end
      },
      {(err: MultipartParseError)(out) =>
        out.print("Error: " + err.string())
      })
    let parser =
      MultipartParser(notify, boundary)
    parser
      .> parse(msg.array())
      .> finish()
