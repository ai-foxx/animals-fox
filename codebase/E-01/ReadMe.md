# AnimalsFox E-01 .NET Runner

This folder contains the .NET (C#) translation of the A-01 through D-01 Forth behavior modules and a small console runner.

## What the code does

The runner wires together the translated components in `codebase/E-01`:

- `PcmAnalyze`: loads 16-bit little-endian mono PCM `.raw` files and performs fixed-point correlation to detect a reference phrase in a test buffer.
- `MoveToward`: uses left/right mic buffers to estimate time-delay-of-arrival (TDOA) via cross-correlation and steers toward the sound.
- `ExecuteAnimation`: plays a friendly motor + LED animation and then waits for vocal feedback.
- `AwaitVocalFeedback`: polls for phrase or loudness detection and triggers success/failure callbacks.

Default wiring:

`PcmAnalyze.OnDetect` → `MoveToward.OnDetectMove` → `ExecuteAnimation.OnArrivalFriendly` → `AwaitVocalFeedback.Await()`

Motor/LED hooks and audio detection hooks are stubs (console output by default); real hardware integration should bind these.

## Test files

Sample PCM files are in `tests/`:

- `tests/ref.raw`: reference phrase template
- `tests/test.raw`: mixed audio containing the phrase
- `tests/left.raw`: left mic channel for direction estimation
- `tests/right.raw`: right mic channel for direction estimation

## Running the .NET version

From the repo root:

```bash
dotnet run --project codebase/E-01 -- --once
```

## GPIO hookup

See `codebase/E-01/GPIO-SETUP.md` for the recommended Raspberry Pi 4B + TB6612FNG wiring.

### Optional flags

- `--once`: stop after the first detection (prevents repeated detections)
- `--simulate-vocal`: simulate vocal success after 500ms (only when provided)
- `--gpio`: use Raspberry Pi GPIO/PWM instead of console stubs

Example:

```bash
dotnet run --project codebase/E-01 -- --once --simulate-vocal
```

### Custom input files

```bash
dotnet run --project codebase/E-01 -- --once <ref.raw> <test.raw> [left.raw] [right.raw]
```

If no paths are provided, defaults are `tests/ref.raw`, `tests/test.raw`, `tests/left.raw`, `tests/right.raw`.

### GPIO mode (Raspberry Pi)

Use `--gpio` to enable the real GPIO/PWM implementation. Without it, the runner prints to console only.

```bash
dotnet run --project codebase/E-01 -- --once --gpio
```

You can combine it with other flags:

```bash
dotnet run --project codebase/E-01 -- --once --simulate-vocal --gpio
```
