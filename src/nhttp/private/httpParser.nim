import macros, bitops, httpcore

macro getCPU: untyped =
  let CPU = staticExec(
    "nim c -r --hints:off --verbosity:0 SIMD/getCPU")

  if CPU == "SSE41\n" or CPU == "SSE41":
    return quote do:
      import SIMD/[x86_sse2, x86_sse3, x86_ssse3]
      proc fastURLMatch(buf: ptr char): int =
        let LSH = set1_epi8(0x0F'i8)
        let URI = setr_epi8(
          0xb8'i8, 0xfc'i8, 0xf8'i8, 0xfc'i8, 0xfc'i8, 0xfc'i8, 0xfc'i8, 0xfc'i8,
          0xfc'i8, 0xfc'i8, 0xfc'i8, 0x7c'i8, 0x54'i8, 0x7c'i8, 0xd4'i8, 0x7c'i8,
        )
        let ARF = setr_epi8(
          0x01'i8, 0x02'i8, 0x04'i8, 0x08'i8, 0x10'i8, 0x20'i8, 0x40'i8, 0x80'i8,
          0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8,
        )
        let data = lddqu_si128(cast[ptr m128i](buf))
        let rbms = shuffle_epi8(URI, data)
        let cols = and_si128(LSH, srli_epi16(data, 4))
        let bits = and_si128(shuffle_epi8(ARF, cols), rbms)
        let v = cmpeq_epi8(bits, setzero_si128())
        let r = 0xffff_0000 or movemask_epi8(v)
        return countTrailingZeroBits(r)
      proc fastHeaderMatch(buf: ptr char): int =
        let TAB = set1_epi8(0x09)
        let DEL = set1_epi8(0x7f)
        let LOW = set1_epi8(0x1f)
        let dat = lddqu_si128(cast[ptr m128i](buf))
        let low = cmpgt_epi8(dat, LOW)
        let tab = cmpeq_epi8(dat, TAB)
        let del = cmpeq_epi8(dat, DEL)
        let bit = andnot_si128(del, or_si128(low, tab))
        let rev = cmpeq_epi8(bit, setzero_si128())
        let res = 0xffff_0000 or movemask_epi8(rev)
        return countTrailingZeroBits(res)
      proc urlVector*(buf: var ptr char, bufLen: var int) =
        while bufLen >= 16:
          let ret = fastURLMatch(buf)
          buf += ret
          bufLen -= ret
          if ret != 16: break
      proc headerVector*(buf: var ptr char, bufLen: var int) =
        while bufLen >= 16:
          let ret = fastHeaderMatch(buf)
          buf += ret
          bufLen -= ret
          if ret != 16: break
  elif CPU == "AVX2\n" or CPU == "AVX2":
    return quote do:
      import SIMD/[x86_avx, x86_avx2, x86_ssse3]
      proc fastURLMatch(buf: ptr char): int =
        let LSH = set1_epi8(0x0F'i8)
        let URI = setr_epi8(
          0xb8'i8, 0xfc'i8, 0xf8'i8, 0xfc'i8, 0xfc'i8, 0xfc'i8, 0xfc'i8, 0xfc'i8,
          0xfc'i8, 0xfc'i8, 0xfc'i8, 0x7c'i8, 0x54'i8, 0x7c'i8, 0xd4'i8, 0x7c'i8,
          0xb8'i8, 0xfc'i8, 0xf8'i8, 0xfc'i8, 0xfc'i8, 0xfc'i8, 0xfc'i8, 0xfc'i8,
          0xfc'i8, 0xfc'i8, 0xfc'i8, 0x7c'i8, 0x54'i8, 0x7c'i8, 0xd4'i8, 0x7c'i8,
        )
        let ARF = setr_epi8(
          0x01'i8, 0x02'i8, 0x04'i8, 0x08'i8, 0x10'i8, 0x20'i8, 0x40'i8, 0x80'i8,
          0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8,
          0x01'i8, 0x02'i8, 0x04'i8, 0x08'i8, 0x10'i8, 0x20'i8, 0x40'i8, 0x80'i8,
          0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8, 0x00'i8,
        )
        let data = lddqu_si256(cast[ptr m256i](buf))
        let rbms = shuffle_epi8(URI, data)
        let cols = and_si256(LSH, srli_epi16(data, 4))
        let bits = and_si256(shuffle_epi8(ARF, cols), rbms)
        let v = cmpeq_epi8(bits, setzero_si256())
        let r = 0xffff_0000 or movemask_epi8(v)
        return countTrailingZeroBits(r)
      proc fastHeaderMatch(buf: ptr char): int =
        let TAB = set1_epi8(0x09)
        let DEL = set1_epi8(0x7f)
        let LOW = set1_epi8(0x1f)
        let dat = lddqu_si256(cast[ptr m256i](buf))
        let low = cmpgt_epi8(dat, LOW)
        let tab = cmpeq_epi8(dat, TAB)
        let del = cmpeq_epi8(dat, DEL)
        let bit = andnot_si256(del, or_si256(low, tab))
        let rev = cmpeq_epi8(bit, setzero_si256())
        let res = 0xffff_0000 or movemask_epi8(rev)
        return countTrailingZeroBits(res)
      proc urlVector(buf: var ptr char, bufLen: var int) =
        while bufLen >= 32:
          let ret = fastURLMatch(buf)
          buf += ret
          bufLen -= ret
          if ret != 32: break
      proc headerVector(buf: var ptr char, bufLen: var int) =
        while bufLen >= 32:
          let ret = fastHeaderMatch(buf)
          buf += ret
          bufLen -= ret
          if ret != 32: break
  else:
    return quote do:
      proc urlVector(buf: var ptr char, bufLen: var int) =
        discard
      proc headerVector(buf: var ptr char, bufLen: var int) =
        discard

const URI_TOKEN = [
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1,
  0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0,
  # ====== Extended ASCII (aka. obs-text) ======
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]

const HEADER_NAME_TOKEN = [
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
  0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]

const HEADER_VALUE_TOKEN = [
  0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
]

const headerSize {.intdefine.} = 64

type
  HttpRequestData* = ref object
    httpMethod, httpPath: ptr char
    headers: array[headerSize, HttpHeaderData]
    httpMajor, httpMinor: char
    httpMethodLen, httpPathLen, httpHeaderLen: int

  HttpHeaderData* = object
    headerName, headerValue: ptr char
    headerNameLen, headerValueLen: int

template `+`[T](p: ptr T, off: int): ptr T =
    cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))

template `+=`[T](p: ptr T, off: int) =
  p = p + off

template `-`[T](p: ptr T, off: int): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) -% off * sizeof(p[]))

template `-`[T](p: ptr T, p2: ptr T): int =
  cast[int](p) - cast[int](p2)

template `-=`[T](p: ptr T, off: int) =
  p = p - off

template `[]`[T](p: ptr T, off: int): T =
  (p + off)[]

template `[]=`[T](p: ptr T, off: int, val: T) =
  (p + off)[] = val

getCPU() # generate proc

proc parseHttpHeader*(headers: var array[headerSize, HttpHeaderData], buf: var ptr char, bufLen: int): int =
  var bufStart = buf
  var headerLen = 0

  while true:
    case buf[]:
      of '\0':
        return -1

      of '\r':
        buf += 1
        if buf[] != '\l': return -1
        buf += 1
        if buf[] == '\r':
          buf += 1
          if buf[] == '\l':
            break

      of '\l':
        buf += 1
        if buf[] == '\l':
          break

      else:
        # HEADER NAME CHECK
        if not HEADER_NAME_TOKEN[buf[].int].bool: return -1
        var start = buf
        var bufEnd = buf
        while true:
          if buf[] == ':':
            bufEnd = buf - 1
            buf += 1
            # skip whitespace
            while true:
              if buf[] == ' ' or buf[] == '\t':
                buf += 1
                break
            break
          else:
            if not HEADER_NAME_TOKEN[buf[].int].bool: return -1
          buf += 1

        headers[headerLen].headerName = start
        headers[headerLen].headerNameLen = bufEnd - start

        # HEADER VALUE CHECK
        var bufLen = bufLen - (buf - bufStart)
        start = buf
        headerVector(buf, bufLen)
        while true:
          if buf[] == '\r' or buf[] == '\l':
            break
          else:
            if not HEADER_VALUE_TOKEN[buf[].int].bool:
              return -1
          buf += 1

        headers[headerLen].headerValue = start
        headers[headerLen].headerValueLen = buf - start - 1
        headerLen.inc()

  return headerLen

proc parseHttpRequest*(requestData: HttpRequestData, requestBuffer: ptr char, requestLength: int): int =
  # argment initialization
  requestData.httpMethod = nil
  requestData.httpPath = nil
  requestData.httpMethodLen = 0
  requestData.httpPathLen = 0
  requestData.httpHeaderLen = 0

  var buffer = requestBuffer
  var bufferLength = requestLength

  # METHOD CHECK
  # 'var start' is first pointer of HTTP Method string.
  var start = buffer
  while true:
    if buffer[] == ' ':
      # skip whitespace
      buffer += 1
      break
    else:
      if not (buffer[] > '\x1f' and buffer[] < '\x7f'):
        return -1
    buffer += 1

  requestData.httpMethod = start
  requestData.httpMethodLen = buffer - start - 2

  # PATH CHECK
  # 'var start' is first pointer of HTTP Path string.
  start = buffer
  bufferLength = bufferLength - (buffer - requestBuffer)
  urlVector(buffer, bufferLength)
  while true:
    if buffer[] == ' ':
      # skip whitespace
      buffer += 1
      break
    else:
      if not URI_TOKEN[buffer[].int].bool:
        return -1
    buffer += 1

  requestData.httpPath = start
  requestData.httpPathLen = buffer - start - 2

  # VERSION CHECK
  if buffer[] != 'H': return -1
  buffer += 1
  if buffer[] != 'T': return -1
  buffer += 1
  if buffer[] != 'T': return -1
  buffer += 1
  if buffer[] != 'P': return -1
  buffer += 1
  if buffer[] != '/': return -1
  buffer += 1
  if buffer[] != '1' and buffer[] != '2': return -1
  requestData.httpMajor = buffer[]
  buffer += 1
  if buffer[] != '.': return -1
  buffer += 1
  if buffer[] != '0' and buffer[] != '1': return -1
  requestData.httpMinor = buffer[]

  # skip version, for example: HTTP/1.1
  #                                   ^
  buffer += 1

  # PARSE HEADER
  bufferLength = bufferLength - (buffer - requestBuffer)
  let headerLen = requestData.headers.parseHttpHeader(buffer, bufferLength)

  if headerLen == -1: return -1
  requestData.httpHeaderLen = headerLen
  return buffer - requestBuffer + 1

proc getMethod*(req: HttpRequestData): string {.inline.} =
  result = ($(req.httpMethod))[0 .. req.httpMethodLen]

proc getPath*(req: HttpRequestData): string {.inline.} =
  result = ($(req.httpPath))[0 .. req.httpPathLen]

proc getHeader*(req: HttpRequestData, name: string): string {.inline.} =
  result = ""
  for i in 0 ..< req.httpHeaderLen:
    if ($(req.headers[i].headerName))[0 .. req.headers[i].headerNameLen] == name:
      result = ($(req.headers[i].headerValue))[0 .. req.headers[i].headerValueLen]
      return

proc getMajor*(req: HttpRequestData): char {.inline.} =
  req.httpMajor

proc getMinor*(req: HttpRequestData): char {.inline.} =
  req.httpMinor

iterator headersPair*(req: HttpRequestData): tuple[name, value: string] =
  for i in 0 ..< req.httpHeaderLen:
    yield (($(req.headers[i].headerName))[0 .. req.headers[i].headerNamelen],
           ($(req.headers[i].headerValue))[0 .. req.headers[i].headerValuelen])

proc toHttpHeaders*(req: HttpRequestData): HttpHeaders =
  var headers = newSeq[tuple[key: string, val: string]]()

  for header in req.headersPair:
    headers.add((header.name, header.value))

  return headers.newHttpHeaders

when isMainModule:
  import times

  var buf =
    "GET /test HTTP/1.1\r\l" &
    "Host: 127.0.0.1:8080\r\l" &
    "Connection: keep-alive\r\l" &
    "Cache-Control: max-age=0\r\l" &
    "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\l" &
    "User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64) " &
      "AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.56 Safari/537.17\r\l" &
    "Accept-Encoding: gzip,deflate,sdch\r\l" &
    "Accept-Language: en-US,en;q=0.8\r\l" &
    "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\l" &
    "Cookie: name=mofuparser\r\l" &
    "\r\l" &
    "test=hoge"

  var reqData = HttpRequestData()

  assert reqData.parseHttpRequest(buf[0].addr, buf.len) > 0
  assert reqData.getMethod() == "GET"
  assert reqData.getPath() == "/test"
  assert reqData.getMajor() == '1'
  assert reqData.getMinor() == '1'