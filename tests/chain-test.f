\ =============================================================
\  Chain Test: A-01 -> B-01 -> C-01 -> D-01
\  Minimal smoke test with synthetic PCM files in tests/.
\ =============================================================

decimal

\ Run from tests/ so test PCM files resolve correctly.
\ Load modules in order
include ../codebase/A-01/pcm-analyze.f
include ../codebase/B-01/move-toward.f
include ../codebase/D-01/await-vocal-feedback.f
include ../codebase/C-01/execute-animation.f

\ Speed up tests
: ms ( u -- ) drop ;

\ Use test files for left/right mic inputs
s" left.raw"  2constant LEFT-FILE
s" right.raw" 2constant RIGHT-FILE

\ Simplified on-detect for smoke test (avoid full lag estimation)
variable detected-once
:noname ( sample-idx -- )
  drop
  detected-once @ if exit then
  1 detected-once !
  50 motor-forward
  on-arrival ;
is on-detect

\ Minimal mocks (prints only)
:noname ( speed -- ) drop ." motor-forward" cr ; is motor-forward
:noname ( speed -- ) drop ." motor-backwards" cr ; is motor-backwards
:noname ( speed -- ) drop ." motor-left" cr ; is motor-left
:noname ( speed -- ) drop ." motor-right" cr ; is motor-right
:noname ( -- ) ." motor-stop" cr ; is motor-stop

:noname ( r g b -- ) 2drop drop ." led-set" cr ; is led-set
:noname ( -- ) ." led-off" cr ; is led-off

:noname ( -- flag ) -1 ; is phrase-detected?
:noname ( -- flag ) 0 ; is loudness-detected?

:noname ( -- ) ." vocal-success" cr ; is on-vocal-success
:noname ( -- ) ." vocal-failure" cr ; is on-vocal-failure

\ -------------------  RUN  -----------------------------------
s" ref.raw" s" test.raw" detect-command-fast-files

bye
