using System;
using System.Device.Gpio;
using System.Device.Pwm;
using System.Threading;

namespace AnimalsFox.E01
{
    public sealed class RaspberryPiGpio : IDisposable
    {
        private readonly GpioController _gpio;
        private readonly PwmChannel _pwmA;
        private readonly PwmChannel _pwmB;
        private readonly SoftwarePwmLed _ledRed;
        private readonly SoftwarePwmLed _ledYellow;
        private readonly SoftwarePwmLed _ledGreenOrBlue;

        private readonly int _ain1;
        private readonly int _ain2;
        private readonly int _bin1;
        private readonly int _bin2;
        private readonly int _stby;

        public RaspberryPiGpio(
            int ain1,
            int ain2,
            int pwmaChip,
            int pwmaChannel,
            int bin1,
            int bin2,
            int pwmbChip,
            int pwmbChannel,
            int stby,
            int ledRed,
            int ledYellow,
            int ledGreenOrBlue,
            int motorPwmHz = 20000,
            int ledPwmHz = 200)
        {
            _gpio = new GpioController();

            _ain1 = ain1;
            _ain2 = ain2;
            _bin1 = bin1;
            _bin2 = bin2;
            _stby = stby;

            _gpio.OpenPin(_ain1, PinMode.Output);
            _gpio.OpenPin(_ain2, PinMode.Output);
            _gpio.OpenPin(_bin1, PinMode.Output);
            _gpio.OpenPin(_bin2, PinMode.Output);
            _gpio.OpenPin(_stby, PinMode.Output);
            _gpio.Write(_stby, PinValue.High);

            _pwmA = PwmChannel.Create(pwmaChip, pwmaChannel, motorPwmHz, 0.0);
            _pwmB = PwmChannel.Create(pwmbChip, pwmbChannel, motorPwmHz, 0.0);
            _pwmA.Start();
            _pwmB.Start();

            _ledRed = new SoftwarePwmLed(_gpio, ledRed, ledPwmHz);
            _ledYellow = new SoftwarePwmLed(_gpio, ledYellow, ledPwmHz);
            _ledGreenOrBlue = new SoftwarePwmLed(_gpio, ledGreenOrBlue, ledPwmHz);
        }

        public void MotorForward(int speed)
        {
            SetMotor(_pwmA, _ain1, _ain2, speed, forward: true);
            SetMotor(_pwmB, _bin1, _bin2, speed, forward: true);
        }

        public void MotorBackwards(int speed)
        {
            SetMotor(_pwmA, _ain1, _ain2, speed, forward: false);
            SetMotor(_pwmB, _bin1, _bin2, speed, forward: false);
        }

        public void MotorLeft(int speed)
        {
            SetMotor(_pwmA, _ain1, _ain2, speed, forward: false);
            SetMotor(_pwmB, _bin1, _bin2, speed, forward: true);
        }

        public void MotorRight(int speed)
        {
            SetMotor(_pwmA, _ain1, _ain2, speed, forward: true);
            SetMotor(_pwmB, _bin1, _bin2, speed, forward: false);
        }

        public void MotorStop()
        {
            _pwmA.DutyCycle = 0.0;
            _pwmB.DutyCycle = 0.0;
        }

        public void SetLedRed(double duty)
        {
            _ledRed.SetDuty(duty);
        }

        public void SetLedYellow(double duty)
        {
            _ledYellow.SetDuty(duty);
        }

        public void SetLedGreenOrBlue(double duty)
        {
            _ledGreenOrBlue.SetDuty(duty);
        }

        public void AllLedsOff()
        {
            _ledRed.SetDuty(0.0);
            _ledYellow.SetDuty(0.0);
            _ledGreenOrBlue.SetDuty(0.0);
        }

        private void SetMotor(PwmChannel pwm, int in1, int in2, int speed, bool forward)
        {
            double duty = Math.Clamp(speed, 0, 100) / 100.0;
            _gpio.Write(in1, forward ? PinValue.High : PinValue.Low);
            _gpio.Write(in2, forward ? PinValue.Low : PinValue.High);
            pwm.DutyCycle = duty;
        }

        public void Dispose()
        {
            _ledRed.Dispose();
            _ledYellow.Dispose();
            _ledGreenOrBlue.Dispose();
            _pwmA.Dispose();
            _pwmB.Dispose();

            _gpio.Write(_stby, PinValue.Low);
            _gpio.ClosePin(_ain1);
            _gpio.ClosePin(_ain2);
            _gpio.ClosePin(_bin1);
            _gpio.ClosePin(_bin2);
            _gpio.ClosePin(_stby);
            _gpio.Dispose();
        }

        private sealed class SoftwarePwmLed : IDisposable
        {
            private readonly GpioController _gpio;
            private readonly int _pin;
            private readonly int _periodMs;
            private readonly Timer _timer;
            private volatile int _onMs;
            private volatile int _offMs;

            public SoftwarePwmLed(GpioController gpio, int pin, int frequencyHz)
            {
                _gpio = gpio;
                _pin = pin;
                _periodMs = Math.Max(1, 1000 / Math.Max(1, frequencyHz));
                _gpio.OpenPin(_pin, PinMode.Output);
                _gpio.Write(_pin, PinValue.Low);

                _onMs = 0;
                _offMs = _periodMs;
                _timer = new Timer(Tick, null, 0, Timeout.Infinite);
            }

            public void SetDuty(double duty)
            {
                double clamped = Math.Clamp(duty, 0.0, 1.0);
                int on = (int)Math.Round(_periodMs * clamped);
                _onMs = on;
                _offMs = Math.Max(0, _periodMs - on);
                if (_periodMs == 0)
                {
                    _gpio.Write(_pin, PinValue.Low);
                }
            }

            private void Tick(object state)
            {
                if (_onMs > 0)
                {
                    _gpio.Write(_pin, PinValue.High);
                    _timer.Change(_onMs, Timeout.Infinite);
                    _onMs = -_onMs;
                }
                else
                {
                    _gpio.Write(_pin, PinValue.Low);
                    _timer.Change(_offMs, Timeout.Infinite);
                    _onMs = Math.Abs(_onMs);
                }
            }

            public void Dispose()
            {
                _timer.Dispose();
                _gpio.Write(_pin, PinValue.Low);
                _gpio.ClosePin(_pin);
            }
        }
    }
}
