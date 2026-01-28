\ ==============================================================
\  PCM16 Command-Word Analyzer (for ref.raw and test.raw)
\  --------------------------------------------------------------
\  Loads a raw 16-bit little-endian mono PCM file into memory.
\  Leaves on stack:  ( sample-addr n-samples )
\  Also prints: "Loaded <n> samples from: <filename>"
\ 
\  Requires:
\    open-file  file-size  read-file  close-file
\    allocate   free
\    c@  !  type  throw  
\  Tested with Gforth (uses file-size, not file-size@).
\ ==============================================================

decimal

\ -------------------  USER SETTINGS  -------------------------
16000 constant SAMPLE-RATE          \ Hz – must match your audio files
2      constant BYTES-PER-SAMPLE    \ 16‑bit = 2 bytes

s" ref_test.raw"   2constant REF-FILE     \ reference template (come here)
s" test_test.raw"  2constant TEST-FILE    \ file you want to scan

\ Fixed‑point parameters
14 constant FRAC-BITS               \ 14 fractional bits → 2¹⁴ = 16384
1 FRAC-BITS lshift constant SCALE     \ SCALE = 1 << FRAC-BITS (16384)

\ Scaled detection threshold (0.80 → 0.80 * SCALE)
\ 0.80e0 FRAC-BITS lshift f>s constant THRESHOLD-FIXED
\ 0.80e0 SCALE s>f f* f>s constant THRESHOLD-FIXED
13107 constant THRESHOLD-FIXED   \ 0.80 * SCALE rounded
9830  constant COARSE-THRESHOLD-FIXED \ 0.60 * SCALE rounded
16    constant COARSE-STRIDE

cr ." FRAC-BITS = " FRAC-BITS . cr
cr ." SCALE     = " SCALE . cr
cr ." THRESHOLD-FIXED (fixed-point) = " THRESHOLD-FIXED . cr

\ Detection hook (override in other code)
\ Stack effect: ( sample-idx -- ) where sample-idx is the detected position
defer on-detect
:noname drop ; is on-detect

\ Unsigned 64‑bit multiply
: umul64 ( u1 u2 -- ud )  um* ;
\ Optional alias – makes the source read like the original
: u- ( u1 u2 -- udiff ) - ;

\ --------------------------------------------------------------
\ Utility: error handling
\ --------------------------------------------------------------

: ?ior ( ior -- )
  \ If ior is non-zero, THROW it.
  ?dup IF throw THEN ;

\ --------------------------------------------------------------
\ Globals
\ --------------------------------------------------------------

variable source-fname-addr   \ c-addr of last loaded filename
variable source-fname-len    \ length of last loaded filename

variable pcm-bytes           \ even byte size of file
variable pcm-byte-buf        \ address of temporary byte buffer

variable samples-count       \ number of 16-bit samples
variable samples-buf         \ address of final sample cell buffer

\ --------------------------------------------------------------
\ Convert 2 little-endian bytes to signed 16-bit in cell
\   ( c-addr -- n )
\ --------------------------------------------------------------
: le-16@ ( c-addr -- n )
  \ Read: low byte then high byte, combine, sign-extend.
  dup 1+ c@ 256 *           \ high byte * 256
  swap c@ +                 \ + low byte => u16 [0..65535]
  dup 32768 >= IF           \ if sign bit set
    65536 -                 \ convert to negative in [-32768..-1]
  THEN ;

\ --------------------------------------------------------------
\ Convert byte buffer (16-bit LE samples) into cell buffer
\   ( byte-addr sample-addr n-samples -- )
\ --------------------------------------------------------------
: bytes>cells ( byte-addr sample-addr n-samples -- )
  0 ?DO
    over I 2 * +            \ byte-addr + 2*i
    le-16@                  \ -> sample
    over I cells +          \ sample-addr + i*cells
    !                       \ store
  LOOP
  2drop ;                   \ drop byte-addr and sample-addr

\ Double helpers
: d0! ( addr -- )  0 0 rot 2! ;
: d+! ( ud addr -- )  >r r@ 2@ d+ r> 2! ;

\ Integer square root for unsigned 64‑bit (Newton method)
: isqrt64 ( u -- u )
    { n -- }
    n 0= if 0 exit then
    n 2/ 1+ { x }
    begin
        n x / x + 2/ { x1 }
        x1 x <
    while
        x1 to x
    repeat
    x ;
\ Dot product of two integer vectors → 64‑bit result (hi lo)
: dot64 ( a-addr b-addr n -- ud )
    { a b n -- }
    0. n 0 do
        a i cells + @                  \ a[i]
        b i cells + @                  \ b[i]
        m* d+
    loop ;

\ Sum of squares → 64‑bit result (hi lo)
: sumsq64 ( a-addr n -- ud )
    { a n -- }
    0. n 0 do
        a i cells + @                  \ x
        dup m* d+
    loop ;
\ Double shift left by u bits
: d<< ( ud u -- ud )
    0 ?do d2* loop ;

\ Double absolute value
: dabs ( d -- ud )
    2dup d0< if dnegate then ;

\ Normalised correlation in fixed‑point (one-pass window sumsq)
2variable dot-acc
2variable sum-acc

    \ corr-fixed-window returns fixed-point correlation (SCALE = 1<<FRAC-BITS)
: corr-fixed-window ( test-addr ref-addr n refnorm -- corr )
    { t r n refnorm -- }
    dot-acc d0!
    sum-acc d0!
    n 0 do
        t i cells + @ { x }
        r i cells + @ x m* dot-acc d+!
        x x m* sum-acc d+!
    loop
    dot-acc 2@                         \ numerator (signed d)
    sum-acc 2@ d>s isqrt64             \ window norm (u)
    refnorm um* d>s { denom }          \ denom (u)
    denom 0= if 2drop 0 exit then
    2dup d0< if dnegate -1 else 0 then { sign }  \ save sign, make numerator positive
    FRAC-BITS d<<                       \ scale numerator
    denom um/mod nip                    \ unsigned quotient
    sign 0< if negate then ;            \ apply sign

\ --------------------------------------------------------------
\ Core loader
\   ( c-addr u -- sample-addr n-samples )
\ --------------------------------------------------------------
: load-pcm ( c-addr u -- sample-addr n-samples )
  \ Save filename for later printing
  2dup
  source-fname-addr !
  source-fname-len !

  \ Open file read-only
  r/o open-file ?ior        \ -- fileid
  >r                        \ save fileid on return stack

  \ Determine file size (assumes size fits in one cell)
  r@ file-size ?ior         \ -- ud
  drop                      \ keep low cell only: -- u-bytes

  \ Force even size (clear low bit: ignore trailing odd byte)
  1 invert and              \ u-even
  dup pcm-bytes !           \ remember even byte count

  \ Allocate temporary byte buffer
  pcm-bytes @ allocate ?ior \ -- addr
  dup pcm-byte-buf !        \ store temporary buffer address

  \ Read entire file into byte buffer
  pcm-byte-buf @            \ c-addr
  pcm-bytes @               \ u
  r@                        \ fileid
  read-file ?ior            \ -- actual-u
  drop                      \ ignore actual count (assume full read)

  \ Close file
  r> close-file ?ior        \ return stack now balanced

  \ Compute number of 16-bit samples: bytes / 2
  pcm-bytes @ 2 / dup samples-count !   \ -- n-samples

  \ Allocate final cell buffer for samples
  dup cells allocate ?ior              \ n-samples -- n-samples addr
  dup samples-buf !                    \ store buffer address
  drop                                  \ keep n-samples in variable only

  \ Convert from byte buffer into cell buffer
  pcm-byte-buf @
  samples-buf @
  samples-count @
  bytes>cells

  \ Free temporary byte buffer
  pcm-byte-buf @ free ?ior

  \ Leave ( sample-addr n-samples ) on data stack
  samples-buf @ samples-count @

  \ Print verification line (does not disturb result)
  cr
  ." Loaded " samples-count @ . ." samples from: "
  source-fname-addr @ source-fname-len @ type
  cr
;
\ ------------------------------------------------------------
\  Utility: read a raw PCM file into a cell array
\ ------------------------------------------------------------
: load-raw ( c-addr u -- addr n )
    { c-addr u -- }
    c-addr u r/o open-file throw { fid }
    fid file-size throw drop 1 invert and { bytes }
    bytes allocate throw { bytebuf }
    bytebuf bytes fid read-file throw drop
    bytes 2/ { nsamples }
    nsamples cells allocate throw { samples }
    bytebuf samples nsamples bytes>cells
    bytebuf free throw
    fid close-file throw
    samples nsamples ;

\ ------------------------------------------------------------
\  Load reference and test buffers
\ ------------------------------------------------------------
REF-FILE load-raw 2constant REF-BUF   \ ( addr n )
TEST-FILE load-raw 2constant TEST-BUF \ ( addr n )

: REF-ADDR ( -- addr ) REF-BUF drop ;
: REF-LEN  ( -- n )    REF-BUF nip ;
: TEST-ADDR ( -- addr ) TEST-BUF drop ;
: TEST-LEN  ( -- n )    TEST-BUF nip ;

\ --------------------------------------------------------------
\ Convenience wrappers for two input files
\ --------------------------------------------------------------
\ ref.raw  : contains the phrase to be identified
\ test.raw : contains the phrase mixed with other content
\ --------------------------------------------------------------

: load-ref  ( -- ref-addr ref-n )
  s" ref.raw" load-pcm ;

: load-test ( -- test-addr test-n )
  s" test.raw" load-pcm ;

: load-rawly ( -- raw-addr raw-n )
  s" test.raw" load-pcm ;

\ --------------------------------------------------------------
\ Sliding‑window detector
\ --------------------------------------------------------------
32 constant MAX-LAG

: detect-command ( -- )
    0 { found }
    REF-ADDR REF-LEN sumsq64 d>s isqrt64 { refnorm }
    TEST-LEN REF-LEN - 0 max          \ number of possible windows
    0 do
        TEST-ADDR i cells +           \ start of window
        REF-ADDR REF-LEN refnorm corr-fixed-window
        dup THRESHOLD-FIXED > if      \ above threshold?
            i REF-LEN + dup
            ." Detected come here at sample "
            . cr                      \ report approximate position
            1 to found
            on-detect
        then
        drop
    loop ;

\ Coarse-to-fine scan to speed up detection
: detect-command-fast ( -- )
    0 { found }
    REF-ADDR REF-LEN sumsq64 d>s isqrt64 { refnorm }
    TEST-LEN REF-LEN - 0 max { maxwin }
    0 maxwin COARSE-STRIDE ?do
        TEST-ADDR i cells + 
        REF-ADDR REF-LEN refnorm corr-fixed-window
        dup COARSE-THRESHOLD-FIXED > if
            \ refine locally around the coarse hit
            i COARSE-STRIDE - 0 max
            i COARSE-STRIDE + maxwin min
            1+ swap do
                TEST-ADDR j cells +
                REF-ADDR REF-LEN refnorm corr-fixed-window
                dup THRESHOLD-FIXED > if
                    j REF-LEN + dup
                    ." Detected come here at sample "
                    . cr
                    1 to found
                    on-detect
                then
                drop
            loop
        then
        drop
    COARSE-STRIDE +loop
    found 0= if ." No match found." cr then ;

\ Run fast detection for explicit files (ref/test), frees buffers after use
: detect-command-fast-files ( ref-addr ref-len test-addr test-len -- )
    { rname rlen tname tlen -- }
    rname rlen load-raw { raddr rcount }
    tname tlen load-raw { taddr tcount }
    0 { found }
    raddr rcount sumsq64 d>s isqrt64 { refnorm }
    tcount rcount - 0 max { maxwin }
    0 maxwin COARSE-STRIDE ?do
        taddr i cells + 
        raddr rcount refnorm corr-fixed-window
        dup COARSE-THRESHOLD-FIXED > if
            i COARSE-STRIDE - 0 max
            i COARSE-STRIDE + maxwin min
            1+ swap do
                taddr j cells +
                raddr rcount refnorm corr-fixed-window
                dup THRESHOLD-FIXED > if
                    j rcount + dup
                    ." Detected come here at sample "
                    . cr
                    1 to found
                    on-detect
                then
                drop
            loop
        then
        drop
    COARSE-STRIDE +loop
    found 0= if ." No match found." cr then
    raddr free throw
    taddr free throw ;

\ Full scan for explicit files (slower than fast scan)
: detect-command-files ( ref-addr ref-len test-addr test-len -- )
    { rname rlen tname tlen -- }
    rname rlen load-raw { raddr rcount }
    tname tlen load-raw { taddr tcount }
    0 { found }
    raddr rcount sumsq64 d>s isqrt64 { refnorm }
    tcount rcount - 0 max { maxwin }
    maxwin 0 do
        taddr i cells +
        raddr rcount refnorm corr-fixed-window
        dup THRESHOLD-FIXED > if
            ." Detected come here at sample "
            i rcount + . cr
            1 to found
        then
        drop
    loop
    found 0= if ." No match found." cr then
    raddr free throw
    taddr free throw ;

: detect-command-fast-test ( -- )
    s" ref_test.raw" s" test_test.raw" detect-command-fast-files ;

\ Helper: show which files the default detectors use
: show-input-files ( -- )
    ." REF-FILE: " REF-FILE type cr
    ." TEST-FILE: " TEST-FILE type cr ;

\ Command-line helpers (expects args after -e)
: ?missing-arg ( c-addr u -- c-addr u missing? )
    2dup 0= swap 0= and ;

: detect-command-fast-args ( -- )
    next-arg ?missing-arg if
        2drop ." Usage: gforth pcm-analyze.f -e 'detect-command-fast-args bye' <ref.raw> <test.raw>" cr
        exit
    then
    next-arg ?missing-arg if
        2drop 2drop ." Usage: gforth pcm-analyze.f -e 'detect-command-fast-args bye' <ref.raw> <test.raw>" cr
        exit
    then
    detect-command-fast-files ;

: detect-command-args ( -- )
    next-arg ?missing-arg if
        2drop ." Usage: gforth pcm-analyze.f -e 'detect-command-args bye' <ref.raw> <test.raw>" cr
        exit
    then
    next-arg ?missing-arg if
        2drop 2drop ." Usage: gforth pcm-analyze.f -e 'detect-command-args bye' <ref.raw> <test.raw>" cr
        exit
    then
    detect-command-files ;
\ 
\ NOTE: The caller owns the returned sample buffers.
\ To free a loaded buffer later, do:
\   <sample-addr> free ?ior
\ (Keep track of each address from load-ref / load-test.)
\ --------------------------------------------------------------
