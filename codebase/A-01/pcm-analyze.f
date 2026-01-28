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

\ Unsigned 64‑bit multiply (low part only – sufficient here)
: umul64 ( u1 u2 -- ud )  >r >r  r@ r@ *  r> r> 2drop ;
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

\ Integer square root (Newton method)
: sqrt ( ud -- u )
    dup 0= if drop 0 exit then
    1 swap 2/ 1+                     \ initial guess
    begin
        dup 2/ over + 2/
        2dup >r >r
        over over >
    while
        r> drop
    repeat
    r> drop ;
\ Dot product of two integer vectors → 64‑bit result (hi lo)
: dot64 ( a-addr b-addr n -- ud )
    0 0 0 do
        dup i cells + @               \ a[i]
        swap i cells + @              \ b[i]
        m*                     \ 32×32 → 64‑bit (hi lo)
        rot rot + >r >r                \ add low parts, carry high parts
        r> r> + >r >r
    loop
    r> r> ;

\ Sum of squares → 64‑bit result (hi lo)
: sumsq64 ( a-addr n -- ud )
    0 0 0 do
        dup i cells + @               \ x
        dup *                         \ x*x
        >r >r                         \ add low part, carry high part
        r> r> + >r >r
    loop
    r> r> ;
\ ------------------------------------------------------------
\  Normalised cross‑correlation for two equal‑length vectors
\ ------------------------------------------------------------
: dot-product ( a-addr b-addr n -- d )
    0.0e0 0 do
        dup i cells + @               \ a[i]
        swap i cells + @ * f+          \ accumulate a[i]*b[i]
    loop nip nip f> ;  

: vec-norm ( a-addr n -- r )
    0.0e0 0 do
        dup i cells + @ dup * f+      \ sum of squares
    loop nip sqrt ;                   \ sqrt(sum(x^2))

\ Normalised correlation in fixed‑point
: correlation-fixed ( a-addr b-addr n -- corr )
    >r >r >r                         \ keep lengths on return stack
    r@ r@ r@ dot64                    \ numerator (hi lo)
    r@ sumsq64 r@ sumsq64             \ denom_a , denom_b
    sqrt swap sqrt                  \ sqrt_a sqrt_b
    umul64                            \ denominator (hi lo)

    \ Shift numerator left by FRAC_BITS (14) to restore fraction
    2dup 0= if drop drop 0 exit then
    2dup 14 lshift swap 64 14 - rshift or >r   \ new_hi
    2dup 14 lshift >r                         \ new_lo

    \ 128‑by‑64 division: (new_hi new_lo) / den
    r> r> 0
    2 0 do
        2over 2over 2>r >r >r
        2over 2over 2>r >r
        2dup 2>r >r
        2over 2over u>= if
            2over 2over u- swap u- swap
            1 swap lshift or
        then
        2drop 2drop
    loop
    r> r> drop drop ;               \ final quotient (fits 64‑bits)

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
    r/o open-file throw               \ open for reading
    dup file-size                     \ total bytes in file
    2/ 2/ 2/                         \ convert bytes → number of 16‑bit samples
    dup cells allocate throw           \ allocate space for samples (cells = 32‑bit)
    dup >r                            \ keep address on stack
    0 do                              \ read sample by sample
        dup i cells +                \ address of ith cell
        2 pick read-file throw       \ read 2 bytes
        dup 0= if leave then
        dup c@ 256 * swap 1+ c@ +    \ combine low/high bytes (little‑endian)
        dup 32768 -                  \ signed conversion
        swap !                       \ store as 32‑bit integer
    loop
    r> swap                          \ (addr n)
    r> close-file throw ;

\ ------------------------------------------------------------
\  Load reference and test buffers
\ ------------------------------------------------------------
REF-FILE load-raw constant REF-ADDR   \ address of reference samples
REF-ADDR swap constant REF-LEN        \ number of samples in reference

TEST-FILE load-raw constant TEST-ADDR \ address of test samples
TEST-ADDR swap constant TEST-LEN      \ number of samples in test file

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
        TEST-ADDR i +                 \ start of window
        REF-ADDR REF-LEN correlation-fixed   \ compute correlation
        dup THRESHOLD f> if           \ above threshold?
            ." 👣 Detected \"come here\" at sample "
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