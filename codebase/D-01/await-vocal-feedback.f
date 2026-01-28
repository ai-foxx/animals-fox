\ ==================================================================
\  Behaviour Routine: Await vocal feedback from sequence 'C'
\  -----------------------------------------------------------------
\  Accepts either a specific phrase or any loud vocal response.
\ ==================================================================

decimal

\ -------------------  DETECTOR HOOKS  -------------------------
\ Override these with real audio analysis.
\ TODO: wire real phrase detector here.
defer phrase-detected?   ( -- flag )  \ e.g., "yes", "ok", "good"
\ TODO: wire real loudness detector here.
defer loudness-detected? ( -- flag )  \ any vocal response over threshold

:noname 0 ; is phrase-detected?
:noname 0 ; is loudness-detected?

\ -------------------  RESULT HOOKS  ---------------------------
defer on-vocal-success   ( -- )
defer on-vocal-failure   ( -- )

:noname ; is on-vocal-success
:noname ; is on-vocal-failure

\ -------------------  ENTRY POINT  ---------------------------
\ Polls for feedback for a fixed duration, then reports success/failure.
3000 constant FEEDBACK-WAIT-MS
100  constant FEEDBACK-POLL-MS

: await-vocal-feedback ( -- )
  0 { elapsed }
  begin
    phrase-detected? if on-vocal-success exit then
    loudness-detected? if on-vocal-success exit then
    FEEDBACK-POLL-MS ms
    elapsed FEEDBACK-POLL-MS + to elapsed
    elapsed FEEDBACK-WAIT-MS >=
  until
  on-vocal-failure ;
