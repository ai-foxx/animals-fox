using System;
using System.Threading;

namespace AnimalsFox.E01
{
    public sealed class ExecuteAnimation
    {
        // Motor hooks: bind these to your GPIO/PWM layer (e.g., TB6612FNG).
        public Action<int> MotorForward { get; set; } = _ => { };
        public Action<int> MotorBackwards { get; set; } = _ => { };
        public Action<int> MotorLeft { get; set; } = _ => { };
        public Action<int> MotorRight { get; set; } = _ => { };
        public Action MotorStop { get; set; } = () => { };

        // LED hooks: bind these to your LED GPIO/driver as needed.
        public Action<int, int, int> LedSet { get; set; } = (_, __, ___) => { };
        public Action LedOff { get; set; } = () => { };

        public const int BlinkMs = 50;
        public const int StepMs = 250;

        public AwaitVocalFeedback AwaitVocalFeedback { get; set; } = new AwaitVocalFeedback();

        private void LedPulse(int r, int g, int b)
        {
            LedSet(r, g, b);
            Thread.Sleep(BlinkMs);
            LedOff();
            Thread.Sleep(BlinkMs);
        }

        private void LedSmile()
        {
            LedPulse(0, 80, 20);
            LedPulse(0, 80, 20);
            LedPulse(0, 20, 80);
        }

        private void MotorWiggle()
        {
            MotorLeft(40);
            Thread.Sleep(StepMs);
            MotorRight(40);
            Thread.Sleep(StepMs);
            MotorStop();
        }

        private void MotorNod()
        {
            MotorForward(40);
            Thread.Sleep(StepMs);
            MotorBackwards(40);
            Thread.Sleep(StepMs);
            MotorStop();
        }

        public void FriendlyAnimation()
        {
            LedSmile();
            MotorWiggle();
            LedSmile();
            MotorNod();
        }

        public void OnArrivalFriendly()
        {
            FriendlyAnimation();
            AwaitVocalFeedback.Await();
        }
    }
}
