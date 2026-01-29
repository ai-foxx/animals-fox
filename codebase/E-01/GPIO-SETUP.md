# Raspberry Pi 4B + TB6612FNG (SparkFun) Wiring Guide

This document describes the recommended GPIO (BCM) pin mapping for the .NET (E-01) implementation.

## Motor driver (TB6612FNG)

Recommended mapping (hardware PWM for both motors):

- PWMA → BCM18 (GPIO18, HW PWM0)
- PWMB → BCM19 (GPIO19, HW PWM1)
- AIN1 → BCM5 (GPIO5)
- AIN2 → BCM6 (GPIO6)
- BIN1 → BCM23 (GPIO23)
- BIN2 → BCM24 (GPIO24)
- STBY → BCM25 (GPIO25)

Notes:
- Use hardware PWM on BCM18/BCM19 for smoother motor speed control.
- Avoid using BCM2/BCM3 (I2C), BCM14/BCM15 (UART), and BCM7–11 (SPI) unless you need those buses.

## LED actions (3 single-color LEDs with dimming)

You mentioned three separate LEDs (red, yellow, green or blue) and optional dimming. Use software PWM for LEDs and keep motor PWM on hardware outputs:

- RED → BCM12
- YELLOW → BCM13
- GREEN or BLUE → BCM16

Notes:
- Software PWM is sufficient for LED dimming and preserves both hardware PWM channels for motors.
- If you prefer blue instead of green, just wire the blue LED to BCM16.

## Power and grounding

- VM (motor power): connect to your motor power supply voltage.
- VCC (logic power): connect to 3.3V (Pi logic) per the TB6612FNG breakout requirements.
- GND: common ground between Raspberry Pi and motor supply.

## Code touchpoints

Fill the placeholders in `codebase/E-01/Program.cs` with your chosen BCM pins and bind the hooks:

- Motor hooks: `MoveToward.MotorForward/Backwards/Left/Right`
- LED hooks: `ExecuteAnimation.LedSet/LedOff`

The default implementation prints to console; you’ll replace those with GPIO/PWM calls.
