# luna
# Copyright zhoupeng
# nim test framework

import macros
import sequtils
import streams
import terminal
import threadpool
import strutils
import events
import times
import os

{.experimental.}

export terminal

var ee = initEventEmitter()

proc handleevent(e: EventArgs) =
  echo("Handled!")
# var output = reopen(stdout,"output",fmWrite)
ee.on("EventName", handleevent)

const
  preserveCommands = ["equals", "matchs", "less", "greater"]
  indentSpaceNum = 4

proc getIndentLevel(call: string, col: Natural): int {.compileTime.} =
  result = (col - call.len) div indentSpaceNum

template describe*(des: string, body: untyped): untyped =
  let indentLevl = max(getIndentLevel("describe", instantiationInfo().column) - 1, 0)
  echo des.indent(indentLevl*indentSpaceNum)

  # var genericargs: EventArgs
  # genericargs.
  # ee.emit("EventName", genericargs)
  # for x in body.children:
  #     echo $x.strVal
  block:
    body

proc eval(n: NimNode): NimNode{.compileTime.} =
  let tmp = "$# [$# and $#]"
  let evalChilds = toSeq(n.children)
  if evalChilds.len == 3:
    let
      leftv = evalChilds[1]
      rightv = evalChilds[2]
    result = newCall(newIdentNode("format"), newStrLitNode(tmp), n.toStrLit, leftv, rightv)
  else:
    result = n.toStrLit

proc fails(n: NimNode): NimNode{.compileTime.} =
  result = newNimNode(nnkStmtList)
  let indentLevel = max(getIndentLevel(n.toStrLit.strVal, lineInfoObj(n).column) - 1, 1)
  let flag = newStrLitNode("✘  ".indent(indentLevel * indentSpaceNum))
  result.add newCall(newIdentNode"styledWriteLine", newIdentNode("stdout"), newIdentNode("fgRed"), flag, newIdentNode(
      "resetStyle"), eval(n))
  result.add newNimNode(nnkReturnStmt).add newIdentNode("false")

proc pass(n, beginTime: NimNode): NimNode{.compileTime.} =
  result = newNimNode(nnkStmtList)
  let indentLevel = max(getIndentLevel(n.toStrLit.strVal, lineInfoObj(n).column) - 1, 1)
  let flag = newStrLitNode("✓  ".indent(indentLevel * indentSpaceNum))
  let tmp = "$# ⏱ :$#s"
  let endTime = genSym(nskLet, "endTime")
  let endTimeGen = newLetStmt(endTime, newCall("epochTime"))
  result.add endTimeGen
  # let duration = infix(endTime,"-",beginTime)
  let durationCal = infix(endTime, "-", beginTime)
  let duration = newCall(newIdentNode"formatFloat", durationCal, newIdentNode"ffDecimal", newIntLitNode(3))
  let msg = newCall(newIdentNode("format"), newStrLitNode(tmp), n.toStrLit, duration)
  result.add newCall(newIdentNode"styledWriteLine", newIdentNode("stdout"), newIdentNode("styleDim"), flag,
      newIdentNode("resetStyle"), msg)
  result.add newNimNode(nnkReturnStmt).add newIdentNode("true")

proc ifelse(n: NimNode): NimNode{.compileTime.} =
  result = newNimNode(nnkStmtList, n)

  let indentLevel = getIndentLevel(n.toStrLit.strVal, lineInfoObj(n).column) - 1
  let beginTime = genSym(nskLet, "beginTime")
  let beginTimeGen = newLetStmt(beginTime, newCall("epochTime"))
  result.add beginTimeGen
  result.add newIfStmt(
      (n, pass(n, beginTime)),
    ).add(newNimNode(nnkElse).add(fails(n)))

proc exceptionHandle(n: NimNode): NimNode{.compileTime.} =
  var
    indentLevel: int
    exp = n.toStrLit.strVal
  indentLevel = max(getIndentLevel(exp, lineInfoObj(n).column) - 1, 1)
  result = quote do:
    var msg = ""
    let ex = getCurrentException()
    let stacks = getStackTraceEntries(ex)
    let last = stacks[^1]
    msg.add `exp`
    msg.add " [\x1B[0;31m$#\x1B[0m]" % $ex.name
    styledWriteLine(stdout, fgRed, "✘  ".indent(`indentLevel` * indentSpaceNum), resetStyle, msg)

proc takes2(n: varargs[NimNode]): NimNode{.compileTime.} =
  result = newNimNode(nnkCall)
  result.add newEmptyNode()
  for x in n[1..^1]:
    result.add x

proc takeCall(call: var NimNode, n: NimNode): NimNode{.compileTime.} =
  var res = findChild(n, it.kind == nnkFormalParams)
  result = newNimNode(nnkStmtList, n)
  let beginTime = genSym(nskLet, "beginTime")
  result.add newLetStmt(beginTime, newCall("epochTime"))
  if res == nil:
    result.add call
  else:
    result.add newNimNode(nnkDiscardStmt).add call
  result.add pass(n, beginTime)

macro expect*(n: untyped): untyped =
  let
    childs = toSeq(n.children)
    childsLen = len(childs)

  var body = newNimNode(nnkStmtList, n)
  let tryStmt = newNimNode(nnkTryStmt)
  if childs.len > 1:
    let
      first = childs[0]
      firstChilds = toSeq(first.children)
      second = childs[1]
      secondChilds = toSeq(second.children)
    case second.kind:
      of nnkCommand, nnkCall:
        if secondChilds.len >= 1 and secondChilds[0].basename.strVal == "takes":
          var call = takes2(secondChilds)
          call[0] = first
          if childsLen > 2:
            for y in childs[1..^1]:
              call.add y
          tryStmt.add takeCall(call, n)
        else:
          tryStmt.add ifelse(n)
      else:
        tryStmt.add ifelse(n)
  else:
    tryStmt.add ifelse(n)

  tryStmt.add newNimNode(nnkExceptBranch).add(exceptionHandle(n))
  body.add tryStmt
  body.add newNimNode(nnkReturnStmt).add newIdentNode("false")
  let procname = genSym(nskProc)
  var procs = newProc(procname, [newIdentNode("bool")], body)
  procs.addPragma newIdentNode("discardable")
  procs.addPragma newIdentNode("closure")
  result = newBlockStmt(newStmtList(procs, newCall(procname)))
  # result = newCall(procname)

  # var outputStream = newFileStream(stdout)
  # result = newNimNode(nnkStmtList,n)
  # let indentLevl = getIndentLevel(n.toStrLit.strVal,lineInfoObj(n).column) - 1
  # let command = newNimNode(nnkCommand,n)
  # command.add newIdentNode("doAssert")
  # command.add n
  # result.add command

  # if output.isatty():
  # outputStream.write()

when isMainModule:

  proc plus(a, b: int): int = a + b
  proc plusRaise(a, b: int): int = raise newException(ValueError, "")
  proc newEx(n: int){.discardable.} =
    sleep(100)

  proc newExt(n, b: int){.discardable.} = raise newException(ValueError, "")

  describe "test call":
    expect plus(1, 2) == 3
    expect plus(1, 2) == 4
    expect plusRaise(1, 2) == 4

    describe "test nested":
      expect plus(1, 2) == 3

  describe "test takes and exception":
    expect newEx takes 1
    expect newExt takes(1, 2)
