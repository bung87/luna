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

proc eval(n:NimNode):NimNode{.compileTime.} =
    let tmp = "$# [$# and $#]"
    let evalChilds = toSeq(n.children)
    let 
        leftv = evalChilds[1]
        rightv = evalChilds[2]
    result = newCall(newIdentNode("format"),newStrLitNode(tmp),n.toStrLit,leftv,rightv)

proc fails(n:NimNode):NimNode{.compileTime.} =
    let indentLevel = max(getIndentLevel(n.toStrLit.strVal,lineInfoObj(n).column) - 1,1)
    let flag = newStrLitNode("✘  ".indent( indentLevel * indentSpaceNum ))
    result = newCall(newIdentNode"styledWriteLine",newIdentNode("stdout"),newIdentNode("fgRed"),flag,newIdentNode("resetStyle"),eval(n))

proc pass(n,beginTime:NimNode):NimNode{.compileTime.} =
    result = newNimNode(nnkStmtList)
    let indentLevel = max(getIndentLevel(n.toStrLit.strVal,lineInfoObj(n).column) - 1,1)
    let flag = newStrLitNode("✓  ".indent(indentLevel * indentSpaceNum))
    let tmp = "$# ⏱ :$#s"
    let endTime = genSym(nskLet,"endTime")
    let endTimeGen = newLetStmt(endTime,newCall("epochTime"))
    result.add endTimeGen
    # let duration = infix(endTime,"-",beginTime)
    let durationCal = infix(endTime,"-",beginTime)
    let duration = newCall(newIdentNode"formatFloat",durationCal,newIdentNode"ffDecimal",newIntLitNode(3))
    let msg = newCall(newIdentNode("format"),newStrLitNode(tmp),n.toStrLit,duration)
    result.add newCall(newIdentNode"styledWriteLine",newIdentNode("stdout"),newIdentNode("styleDim"),flag,newIdentNode("resetStyle"),msg)

proc ifelse(n:NimNode):NimNode{.compileTime.} =
    result = newNimNode(nnkStmtList,n)
    
    let indentLevel = getIndentLevel(n.toStrLit.strVal,lineInfoObj(n).column) - 1
    let beginTime = genSym(nskLet,"beginTime")
    let beginTimeGen = newLetStmt(beginTime,newCall("epochTime"))
    result.add beginTimeGen
    result.add newIfStmt(
        (n, pass(n,beginTime)),
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
        msg.add " [\x1B[0;31m$#\x1B[0m]" % $ex.name
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
                let beginTime = genSym(nskLet,"beginTime")
                process.add newLetStmt(beginTime,newCall("epochTime"))
                var call = newNimNode(nnkCall)
                call.add first
                for x in secondChilds[1..^1]:
                    call.add x
                process.add call
                # let endTime = genSym(nskLet,"endTime")
                # process.add newLetStmt(endTime,newCall("epochTime"))
                process.add pass(n,beginTime)
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
    proc newEx(n:int) = 
        sleep(1000)
        
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

    describe "test complex comparsion":
        expect plus(1,2) == plus(1,2)
        let 
            a = 1
            b = 2
            c = 3
            d = 4
        expect plus(a,b) >= plus(c,d)