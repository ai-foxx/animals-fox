\ =====================================================================
\  Behaviour Routine: Execute one of a number of possible animations.
\   Make the code such that each component is demarcated as a 'module' that can be interchanged.
\  --------------------------------------------------------------------
\ The choices are:
\ ---------------------------------------------
\ Indicate Mood Interaction
\ if (happy)    - spin clockwise +1 rotation [ 1-motor CW; 2-motor CCW ] | How to determine that enough rot for returning to facing the user?
\ if (pensive)  - move (forward) +1 rot, move (backward) -1 rot
\ if (...)
\ else          - spin counterclockwise  -1 rotation [ 1-motor CCW; 2-motor CW ] | Same concern here as the one above.

\ Dance
\  Sounds and movements
\   -   mixture of move and spin
\   -   lights and sounds

\ Acknowledge
\  Sounds
\   - tonal language

\ =====================================================================
\ Friendly arrival animation (motor + LED)
\ =====================================================================

decimal

\ -------------------  HARDWARE HOOKS  ------------------------
\ These should be bound to real motor/LED control words elsewhere.
defer motor-forward   ( speed -- )
defer motor-backwards ( speed -- )
defer motor-left      ( speed -- )
defer motor-right     ( speed -- )
defer motor-stop      ( -- )

defer led-set         ( r g b -- )
defer led-off         ( -- )

:noname drop ; is motor-forward
:noname drop ; is motor-backwards
:noname drop ; is motor-left
:noname drop ; is motor-right
:noname ; is motor-stop

:noname drop drop drop ; is led-set
:noname ; is led-off

\ -------------------  TIMING  -------------------------------
50  constant BLINK-MS
250 constant STEP-MS

\ -------------------  LED ANIMS  -----------------------------
: led-pulse ( r g b -- )
  3dup led-set  BLINK-MS ms
  led-off       BLINK-MS ms ;

: led-smile ( -- )
  0 80 20 led-pulse
  0 80 20 led-pulse
  0 20 80 led-pulse ;

\ -------------------  MOTOR ANIMS  ---------------------------
: motor-wiggle ( -- )
  40 motor-left  STEP-MS ms
  40 motor-right STEP-MS ms
  motor-stop ;

: motor-nod ( -- )
  40 motor-forward  STEP-MS ms
  40 motor-backwards STEP-MS ms
  motor-stop ;

\ -------------------  FRIENDLY ANIMATION  --------------------
: friendly-animation ( -- )
  led-smile
  motor-wiggle
  led-smile
  motor-nod ;

\ Entry point when the robot has arrived successfully
: on-arrival-friendly ( -- )
  friendly-animation
  await-vocal-feedback ;

\ Wire arrival hook from B-01 (expects move-toward.f to be loaded first)
' on-arrival-friendly is on-arrival
