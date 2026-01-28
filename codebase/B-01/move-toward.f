\ =============================================================
\  Behaviour Routine: Move toward where a sound was detected
\  ------------------------------------------------------------
\  Uses two mono mic files (left/right) to estimate direction.
\  Expects pcm-analyze.f to be loaded (for load-raw, REF-LEN, etc).
\ =============================================================

decimal

\ -------------------  USER SETTINGS  -------------------------
s" left.raw"  2constant LEFT-FILE
s" right.raw" 2constant RIGHT-FILE

32 constant MAX-LAG          \ +/- samples to search for TDOA
100 constant MAX-SPEED       \ speed scale 0..100

\ -------------------  MOTOR HOOKS  ---------------------------
\ TB6612FNG control via GPIO/PWM (pins TBD on real board)
\ Pins to fill in:
\   AIN1: ___  AIN2: ___  PWMA: ___
\   BIN1: ___  BIN2: ___  PWMB: ___
\   STBY: ___
\ Override these in your hardware layer.
defer motor-forward   ( speed -- )
defer motor-backwards ( speed -- )
defer motor-left      ( speed -- )
defer motor-right     ( speed -- )

:noname drop ; is motor-forward
:noname drop ; is motor-backwards
:noname drop ; is motor-left
:noname drop ; is motor-right

\ -------------------  FLOW HOOKS  ----------------------------
\ Called when a move-toward action completes.
defer on-arrival   ( -- )
:noname ; is on-arrival

\ -------------------  MATH HELPERS  --------------------------
: dabs ( d -- ud )
  2dup d0< if dnegate then ;

: d0! ( addr -- )  0 0 rot 2! ;
: d+! ( ud addr -- )  >r r@ 2@ d+ r> 2! ;

\ Cross-correlation between two windows with a lag (signed)
2variable corr-acc
: corr-lag ( left-addr right-addr n lag -- d )
  { l r n lag -- }
  corr-acc d0!
  lag 0>= if
    n lag - 0 max { m }
    m 0 do
      l lag cells + i cells + @
      r i cells + @
      m* corr-acc d+!
    loop
  else
    n lag + 0 max { m }
    m 0 do
      l i cells + @
      r lag negate cells + i cells + @
      m* corr-acc d+!
    loop
  then
  corr-acc 2@ ;

\ Estimate lag that maximizes absolute correlation
2variable best-val
: estimate-lag ( left-addr right-addr n max-lag -- lag )
  { l r n maxlag -- }
  0 { bestlag }
  0 0 best-val 2!
  maxlag negate maxlag 1+ do
    l r n i corr-lag dabs
    2dup best-val 2@ d> if
      best-val 2!
      i to bestlag
    else
      2drop
    then
  loop
  bestlag ;

\ Map lag to continuous steering
: steer-toward ( lag -- )
  dup abs MAX-LAG min           \ magnitude
  dup 0= if drop MAX-SPEED motor-forward exit then
  MAX-SPEED swap MAX-LAG */     \ scale speed
  swap 0< if motor-left else motor-right then ;

\ -------------------  DETECTION HANDLER  ---------------------
\ Called by pcm-analyze on detection: ( sample-idx -- )
: on-detect-move ( sample-idx -- )
  { idx -- }
  LEFT-FILE load-raw { laddr lcount }
  RIGHT-FILE load-raw { raddr rcount }
  lcount rcount min { tcount }
  idx REF-LEN - 0 max { start }
  start REF-LEN + tcount min { end }
  end start - { win }
  win 0> if
    laddr start cells + 
    raddr start cells + 
    win MAX-LAG estimate-lag
    steer-toward
  then
  laddr free throw
  raddr free throw
  on-arrival ;

' on-detect-move is on-detect
