import strtabs, asyncdispatch
import httpParser

type
  HttpHandler* = proc(ctx: ClientCtx): Future[void] {.gcsafe.}

  ServerCtx* = ref object
    servername*: string
    port*: int
    readBufferSize*, writeBufferSize*, maxBodySize*: int
    timeout*: int
    handler*: HttpHandler
    hookBeforeRequest*, hookAfterRequest*: HttpHandler
    hookBeforeResponse*, hookAfterResponse*: HttpHandler

  ClientCtx* = ref object
    fd*: AsyncFD
    parseData*: HttpRequestData
    ip*: string
    buf*, resp*: string
    bufLen*, respLen*: int
    currentBufPos*: int
    bodyStart*: int
    maxBodySize*: int
    bodyParams*, uriParams*, uriQuerys*: StringTableRef

proc newServeCtx*(servername = "nhttp", port: int,
                  readBufferSize, writeBufferSize = 4096,
                  maxBodySize = 1024 * 1024 * 5,
                  timeout = -1,
                  handler,
                  hookBeforeRequest, hookAfterRequest,
                  hookBeforeResponse, hookAfterResponse: HttpHandler = nil,
): ServerCtx =
  result = ServerCtx(
    servername: servername,
    port: port,
    readBufferSize: readBufferSize,
    writeBufferSize: writeBufferSize,
    maxBodySize: maxBodySize,
    timeout: timeout,
    handler: handler,
    hookBeforeRequest: hookBeforeRequest,
    hookAfterRequest: hookAfterRequest,
    hookBeforeResponse: hookBeforeResponse,
    hookAfterResponse: hookAfterResponse
  )

proc newClientCtx*(readSize: int, writeSize: int): ClientCtx =
  result = ClientCtx(
    buf: newString(readSize),
    resp: newString(writeSize),
    bufLen: 0,
    respLen: 0,
    currentBufPos: 0,
    parseData: HttpRequestData()
  )
