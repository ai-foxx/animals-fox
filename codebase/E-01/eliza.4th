( Eliza 10/22/95  20:24:17)  0 28 +md !
forget task : task ;

\ ------------------------------------------------------------
\                     Part 0a - Background
\ -----------------String words from Strings.pf---------------
: LENGTH  ,$ 3016 ,$ 4a33 ,$ 0000 ,$ 6706 ,$ 0640 ,$ 0001
    ,$ 60f4 ,$ 9056 ,$ 3c80 ;
: $CLEAR  ,$ 301E ,$ 4233 ,$ 0000 ;
: >NULL  dup c@ 2dup + >r swap dup 1+ swap rot cmove  r> $clear ;
: >COUNT  dup length >r dup dup 1+ r cmove  r> swap c! ;  
: 0TYPE  dup length dup IF type ELSE 2drop THEN ;
: ACCEPT  2dup 1+ 0 fill  >r dup r> expect dup length 1- + $clear ;
: $=  dup length 1+  -1 swap 2swap rot 0 DO  over r + c@
    over r + c@  =  0= IF rot 1+ rot rot leave THEN  LOOP 2drop ;
: $COPY  over length 1+ cmove ;
: $+  dup length + $copy ;
: $LEFT  over length min  +  $clear ;
: $RIGHT  over length over - 0> IF  over length over -  rot dup
    rot +  swap rot 1+  cmove  ELSE 2drop THEN ;
: $MID  rot rot over length  swap - 1+  >r dup r> $right  swap $left ;
: $UPPER  dup >count  dup upper  dup >null drop ;
variable POS
: $FIND  0 pos !  over length over length - 2+  1  DO
      over here $copy  here  over length  r swap  $mid
      here over  $= IF  r pos !  leave THEN
    LOOP  2drop pos @ ;
: $REPLACE  rot >r swap r over $find ?dup IF
      r here $copy  r over 1-  $left  rot r $+  swap length +
      here length  swap - 1+  here swap $right  here r> $+
    ELSE 2drop r> drop  THEN ;
: $CONSTANT CREATE  125 word here c@ 1+ dup 2 mod + allot  0 [compile] ,
    DOES>  count drop ;
: $VARIABLE CREATE 1+ allot ;
: $ARRAY CREATE  dup ,  * allot DOES>  dup @ rot * + 2+ ;
: ${ 125 word  here >null  here swap $copy ;

\ ------------------------------------------------------------
\                      Part 0b - Background
\ -----------------File words from DataFiles.pf---------------
variable FCB 78 allot  ( our File's Control Block )
: +FCB ( offset -- addr ) fcb + ;  ( offset into fcb )
: FTRAP ( -- ) fcb >abs  ,$ 205E ;  ( movea.l [ps]+,a0 )
: CLOSE ( -- ) ftrap ,$ A001  ftrap ,$ A013 ;  ( _Close & _FlushBuffer )
: .ERROR ( error# -- ) ." Disk Error" .  close  abort ;
variable ^ERROR  ' .error ^error !
: DERROR ( -- error# ) 16 +fcb @ ;
: ?DERROR ( -- ) derror ?dup IF  ^error @ execute THEN ;
: !FILE ( string[255] wd# - )
    fcb 80 0 fill      \    clear the fc buffer
    22 +fcb  !          \   set vRefnum to n (zero means same folder)
    >abs  18 +fcb  2! ;  \  set name to string
: OPENFILE ( string[255] wd# - ) !file ftrap ,$ A000 ?derror ;  \ _HOpen
: OPEN ( string[255] -- ) 0 openfile ; \ for the lazy: file in same folder
: ?FILEOK ( string[255] wd# -- flag ) \ true if exists, has permission, etc.
    !file ftrap ,$ A000  derror 0= close ;
: NEWFILE ( string[255] wd# -- )
    !file ftrap ,$ A008  ?derror  ( _Create )
    ,s TEXT 32 +fcb 2!             \ TEXT type
    ftrap ,$ A00D ?derror ;       ( _SetFileInfo )
: @SIZE ( -- bytes ) ftrap ,$ A011  30 +fcb @ ;  ( _GetEOF )
: !SIZE ( bytes -- ) 38 +fcb ! ;      \ set bytes-to-read/write
: !BUFF ( addr -- ) >abs 32 +fcb 2! ;  \ set read/write buffer pointer
: READ ( addr count -- )  !size !buff ftrap ,$ A002  ?derror ;  ( _Read )
: WRITE ( addr count -- ) !size !buff ftrap ,$ A003  ?derror ;  ( _Write )
: CREAD ( addr c -- bytes_read ) \ See Inside Mac for how this works
    44 +fcb c!  128 45 +fcb c!  \ setup ioPosMode
    @size read  42 +fcb @ ;     \ put lowbyte of ioActCount on stack
: GETCHR ( -- c ) here 1 read  here c@ ;
: PUTCHR ( c -- ) here c!  here 1 write ;

\ ------------------------------------------------------------
\                     Part 0c - Background
\ ----------------------additional stuff----------------------

: -$TRAILING ( string -- ) \ remove trailing spaces.
    BEGIN dup length 1- + dup c@ 32 =
    WHILE 0 over c! REPEAT drop ;

: -$LEADING ( string -- )  \ remove leading space
    dup BEGIN dup c@ 32 = WHILE 1+ REPEAT
    over - over length swap - $right ;

$constant DSPACE   }  $constant SP  }
: -$DOUBLESPACE ( string -- ) \ remove double spaces.
    BEGIN
      dup here 512 + $copy
      dup dspace sp $replace
      dup here 512 + $=
    UNTIL drop ;

: -$MARKERS ( string -- ) \ remove @ and * markers and replace with spaces
    dup length 0 DO
      dup r + c@ dup 64 = swap 42 = or IF
      dup r + 32 swap c! THEN
    LOOP -$doublespace ;

: $CLEANUP ( string -- ) dup -$trailing dup -$leading -$markers ;

: -$PUNCTUATION ( string -- ) \ remove ., ! and ?
    dup -$trailing
    dup  length 1- 2dup + c@
    dup 33 = swap  dup 46 = swap  63 = or or IF
    + 0 swap c! ELSE 2drop THEN ;

\ Put a space at both ends of a string.
: $PREP ( string -- ) \ prepare a string for analysis
    dup -$punctuation
    dup $upper
    here over length 3 + 0 fill
    32 here c!
    dup here $+
    dup length here + 1+ 32 swap c!
    here swap $copy ;

\ ----------------------some file stuff-------------------

13 constant [RET]
: @LINE ( string -- ) \ set string to a line from an open file
    0 swap dup [ret] cread 1- + c! ;

: !LINE ( string -- ) \ send a string to a file
    BEGIN dup c@  WHILE dup c@ putchr  1+  REPEAT drop ;

\ --------------------and some other stuff------------------

3 4 $array OFF  0 off ${ OFF}  1 off ${ off}  2 off ${ Off}
: ?ON ( string -- flag ) \ is the word off not included?
    0 swap 3 0 DO dup r off $find rot or swap LOOP drop 0= ;

\ random numbers with no repeats
: RANDOM ( n -- n' ) 0 >r ,$ A861 r>  swap 32768 */ abs ;
variable RN1  4 rn1 !  \ the last number picked
: RAND ( n -- n' ) \ never pick the same number twice in a row
   BEGIN dup random dup rn1 @ =  \ scale to zero to n range
   WHILE drop REPEAT swap drop dup rn1 ! ;

\ ------------------------------------------------------------
\                            Part 1
\ --------------Substitute one word for another---------------

32 12 $array OPS  \ opposite forms

\ When you say:            eliza sez:
00 ops ${  MOM }		01 ops ${  MOTHER }
02 ops ${  DAD }		03 ops ${  FATHER }
04 ops ${  DREAMS }		05 ops ${  DREAM }
06 ops ${  I }			07 ops ${  YOU@ }
08 ops ${  YOU }		09 ops ${  I }
10 ops ${  ME }			11 ops ${  YOU }
12 ops ${  MY }			13 ops ${  YOUR* }
14 ops ${  YOUR }		15 ops ${  MY }
16 ops ${  MYSELF }		17 ops ${  YOURSELF* }
18 ops ${  YOURSELF }	19 ops ${  MYSELF }
20 ops ${  I'M }		21 ops ${  YOU'RE* }
22 ops ${  YOU'RE }		23 ops ${  I'M }
24 ops ${  AM }			25 ops ${  ARE@ }
26 ops ${  WERE }		27 ops ${  WAS }
28 ops ${  IM }			29 ops ${  YOU'RE* }
30 ops ${  YOURE }		31 ops ${  I'M }

32 constant #OPS  \ the number of words

: $SUBSTITUTE ( string -- )
    #ops 0 DO
        BEGIN
            dup here 160 + $copy
            dup  r ops  r 1+ ops $replace
            dup here 160 + $=
        UNTIL
    2 +LOOP drop ;

\ ------------------------------------------------------------
\                           Part 2
\ -----------------------the keywords-------------------------

variable #KEYWORDS  81 #keywords ! \ number of lines in .keys file
30 constant KWSIZE   \ maximum length of a keyword

#keywords @  kwsize 8 - $array KEYS

1  keys ${ COMPUTER}
2  keys ${ INTERNET}
3  keys ${  NAME }
4  keys ${ ALIKE}
5  keys ${  LIKE }
6  keys ${  SAME }
7  keys ${ YOU@ REMEMBER}
8  keys ${ DO I REMEMBER}
9  keys ${ YOU@ DREAMED}
10  keys ${  DREAM }
11  keys ${  IF }
12  keys ${ EVERYBODY}
13  keys ${ EVERYONE}
14  keys ${ NOBODY}
15  keys ${ NO ONE}
16  keys ${ WAS YOU@ }
17  keys ${ YOU@ WAS}
18  keys ${ WAS I}
19  keys ${ YOUR* MOTHER}
20  keys ${ YOUR* FATHER}
21  keys ${ YOUR* SISTER}
22  keys ${ YOUR* BROTHER}
23  keys ${ YOUR* WIFE}
24  keys ${ YOUR* HUSBAND}
25  keys ${ YOUR* CHILDREN}
26  keys ${ YOUR* }
27  keys ${ ALWAYS}
28  keys ${ ARE I}
29  keys ${ ARE@ YOU@}
30  keys ${  HOW }
31  keys ${ BECAUSE}
32  keys ${ CAN I}
33  keys ${ CAN YOU@ }
34  keys ${ CERTAINLY}
35  keys ${ DEUTCH}
36  keys ${ ESPANOL}
37  keys ${ FRANCAIS}
38  keys ${ HELLO}
39  keys ${ I REMIND YOU OF}
40  keys ${ I ARE}
41  keys ${ I'M}
42  keys ${ ITALIANO}
43  keys ${ MAYBE}
44  keys ${  MY }
45  keys ${  NO }
46  keys ${ PERHAPS}
47  keys ${ SORRY}
48  keys ${ WHAT }
49  keys ${ WHEN }
50  keys ${ WHY DON'T I}
51  keys ${ WHY CAN'T YOU@ }
52  keys ${ YES}
53  keys ${ YOU@ WANT}
54  keys ${ YOU@ NEED}
55  keys ${  ARE }
56  keys ${  I }
57  keys ${ YOU@ ARE@ SAD}
58  keys ${ YOU'RE* SAD}
59  keys ${ YOU@ ARE@ DEPRESSED}
60  keys ${ YOU'RE* DEPRESSED}
61  keys ${ YOU@ ARE@ SICK}
62  keys ${ YOU'RE* SICK}
63  keys ${ YOU@ ARE@ HAPPY}
64  keys ${ YOU'RE* HAPPY}
65  keys ${ YOU@ ARE@ ELATED}
66  keys ${ YOU'RE* ELATED}
67  keys ${ YOU@ ARE@ GLAD}
68  keys ${ YOU'RE* GLAD}
69  keys ${ YOU@ ARE@ BETTER}
70  keys ${ YOU'RE* BETTER}
71  keys ${ YOU@ FEEL YOU@ }
72  keys ${ YOU@ THINK YOU@ }
73  keys ${ YOU@ BELIEVE YOU@ }
74  keys ${ YOU@ WISH YOU@ }
75  keys ${  YOU@ ARE@ }
76  keys ${ YOU'RE* }
77  keys ${ YOU@ CAN'T}
78  keys ${ YOU@ CANNOT}
79  keys ${ YOU@ DON'T}
80  keys ${ YOU@ FEEL}
0 81 keys c! ( )

create KEYMAP
  (  1: )     1 ,   1 ,   2 ,   3 ,   3 ,   3 ,   4 ,   5 ,   6 ,
  ( 10: )     7 ,   8 ,   9 ,   9 ,   9 ,   9 ,  10 ,  11 ,  12 ,
  ( 19: )    13 ,  13 ,  13 ,  13 ,  13 ,  13 ,  13 ,  14 ,  15 ,
  ( 28: )    16 ,  18 ,  25 ,  19 ,  20 ,  21 ,  22 ,  23 ,  23 ,
  ( 37: )    23 ,  24 ,  23 ,  26 ,  26 ,  23 ,  28 ,  29 ,  30 ,
  ( 46: )    28 ,  31 ,  25 ,  25 ,  32 ,  33 ,  22 ,  34 ,  34 ,
  ( 55: )    17 ,  27 ,  35 ,  35 ,  35 ,  35 ,  35 ,  35 ,  36 ,
  ( 64: )    36 ,  36 ,  36 ,  36 ,  36 ,  36 ,  36 ,  37 ,  37 ,
  ( 73: )    37 ,  37 ,  38 ,  38 ,  39 ,  39 ,  40 ,  41 ,   0 , 

kwsize $variable KEYWORD  \ the selected keyword
kwsize $variable TKW       \ temporary keyword

$constant KWFILE eliza.keys}  kwfile >count

80 $variable INSTRING  \ the input string
80 $variable MYSTRING
80 $variable RTSTRING

\ ---------------------------find keyword----------------------

: !RTSTRING ( pos -- ) \ set rtstring to instring right of keyword
    instring rtstring $copy
    rtstring dup length rot keyword length 1- + - $right
    rtstring $cleanup ;

variable TAB  0 tab !  9 tab c!  \ this is really a string :)
variable KNUMBER                  \ the number of the keyword
: @KEYWORD ( -- keynumber ) \ SET VARIABLES: keyword & rtstring
    0 knumber !
    kwfile open  kwsize !size     \ open the keyword file
    tkw dup @line dup >count number IF #keywords ! THEN  \ **
    #keywords @ 0 DO
      tkw @line
      tkw keyword $copy              \ copy line to keyword
      keyword dup tab $find 1- $left  \ clip key line to the keyword part
      instring keyword $find  ?dup IF           \ find keyword in instring
        tkw dup length over tab $find - $right   \ clip to the number part
        tkw dup >count number IF  knumber ! THEN  \ put value into knumber
        !rtstring LEAVE                            \ set rtstring
      THEN
    LOOP close
    knumber @ ;

\ Handle special cases.
: ?SPECIAL ( keyword.number -- response.number )
     instring dspace $= IF drop 42 THEN  \ blank input

     dup 0= IF               \  no key word found in input
       mystring length IF     \  previous reference to 'my...'
         drop  5 rand 48 +     \  bring up previous reference to 'my...'
       ELSE  drop  5 rand 43 +  \ 'please go on', etc. type responses
     THEN THEN

     dup 14 = IF rtstring mystring $copy THEN  \ SET $VARIABLE: mystring

     \ Put additional special actions here. \
    ;

\ ------------------------------------------------------------
\                            Part 3
\ --------------------------respond----------------------------

54 60 $array responses \ the responses

00 responses ${ DANGER, DANGER, WILL ROBINSON!}
01 responses ${ DOES THE INTERNET WORRY YOU?}
02 responses ${ NO NAMES, PLEASE.}
03 responses ${ HOW'S THAT?}
04 responses ${ DO YOU THINK ABOUT ^0 OFTEN?}
05 responses ${ DID YOU THINK I WOULD FORGET ^0?}
06 responses ${ REALLY, ^0?}
07 responses ${ WHAT DOES THAT DREAM SUGGEST TO YOU?}
08 responses ${ DO YOU THINK IT'S LIKELY THAT IF ^0?}
09 responses ${ REALLY, ^1?}
10 responses ${ WHAT IF YOU WERE ^0?}
11 responses ${ WERE YOU REALLY?}
12 responses ${ DO YOU WANT TO BELIEVE I WAS ^0?}
13 responses ${ TELL ME MORE ABOUT YOUR FAMILY.}
14 responses ${ YOUR ^0...}
15 responses ${ GIVE ME A SPECIFIC EXAMPLE?}
16 responses ${ WHY DO YOU CARE IF I AM ^0 OR NOT?}
17 responses ${ DID YOU THINK THEY MIGHT NOT BE ^0?}
18 responses ${ DO YOU BELIEVE YOU ARE ^0?}
19 responses ${ THATS NOT THE REAL REASON, IS IT?}
20 responses ${ YOU BELIEVE I CAN ^0, DON'T YOU?}
21 responses ${ WHETHER OR NOT YOU CAN ^0 DEPENDS MORE ON YOU THAN ON ME.}
22 responses ${ YOU SEEM SURE.}
23 responses ${ SORRY, I CAN ONLY UNDERSTAND ENGLISH.}
24 responses ${ HOW DO YOU DO.}
25 responses ${ WHY DO YOU ASK?}
26 responses ${ WHAT MAKES YOU THINK I AM ^0?}
27 responses ${ WE'RE TALKING ABOUT YOU, NOT ME.}
28 responses ${ YOU DON'T SEEM SO SURE.}
29 responses ${ WHY ARE YOU WORRIED ABOUT MY ^0?}
30 responses ${ ARE YOU SAYING `NO' JUST TO BE CONTRARY?}
31 responses ${ OH PLEASE, DON'T APPOLOGIZE.}
32 responses ${ DO YOU THINK I DON'T ^0?}
33 responses ${ DO YOU THINK YOU SHOULD BE ABLE TO ^0?}
34 responses ${ WOULD IT BE COOL IF YOU GOT ^0?}
35 responses ${ SO SORRY THAT ^1 ^0.}
36 responses ${ I AM GLAD THAT ^1 ^0?}
37 responses ${ DO YOU REALLY THINK SO?}
38 responses ${ IS IT BECAUSE YOU ARE ^0 THAT YOU CAME TO ME?}
39 responses ${ WHAT MAKES YOU THINK THAT YOU CAN'T ^0?}
40 responses ${ DON'T YOU REALLY ^0?}
41 responses ${ TELL ME MORE ABOUT THOSE FEELINGS.}
42 responses ${ DON'T BE SHY, I WON'T BITE!}
43 responses ${ TELL ME MORE.}
44 responses ${ DO GO ON...}
45 responses ${ PLEASE ELABORATE ON THAT POINT.}
46 responses ${ WHAT ELSE?}
47 responses ${ OH?...}
48 responses ${ EARLIER YOU SAID YOUR ^2...}
49 responses ${ GO BACK TO YOUR ^2 AND ELABORATE.}
50 responses ${ WHAT DID YOU MEAN WHEN YOU SAID YOUR ^2?}
51 responses ${ I WANT TO HEAR MORE ABOUT YOUR ^2.}
52 responses ${ LETS TALK ABOUT YOUR ^2.}

$constant ^0 ^0}
$constant ^1 ^1}
$constant ^2 ^2}

160 $variable RESPONSE

$constant RSFILE eliza.responses}  rsfile >count

variable #RESPONSES  0 #responses !

\ -----------------build the response string------------------

: RESPOND ( -- ) \ set variables: RESPONSE and #RESPONSES
    instring $prep
    instring $substitute
    @keyword ?special     ( -- key_number )

    rsfile open
    1+ 0 DO response @line LOOP  \ put line in RESPONSE variable.
    close

    response ^0 rtstring $replace
    response ^1 keyword  $replace
    response ^2 mystring $replace

    \ Put additional response manipulations here. \

    response $cleanup
    1 #responses +! ;

\ ------------------------------------------------------------
\                            Part 4
\ --------------------Control the program---------------------

\ ------------------create data files--\----------------------
: MAKEFILES ( -- ) \ create the files if they don't exist
    kwfile 0 ?fileok 0= IF               \ if keyword file isn't there
      kwfile 0 newfile  kwfile open       \ create and open a data file
      81 s>d <# # # # #> write  13 putchr  \ number of lines
      81 1 DO
        r keys  !line  9 putchr                \ send a string & tab
        r 1- 2* keymap + @  s>d <# #s #> write  \ add ascii key-number
        13 putchr                                \ add a cr to the end
      LOOP  9 putchr 48 putchr 13 putchr  close   \ add the last line     
    THEN
    rsfile 0 ?fileok 0= IF          \ if response file isn't there
      rsfile 0 newfile  rsfile open  \ create and open a data file
      53 0 DO
        r responses !line  13 putchr   \ send a string & cr
      LOOP close
    THEN ;

\ --------------run the program----------------

: $ELIZA ( -- output.string ) respond response ;  \ assumes instring is filled
: ELIZA
    makefiles
    mystring $clear
    ." TELL ME ABOUT IT." cr
    BEGIN
      instring 64 accept cr
    instring ?on WHILE
      $eliza 0type cr
    REPEAT
    ." OK THEN, GOODBYE!" cr ;

-1 28 +md ! page
\ Type ELIZA to enter into a conversation with your computer.
\ The files: eliza.replies and eliza.keys will be created in
\ Pocket Forth's folder.  You may change eliza's personality
\ by editing these files.   The number following the keyword
\ is line number of the eliza.replies file that will be used
\ for the response.  The replacement tokens ^0 ^1 and ^2 may
\ be included in the reply strings to be substituted for the
\ right part of the string, the keyword, and the string that
\ followed the last use of 'my...", respectivly.   The first
\ line of elia.keys iss the number of keywords in the file.
