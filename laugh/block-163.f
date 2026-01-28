163                 0 Refs    0 Other blocks
 0    ( Macros)
 1 ASSEMBLER DEFINITIONS
 2 : f' ( x y z - x)   ROT DUP ( x) I MOV   DUP R MOV   I COM
 3    ROT ( y) R AND   SWAP ( z) I AND   R I OR ;
 4 : g' ( x y z - x)   DUP ( z) I MOV   R MOV   I COM
 5    OVER ( x) R AND   ( y) I AND   R I OR ;
 6 : h' ( x y z - x)   I MOV   I XOR   DUP I XOR ;
 7 : i' ( x y z - x)   I MOV   I COM   OVER I OR   I XOR ;
 8
 9 : m5 ( a b Xi sh Ti)   ( Ti) # I ADD   SWAP ( Xi) 4* W) I ADD
10    ROT ( a) DUP >R  I ADD   I SWAP ( sh) # ROL   ( b) I ADD
11    I R> ( a) MOV ;
12 FORTH DEFINITIONS