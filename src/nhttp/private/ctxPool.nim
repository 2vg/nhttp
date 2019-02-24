import ctx
import deques
import mofuparser

var ctxQueue {.threadvar.}: Deque[ClientCtx]

proc createCtx*(readSize, writeSize: int): ClientCtx =
  result = newClientCtx(readSize, writeSize)
  GC_ref(result)

proc initCtxPool*(readSize, writeSize: int, cap: int) =
  ctxQueue = initDeque[ClientCtx](cap)

  #[
    for guard memory fragmentation.
  ]#
  var ctxArray = newSeq[ClientCtx](cap)

  for i in 0 ..< cap:
    ctxArray[i] = createCtx(readSize, writeSize)
    ctxQueue.addFirst(ctxArray[i])

proc getCtx*(readSize, writeSize: int): ClientCtx =
  if ctxQueue.len > 0:
    return ctxQueue.popFirst()
  else:
    return createCtx(readSize, writeSize)

proc freeCtx*(ctx: ClientCtx) =
  ctxQueue.addLast(ctx)