import ctx, asyncdispatch
import httpUtils

proc close*(ctx: ClientCtx) =
  closeSocket(ctx.fd)

proc read*(ctx: ClientCtx, timeOut: int): Future[int] {.async.} =
  if unlikely(ctx.buf.len - ctx.bufLen == 0):
    ctx.buf.setLen(ctx.buf.len + ctx.buf.len)

  let rcvLimit = ctx.buf.len - ctx.bufLen
  let recvFuture = recvInto(ctx.fd, addr ctx.buf[ctx.bufLen], rcvLimit)

  let recvSize = 
    if timeOut > 0:
      if await withTimeout(recvFuture, timeOut):
        recvFuture.read
      else:
        0
    else:
      await recvFuture

  ctx.bufLen += recvSize
  return recvSize

proc send*(ctx: ClientCtx) {.async.} =
  try:
    await send(ctx.fd, addr(ctx.resp[0]), ctx.respLen)
  except:
    discard
  finally:
    ctx.respLen = 0

proc send*(ctx: ClientCtx, body: string, sendNow = false) {.async.} =
  while unlikely ctx.respLen + body.len > ctx.resp.len:
    ctx.resp.setLen(ctx.resp.len + ctx.resp.len)

  moveMem(addr ctx.resp[ctx.respLen], unsafeAddr body[0], body.len)
  ctx.respLen += body.len

  if unlikely(sendNow): await ctx.send
