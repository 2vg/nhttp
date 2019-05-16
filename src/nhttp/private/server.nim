import os, net, nativesockets, asyncdispatch
import io, ctx, handler, httpUtils

when defined(windows):
  from winlean import TCP_NODELAY
else:
  from posix import TCP_NODELAY

proc updateTime(fd: AsyncFD): bool =
  updateServerTime()
  return false

proc newServerSocket*(port: int): SocketHandle =
  let server = newSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.setSockOpt(OptReusePort, true)
  server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_NODELAY, 1)
  server.getFd.setBlocking(false)
  server.bindAddr(Port(port))
  server.listen()
  return server.getFd()

proc initClient*(server: ServerCtx, fd: AsyncFD, ip: string): ClientCtx =
  result = newClientCtx(server.readBufferSize, server.writeBufferSize)
  result.fd = fd
  result.ip = ip
  result.bufLen = 0
  result.respLen = 0
  result.currentBufPos = 0
  result.buf.setLen(server.readBufferSize)
  result.buf.setLen(server.writeBufferSize)

proc serve*(ctx: ServerCtx) {.async.} =
  if ctx.handler.isNil:
    raise newException(Exception, "Callback is nil. please set callback.")

  let server = ctx.port.newServerSocket().AsyncFD
  register(server)
  setServerName(ctx.serverName)
  updateServerTime()
  addTimer(1000, false, updateTime)

  while true:
    try:
      let data = await acceptAddr(server)
      setBlocking(data[1].SocketHandle, false)
      let client = ctx.initClient(data[1], data[0])
      client.maxBodySize = ctx.maxBodySize
      asyncCheck handler(ctx, client)
    except:
      await sleepAsync(1)
