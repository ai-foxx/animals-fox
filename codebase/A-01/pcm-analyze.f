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

s" ref.raw"   2constant REF-FILE     \ reference template (come here)
s" test.raw"  2constant TEST-FILE    \ file you want to scan

\ Fixed‑point parameters
14 constant FRAC-BITS               \ 14 fractional bits → 2¹⁴ = 16384
1 FRAC-BITS lshift constant SCALE     \ SCALE = 1 << FRAC-BITS (16384)

\ Scaled detection threshold (0.80 → 0.80 * SCALE)
\ 0.80e0 FRAC-BITS lshift f>s constant THRESHOLD-FIXED
\ 0.80e0 SCALE s>f f* f>s constant THRESHOLD-FIXED
13107 constant THRESHOLD-FIXED   \ 0.80 * SCALE rounded

cr ." FRAC-BITS = " FRAC-BITS . cr
cr ." SCALE     = " SCALE . cr
cr ." THRESHOLD-FIXED (fixed-point) = " THRESHOLD-FIXED . cr

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

\ Normalised correlation in fixed‑point
: correlation-fixed ( a-addr b-addr n -- corr )
    { a b n -- }
    a b n dot64                       \ numerator (signed d)
    a n sumsq64 d>s isqrt64           \ denom_a (u)
    b n sumsq64 d>s isqrt64           \ denom_b (u)
    umul64 d>s { denom }              \ denom (u)
    denom 0= if 2drop 0 exit then
    2dup d0< if dnegate -1 else 0 then { sign }  \ save sign, make numerator positive
    FRAC-BITS d<<                     \ scale numerator
    denom um/mod nip                  \ unsigned quotient
    sign 0< if negate then ;          \ apply sign

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
: detect-command ( -- )
    TEST-LEN REF-LEN - 0 max          \ number of possible windows
    0 do
        TEST-ADDR i cells +           \ start of window
        REF-ADDR REF-LEN correlation-fixed   \ compute correlation
        dup THRESHOLD-FIXED > if      \ above threshold?
            ." Detected come here at sample "
            i REF-LEN + . cr          \ report approximate position
        then
        drop
    loop ;
\ 
\ NOTE: The caller owns the returned sample buffers.
\ To free a loaded buffer later, do:
\   <sample-addr> free ?ior
\ (Keep track of each address from load-ref / load-test.)
\ --------------------------------------------------------------
