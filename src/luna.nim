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

{.experimental.}

var ee = initEventEmitter()

proc handleevent(e: EventArgs) =
    echo("Handled!")
# var output = reopen(stdout,"output",fmWrite)
ee.on("EventName", handleevent)

const
    preserveCommands = ["equals","matchs","less","greater"]
    indentSpaceNum = 4

# proc onRaiseAction(e: ref Exception):bool =
proc getIndentLevel(call:string,col:Natural):untyped {.compileTime.}=
    result = (col - call.len) div indentSpaceNum

template describe(des:string,body:untyped):untyped =
    let indentLevl = getIndentLevel("describe",instantiationInfo().column) - 1
    echo des.indent(indentLevl*indentSpaceNum)
    
    # var genericargs: EventArgs
    # genericargs.
    # ee.emit("EventName", genericargs)
    block:
        body

proc fails(n:NimNode,indent:Natural):NimNode{.compileTime.} =
    let flag = newStrLitNode("✘  ".indent( indent * indentSpaceNum ))
    result = newCall(newIdentNode"styledWriteLine",newIdentNode("stdout"),newIdentNode("fgRed"),flag,newIdentNode("resetStyle"),n.toStrLit)

proc pass(n:NimNode,indent:Natural):NimNode{.compiletime.} =
    let flag = newStrLitNode("✓  ".indent(indent * indentSpaceNum))
    result = newCall(newIdentNode"styledWriteLine",newIdentNode("stdout"),newIdentNode("styleDim"),flag,newIdentNode("resetStyle"),n.toStrLit)

macro expect(n:untyped): untyped =
    # var outputStream = newFileStream(stdout)
    result = newNimNode(nnkStmtList,n)
    let indentLevl = getIndentLevel(n.toStrLit.strVal,lineInfoObj(n).column) - 1
    # let command = newNimNode(nnkCommand,n)
    # command.add newIdentNode("doAssert")
    # command.add n
    # result.add command
    result.add newIfStmt(
        (n, pass(n,indentLevl)),
      ).add(newNimNode(nnkElse).add(fails(n,indentLevl)))
    
    # if output.isatty():
    # outputStream.write()
    

when isMainModule:
    proc plus(a,b:int):int = a + b
            
    describe "test call":
        # parallel:
        #     spawn expect plus(1,2) == 3
        #     spawn expect plus(1,2) == 4
        expect plus(1,2) == 3
        expect plus(1,2) == 4

        describe "test nested":
            expect plus(1,2) == 3