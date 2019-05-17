import asyncdispatch
import nhttp

proc h(c: ClientCtx) {.async.} =
  if c.getPath() == "/":
    await c.send(makeResp(
      HTTP200,
      "text/plain",
      "Hello, World!"
    ))

waitFor newServeCtx(
  port = 8888,
  handler = h
).serve
