import asyncdispatch
import ctx, io, http, httpParser, httpUtils

proc notFound*(ctx: ClientCtx) {.async.} =
  await ctx.send(notFound(), true)

proc badRequest*(ctx: ClientCtx) {.async.} =
  await ctx.send(badRequest(), true)

proc bodyTooLarge*(ctx: ClientCtx) {.async.} =
  await ctx.send(bodyTooLarge(), true)

proc badGateway*(ctx: ClientCtx) {.async.} =
  await ctx.send(
    makeResp(
      HTTP502,
      "text/plain",
      "502 Bad Gateway"
    ), true)

proc handler*(server: ServerCtx, client: ClientCtx) {.async.} =
  while true:
    let recv = await client.read(server.timeOut)

    if recv == 0:
      client.close(); return

    # TODO: will change
    # buffer is full, request is progress
    # if unlikely(ctx.buf.len == ctx.bufLen): continue

    case client.checkRequestIsValid()
    of bad:
      await client.notFound()
      client.close()
      return
    of bodyLarge:
      await client.bodyTooLarge()
      client.close()
      return
    of yet:
      continue
    of ok:
      await server.handler(client)

      client.currentBufPos += client.parseData.getBodyStart()

      if client.bufLen - client.currentBufPos > 0: continue

      if client.respLen != 0: asyncCheck client.send()
      client.bufLen = 0
      client.currentBufPos = 0
