import strtabs, httpcore
import ctx, httpParser, httpUtils

type
  ValidCode* = enum
    bad,
    bodyLarge,
    yet,
    ok

proc body*(ctx: ClientCtx, key: string = ""): string =
  if key == "": return $ctx.buf[ctx.bodyStart ..< ctx.bufLen]
  if ctx.bodyParams.len == 0: ctx.bodyParams = ctx.body.bodyParse
  ctx.bodyParams.getOrDefault(key)

proc getMethod*(ctx: ClientCtx): string {.inline.} =
  result = getMethod(ctx.parseData)

proc getPath*(ctx: ClientCtx): string {.inline.} =
  result = getPath(ctx.parseData)

proc getHeader*(ctx: ClientCtx, name: string): string {.inline.} =
  result = getHeader(ctx.parseData, name)

proc toHttpHeaders*(ctx: ClientCtx): HttpHeaders {.inline.} =
  result = ctx.parseData.toHttpHeaders()

proc setParam*(ctx: ClientCtx, params: StringTableRef) {.inline.} =
  ctx.uriParams = params

proc setQuery*(ctx: ClientCtx, query: StringTableRef) {.inline.} =
  ctx.uriQuerys = query

proc params*(ctx: ClientCtx, key: string): string =
  ctx.uriParams.getOrDefault(key)

proc query*(ctx: ClientCtx, key: string): string =
  ctx.uriQuerys.getOrDefault(key)

proc checkRequestIsValid*(ctx: ClientCtx): ValidCode =
  # ##
  # parse request
  # ##
  let httpParseSuccess = ctx.parseData.parseHttpRequest(addr ctx.buf[ctx.currentBufPos], ctx.bufLen - 1) != -1

  if not httpParseSuccess: return bad

  # ##
  # found HTTP Method, return
  # not found, 0 length string
  # ##
  let httpMethod = ctx.getMethod()

  if likely(httpMethod == "GET" or httpMethod == "HEAD"):
    # ##
    # check \r\l\r\l
    # ##
    let last = ctx.bufLen
    if ctx.buf[last-1] == '\l' and ctx.buf[last-2] == '\r' and
       ctx.buf[last-3] == '\l' and ctx.buf[last-4] == '\r':
      # ##
      # if not bodyStart > 0, request is invalid.
      # ##
      # if likely(bodyStart != -1):
      #   ctx.bodyStart = bodyStart
      #   return endReq
      # else:
      #   return badReq
      return ok
    # ##
    # if not end \r\l\r\l, the request may be in progress
    # ##
    else: return yet
  else:
    if unlikely(httpMethod == ""):
      template lenCheck(str: string, idx: int): char =
        if idx > str.len - 1: '\0'
        else: str[idx]

      # ##
      # very slow \r\l\r\l check
      # ##
      for i, ch in ctx.buf:
        if ch == '\r':
          if ctx.buf.lenCheck(i+1) == '\l' and
             ctx.buf.lenCheck(i+2) == '\r' and
             ctx.buf.lenCheck(i+3) == '\l':
            # ##
            # Even if it ends with \r\l\r\l,
            # but it is an illegal request because the method is empty
            # ##
            return bad

      # ##
      # if the method is empty and does not end with \r\l\r\l,
      # the request may be in progress
      # for example, send it one character at a time (telnet etc.)
      # G -> E -> T
      # ##
      return yet

    # ##
    # ctx.buf.len - bodyStart = request body size
    # ##
    if unlikely(ctx.parseData.getBodySize > ctx.maxBodySize):
      return bodyLarge
    else:
      # ##
      # if the body is 0 or more,
      # the parse itself is always successful so it is a normal request
      # whether the data of the body is insufficient is not to check here
      # ##
      if likely(ctx.parseData.getBodyStart > 0):
        return ok
      else:
        return yet
