## DF Robot motors for the robot

Both platforms use the DFRobot [FIT0450](https://wiki.dfrobot.com/Micro_DC_Motor_with_Encoder-SJ01_SKU__FIT0450) Micro DC geared motor with encoder. It is a motor with a `120:1` gearbox and an integrated quadrature encoder that provides a resolution of 8 pulse single per round giving a maximum output of 960 within one round. Applications for this might include a closed-loop PID control or PWM motor speed control. This motor is an ideal option for mobile robot projects. The copper output shaft, embedded thread and reinforced connector greatly extends the motor's service life.

_Specification_

* Gear ratio: 120:1
* No-load speed @ 6V: 160 rpm
* No-load speed @ 3V: 60 rpm
* No-load current @ 6V: 0.17A
* No-load current @ 3V: 0.14A
* Max Stall current: 2.8A
* Max Stall torque: 0.8kgf.cm
* Rated torque: 0.2kgf.cm
* Encoder operating voltage: 4.5~7.5V
* Motor operating voltage: 3~7.5V (Rated voltage 6V)
* Operating ambient temperature: -10 ~ +60℃

_Pinout_

![pinout](/datasheets/motor-encoder/FIT0450.png)

| Pin   | Name                     | Functional Description                                                       |
|-------|--------------------------|------------------------------------------------------------------------------|
| 1     | Motor power supply pin + | 3-7.5V，Rated voltage 6V                                                      |
| 2     | Motor power supply pin - |                                                                              |
| 3     | Encoder A phase output   | Changes square wave with the output frequency of Motor speed                 |
| 4     | Encoder B phase output   | Changes square wave with the output frequency of Motor speed(interrupt port) |
| 5     | Encoder supply GND       |                                                                              |
| 6     | Encoder supply +         | 4.5-7.5V                                                                     |

_Physical specs_

| General                                     |                          | Functional Description                                                       |
|---------------------------------------------|--------------------------|------------------------------------------------------------------------------|
| Brand                                       | DFRobot                  | 3-7.5V，Rated voltage 6V                                                      |
| Manufacturer model/SKU                      | FIT0450                  |                                                                              |
| Minimum operating temperature [°C]          | -10                      | Changes square wave with the output frequency of Motor speed                 |
| Maximum operating temperature [°C]          | 60                       | Changes square wave with the output frequency of Motor speed(interrupt port) |
| Features                                    | Motor Rotary encoder     |                                                                              |
| General physical appearance                 |                          | 4.5-7.5V                                                                     |
| Main color                                  | Yellow                   |                                                                              |
| Weight [g]                                  | 41                       |                                                                              |
| Dimension X [mm]                            | 71                       |                                                                              |
| Dimension Y [mm]                            | 45                       |                                                                              |
| Dimension Z [mm]                            | 30                       |                                                                              |
| Mounting options                            | Mounting hole(s)         |                                                                              |
| Diameter mounting hole(s) [mm]              | 3                        |                                                                              |
| Form factor                                 | Module (general)         |                                                                              |
| General electrical properties               |                          |                                                                              |
| Minimum supply voltage [V DC]               | 4.5                      |                                                                              |
| Maximum supply voltage [V DC]               | 7.5                      |                                                                              |
| Minimum recommended supply current [A]      | 2.8 (stall current @6V)  |                                                                              |
| Indication average current consumption [mA] | 170 (@6V, no load)       |                                                                              |
| Minimum IO-pin input voltage [V]            | 4.5                      |                                                                              |
| Maximum IO-pin input voltage [V]            | 7.5                      |                                                                              |
| IO-pin output voltage [V]                   | Equal to supply voltage  |                                                                              |
| Communication                               |                          |                                                                              |
| Hardware interface(s)                       | PWM                      |                                                                              |
| Rotary encoder                              |                          |                                                                              |
| Encoder type                                | Incremental              |                                                                              |
| Encoder technology                          | Hall effect              |                                                                              |
| Motor driver                                |                          |                                                                              |
| Minimum motor supply voltage [V DC]         | 3                        |                                                                              |
| Maximum motor supply voltage [V DC]         | 7.5                      |                                                                              |
| Actuator                                    |                          |                                                                              |
| Actuator type                               | Brushed DC motor         |                                                                              |
| Maximum holding torque [N.m]                | 0.08                     |                                                                              |
| Maximum speed [RPM]                         | 160 (@6V)                |                                                                              |
| Transmission                                | 120:1                    |                                                                              |
| Gear material                               | Plastic                  |                                                                              |
| Connectors                                  |                          |                                                                              |
| Power supply connector(s)                   | JST-PH (compatible) male |                                                                              |
| IO-connector(s)                             | JST-PH (compatible) male |                                                                              |
| Motor connector(s)                          | JST-PH (compatible) male |                                                                              |

## Using G3VM-61BR2 for Driverless Motor Control
```
   1.8V Source
       |
       R1 (68 Ω)
       |
     -----LED (Input)
     |          
     |          GND
     |
     |  Phototransistor
     |     (Output)
     |
     +---|-----|--- Base of NPN Transistor
     |   |     |
     |   Rb    |
    6.4V   Motor
     |       |
     |       | 
     +-------+----+
     |  Flyback Diode|
     +----------------+
```

## Current Draw Above 50mA

If the current draw of your motor exceeds **50 mA**, you'll need to incorporate additional components to ensure safe and effective operation. Here are some options:

## Using a Transistor or Relay

### 1. Transistor as a Switch

You can use an external transistor to switch the motor on and off. This way, the phototransistor in the **G3VM-61BR2** only needs to drive the base of the external transistor.

#### Circuit Design

- **Components Needed:**
  - NPN Transistor (e.g., **2N2222**, **TIP120**)
  - Flyback Diode (for motor protection, e.g., **1N4007**)
  - Resistor for the base of the transistor (Rb)

#### Schematic Overview

1. **Input Circuit:**
   - Connect the input side of the opto-isolator as before.

2. **Output Circuit:**
   - Connect the collector of the phototransistor to the base of the NPN transistor through the base resistor (Rb).
   - Connect the emitter of the NPN transistor to ground.
   - Connect the motor and a flyback diode in series with the power supply to the collector of the NPN transistor.

#### Example Calculation for Base Resistor (Rb)

If you use a transistor with a current gain of 100 (common for small NPN transistors), and your motor draws **200 mA**:
- Current through the base (Ib) must be:
  \[
  Ib = \frac{Ic}{\text{hFE}} = \frac{200 \text{ mA}}{100} = 2 \text{ mA}
  \]
- Voltage across the base resistor (assuming the base-emitter voltage drop (Vbe) is about 0.7 V):
  \[
  Rb = \frac{V_{source} - V_{be}}{Ib} = \frac{1.8 - 0.7}{0.002} = 550 \, \Omega
  \]
- Use a standard resistor value of **560 Ω**.

### 2. Using a Relay

If the current draw is significantly higher, or if isolation is critical, consider using a relay:

#### Circuit Design

1. **Input Circuit:**
   - Connect the opto-isolator as before.

2. **Relay Control:**
   - Use a relay with a coil rating compatible with the output from the opto-isolator to switch on the motor.
   - Connect the relay contacts in series with the motor and the power supply.

3. **Flyback Diode:**
   - Place a flyback diode across the relay coil to protect against voltage spikes.

### Schematic Representation

In both cases, the schematic will look similar to the earlier designs but with a transistor or relay included to handle the higher current.

## Summary

- If your motor's current draw exceeds **50 mA**, using an external transistor or relay allows you to control larger loads safely.
- Always include protection diodes for inductive loads to safeguard your components.
