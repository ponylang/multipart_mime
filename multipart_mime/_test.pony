use "pony_test"
use "pony_check"

actor \nodoc\ Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    // Parser tests
    test(_TestSinglePart)
    test(_TestMultipleParts)
    test(_TestEmptyBody)
    test(_TestNoHeaders)
    test(_TestPreambleDiscarded)
    test(_TestEpilogueIgnored)
    test(_TestTransportPadding)
    test(_TestIncrementalFeeding)
    test(_TestPartialBoundaryInBody)
    test(_TestInvalidBoundaryEmpty)
    test(_TestInvalidBoundaryTooLong)
    test(_TestInvalidBoundaryBadChar)
    test(_TestMalformedHeaderNoColon)
    test(_TestMalformedHeaderObsFold)
    test(_TestUnexpectedEndInHeaders)
    test(_TestUnexpectedEndInBody)
    test(_TestUnexpectedEndInPreamble)
    test(_TestHeadersTooLarge)
    test(_TestPartBodyTooLarge)
    test(_TestTooManyParts)
    test(_TestStop)
    test(_TestEmptyMultipart)
    test(_TestMaxBoundaryLength)
    test(_TestMultipleHeaders)
    test(_TestCrlfOwnership)
    test(_TestFinishAfterComplete)
    test(_TestPreambleTooLarge)
    test(_TestMalformedBoundaryLine)
    test(_TestMalformedBoundaryTermination)
    test(_TestTransportPaddingBetweenParts)
    test(_TestBodyAtExactLimit)
    test(_TestFinishWithoutParse)
    test(_TestBinaryBodyData)
    test(_TestStopMidPart)
    test(_TestStopFromPartBegin)
    test(_TestStopFromPartEnd)
    test(_TestParseAfterFinish)
    test(_TestParseAfterError)
    test(_TestBodySizeLimitChunked)
    test(_TestStopFromParseError)
    test(_TestStopDuringFinishBodyTooLarge)
    test(_TestStopDuringParseBodyTooLarge)
    test(_TestInvalidBoundaryTrailingSpace)
    test(_TestValidBoundaryInternalSpace)
    test(_TestStopFromFinished)
    test(_TestHeaderEmptyValue)
    test(_TestMalformedHeaderWhitespaceBeforeColon)
    test(_TestMalformedBoundaryLineBody)
    test(_TestHeadersTooLargePending)
    test(_TestTransportPaddingAtCap)
    test(_TestInvalidBoundaryFinishOnly)
    test(_TestCallbackOrdering)
    test(_TestStopFromBodyChunkDuringFinish)

    // PartHeaders tests
    test(_TestPartHeadersCaseInsensitive)
    test(_TestPartHeadersGetAll)
    test(_TestPartHeadersMissing)
    test(_TestPartHeadersSize)
    test(_TestPartHeadersValues)

    // FormData tests
    test(_TestFormDataFieldName)
    test(_TestFormDataFileName)
    test(_TestFormDataNoFileName)
    test(_TestFormDataQuotedEscape)
    test(_TestFormDataContentType)
    test(_TestFormDataNoDisposition)
    test(_TestFormDataContentDisposition)
    test(_TestFormDataCaseInsensitiveParam)
    test(_TestFormDataUnquotedValue)
    test(_TestFormDataSemicolonInQuotes)
    test(_TestFormDataEmptyParamValue)
    test(_TestFormDataUnterminatedQuote)

    // CollectParts tests
    test(_TestCollectPartsBasic)
    test(_TestCollectPartsZeroParts)
    test(_TestCollectPartsError)
    test(_TestCollectPartsMultipleChunks)
    test(_TestCollectPartsHeaders)

    // Property-based tests
    test(Property1UnitTest[_MultipartMessage val](
      _TestRoundtripProperty))
    test(Property1UnitTest[_ChunkedMessage val](
      _TestChunkedRoundtripProperty))
    test(Property1UnitTest[_MultipartMessage val](
      _TestBoundaryNeverInBody))
    test(Property1UnitTest[_MultipartMessage val](
      _TestTruncationDetected))
    test(Property1UnitTest[_MessageWithExtras val](
      _TestPreambleEpilogueIgnored))
    test(Property1UnitTest[_TruncatedMessage val](
      _TestInvalidInputProperty))
