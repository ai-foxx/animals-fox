0 ( Multiprogrammer)
 1 HEX  D7FF CONSTANT WAKE  ( W PIP)
 2      E92E EQU sleep  ( IS sg  next jmp)   DECIMAL
 3
 4 ASSEMBLER HERE   U POP   U DEC   U DEC   sleep #h U ) MOV
 5    S0 4- U) S MOV   I POP   R POP   NEXT  ( +50)
 6
 7 CODE PAUSE   STD   LODS   CLD  ( WAIT+11 => + 82+16*t)
 8    HERE USE   WAKE #h U ) MOV  ( STOP+5 => 80+16*t)
 9 HERE >R   R PUSH   I PUSH   S S0 4- U) MOV
10    ( *) # W MOV   ( STATUS 2+ U] LIS  ( 26)   EVENTS INC
11    STATUS 6 + U) 0 LEA   STATUS 2+ U) 0 ADD   0 LIP
12 R> CONSTANT WAIT  ( + 26+{16*t}+50)
13 CODE STOP   WAIT USE  ( 26+{16*t}+50)
14 CODE ^TASK ( a - a)   W POP   2 W) W ADD   6 W) W LEA
15    W PUSH   NEXT