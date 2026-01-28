0    ( Multiprogrammer control)
 1 CODE GRAB ( a)   W POP   W ) U CMP   0= NOT IF
 2    W ) 1 MOV   1NZ IF   W PUSH   EVENTS DEC   ' PAUSE JMP
 3       THEN   U W ) MOV   THEN   NEXT   ( 32 + 82+16*t)
 4 : GET ( a)   PAUSE GRAB ;
 5
 6 CODE RELEASE ( a)   W POP   W ) U CMP   0= IF
 7       0 # W ) MOV   EVENTS INC   THEN   NEXT