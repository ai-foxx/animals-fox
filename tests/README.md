# AnimalsFox A-01 to D-01 Forth Flow

This folder documents how the original Forth modules (A-01 through D-01) work together. The Forth sources live in:

- `codebase/A-01/pcm-analyze.f`
- `codebase/B-01/move-toward.f`
- `codebase/C-01/execute-animation.f`
- `codebase/D-01/await-vocal-feedback.f`

## What the Forth code does

The core runtime flow is:

`on-detect` → `on-detect-move` → `on-arrival-friendly` → `await-vocal-feedback`

Module responsibilities:

- `pcm-analyze.f`: loads 16-bit little-endian mono PCM `.raw` files and performs fixed-point normalized correlation to detect a reference phrase inside a test buffer.
- `move-toward.f`: uses left/right mic buffers to estimate time-delay-of-arrival (TDOA) via cross-correlation and steers toward the sound.
- `execute-animation.f`: plays a friendly motor + LED animation and then waits for vocal feedback.
- `await-vocal-feedback.f`: polls for a detected phrase or loudness, then calls success/failure hooks (default: unlock detection).

Motor/LED hooks and audio detection hooks are deferred words; real hardware integration should bind these.

## Test files

Sample PCM files are in `tests/`:

- `tests/ref.raw`: reference phrase template
- `tests/test.raw`: mixed audio containing the phrase
- `tests/left.raw`: left mic channel for direction estimation
- `tests/right.raw`: right mic channel for direction estimation

## Running the Forth version

From the repo root, run with Gforth:

```bash
gforth codebase/A-01/pcm-analyze.f \\
  codebase/B-01/move-toward.f \\
  codebase/C-01/execute-animation.f \\
  codebase/D-01/await-vocal-feedback.f \\
  -e 'detect-command-fast bye'
```

### Custom input files

To specify custom reference and test files, use the argument-based helpers:

```bash
gforth codebase/A-01/pcm-analyze.f \\
  -e 'detect-command-fast-args bye' <ref.raw> <test.raw>
```

### Notes

- The Forth code expects 16-bit little-endian mono PCM files.
- `on-detect` is overridden by `move-toward.f`, and `on-arrival` is overridden by `execute-animation.f`.
- `await-vocal-feedback` defaults to unlock detection on success/failure; real detectors should replace the deferred hooks.
