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

proc getIndentLevel(call:string,col:Natural):untyped {.compileTime.}=
    result = (col - call.len) div indentSpaceNum

template describe*(des:string,body:untyped):untyped =
    let indentLevl = getIndentLevel("describe",instantiationInfo().column) - 1
    echo des.indent(indentLevl*indentSpaceNum)
    
    # var genericargs: EventArgs
    # genericargs.
    # ee.emit("EventName", genericargs)
    block:
        body

proc fails(n:NimNode):NimNode{.compileTime.} =
    let indentLevel = getIndentLevel(n.toStrLit.strVal,lineInfoObj(n).column) - 1
    let flag = newStrLitNode("✘  ".indent( indentLevel * indentSpaceNum ))
    result = newCall(newIdentNode"styledWriteLine",newIdentNode("stdout"),newIdentNode("fgRed"),flag,newIdentNode("resetStyle"),n.toStrLit)

proc pass(n:NimNode):NimNode{.compileTime.} =
    let indentLevel = getIndentLevel(n.toStrLit.strVal,lineInfoObj(n).column) - 1
    let flag = newStrLitNode("✓  ".indent(indentLevel * indentSpaceNum))
    result = newCall(newIdentNode"styledWriteLine",newIdentNode("stdout"),newIdentNode("styleDim"),flag,newIdentNode("resetStyle"),n.toStrLit)

proc ifelse(n:NimNode):NimNode{.compileTime.} =
    result = newNimNode(nnkStmtList,n)
    
    let indentLevel = getIndentLevel(n.toStrLit.strVal,lineInfoObj(n).column) - 1
    result.add newIfStmt(
        (n, pass(n)),
      ).add(newNimNode(nnkElse).add(fails(n)))

proc exceptionHandle(n:NimNode): NimNode =
    var indentLevel:int
    indentLevel = max(getIndentLevel(n.toStrLit.strVal,lineInfoObj(n).column) - 1,1)
    result = quote do:
        var msg = ""
        let ex = getCurrentException()
        let stacks = getStackTraceEntries(ex)
        let last = stacks[^1]
        msg.add last.procname
        msg.add " [$#]" % $ex.name
        styledWriteLine(stdout,fgRed,"✘  ".indent(`indentLevel` * indentSpaceNum ),resetStyle,msg )

macro expect*(n:untyped): untyped =
    let 
        childs = toSeq(n.children)
        childsLen = len(childs)
        first = childs[0]
        firstChilds = toSeq(first.children)

    let
        second = childs[1]
        secondChilds = toSeq(second.children)
    result = newNimNode(nnkStmtList,n)
    let tryStmt = newNimNode(nnkTryStmt)
    case second.kind:
        of nnkCommand,nnkCall:
            if secondChilds[0].basename.strVal == "takes":
                let process = newNimNode(nnkStmtList)
                var call = newNimNode(nnkCall)
                call.add first
                for x in secondChilds[1..^1]:
                    call.add x
                process.add call
                process.add pass(n)
                tryStmt.add process
            else:
                tryStmt.add ifelse(n)
        else:
            tryStmt.add ifelse(n)
    tryStmt.add newNimNode(nnkExceptBranch).add(exceptionHandle(n))
    result.add tryStmt

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
    proc plus(a,b:int):int = a + b
    proc plusRaise(a,b:int):int = raise newException(ValueError,"")   
    proc newEx(n:int) = discard  
    proc newExt(n,b:int) = raise newException(ValueError,"")      
    describe "test call":
        # parallel:
        #     spawn expect plus(1,2) == 3
        #     spawn expect plus(1,2) == 4
        expect plus(1,2) == 3
        expect plus(1,2) == 4
        expect plusRaise(1,2) == 4

        describe "test nested":
            expect plus(1,2) == 3

    describe "test takes and exception":
        expect newEx takes 1
        expect newExt takes(1,2)