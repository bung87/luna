#  luna🌛

a nim test framework

## Usage

``` nim
    proc plus(a,b:int):int = a + b
    proc plusRaise(a,b:int):int = raise newException(ValueError,"")   
    proc newEx(n:int) = 
        sleep(1000)
        
    proc newExt(n,b:int) = raise newException(ValueError,"")      
    describe "test call":
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
```
## outputs  
```
test call
    ✓  plus(1, 2) == 3 ⏱ :0.000s
    ✘  plus(1, 2) == 4 [3 and 4]
    ✘  plusRaise [ValueError]
    test nested
        ✓  plus(1, 2) == 3 ⏱ :0.000s
test takes and exception
    ✓  newEx takes 1 ⏱ :1.005s
    ✘  newExt [ValueError]
test complex comparsion
    ✓  plus(1, 2) == plus(1, 2) ⏱ :0.000s
    ✘  plus(a, b) >= plus(c, d) [3 and 7]
```