import math
import luna
import threadpool
import strutils

proc plus(a,b:int):int = a + b
proc term(k: float): float = 4 * math.pow(-1, k) / (2*k + 1)
proc pi(n: int): float =
    var ch = newSeq[float](n+1)
    parallel:
      for k in 0..ch.high:
        ch[k] = spawn term(float(k))
    for k in 0..ch.high:
      result += ch[k]

describe "test complex comparsion":
    expect plus(1,2) == plus(1,2)
    let 
        a = 1
        b = 2
        c = 3
        d = 4
    expect plus(a,b) >= plus(c,d)
    expect formatFloat(pi(5000)) == formatFloat(3.141792613595791)