using System;
using System.IO;

namespace AnimalsFox.E01
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            // GPIO wiring notes (Raspberry Pi 4B + TB6612FNG SparkFun breakout):
            // - Required signals: AIN1, AIN2, PWMA, BIN1, BIN2, PWMB, STBY.
            // - PWM channels map to Pi hardware PWM (BCM18 -> PWM0, BCM19 -> PWM1).
            // - LEDs: three single-color LEDs (red, yellow, green/blue) with software PWM dimming.
            // - ExecuteAnimation.LedSet maps (r,g,b) => (red,yellow,green-or-blue).
            const int AIN1 = 5;
            const int AIN2 = 6;
            const int BIN1 = 23;
            const int BIN2 = 24;
            const int STBY = 25;
            const int LED_RED = 12;
            const int LED_YELLOW = 13;
            const int LED_GREEN_OR_BLUE = 16;

            const int PWMA_CHIP = 0;
            const int PWMA_CHANNEL = 0; // BCM18
            const int PWMB_CHIP = 0;
            const int PWMB_CHANNEL = 1; // BCM19

            bool runOnce = false;
            bool simulateVocal = false;
            bool useGpio = false;
            foreach (string arg in args)
            {
                if (string.Equals(arg, "--once", StringComparison.OrdinalIgnoreCase))
                {
                    runOnce = true;
                }
                if (string.Equals(arg, "--simulate-vocal", StringComparison.OrdinalIgnoreCase))
                {
                    simulateVocal = true;
                }
                if (string.Equals(arg, "--gpio", StringComparison.OrdinalIgnoreCase))
                {
                    useGpio = true;
                }
            }

            string refPath;
            string testPath;
            string leftPath;
            string rightPath;

            if (args.Length >= 2 && !args[0].StartsWith("--", StringComparison.Ordinal))
            {
                refPath = args[0];
                testPath = args[1];
                leftPath = args.Length >= 3 ? args[2] : "tests/left.raw";
                rightPath = args.Length >= 4 ? args[3] : "tests/right.raw";
            }
            else
            {
                refPath = "tests/ref.raw";
                testPath = "tests/test.raw";
                leftPath = "tests/left.raw";
                rightPath = "tests/right.raw";
            }

            if (!File.Exists(refPath) || !File.Exists(testPath) || !File.Exists(leftPath) || !File.Exists(rightPath))
            {
                Console.WriteLine("Missing raw files. Provide args: <ref.raw> <test.raw> [left.raw] [right.raw]");
                Console.WriteLine("Defaults: tests/ref.raw tests/test.raw tests/left.raw tests/right.raw");
                return 1;
            }

            var analyzer = new PcmAnalyze
            {
                RefFile = refPath,
                TestFile = testPath
            };

            var mover = new MoveToward
            {
                LeftFile = leftPath,
                RightFile = rightPath
            };

            var animation = new ExecuteAnimation();

            RaspberryPiGpio gpio = null;
            try
            {
                if (useGpio)
                {
                    gpio = new RaspberryPiGpio(
                        AIN1, AIN2, PWMA_CHIP, PWMA_CHANNEL,
                        BIN1, BIN2, PWMB_CHIP, PWMB_CHANNEL,
                        STBY, LED_RED, LED_YELLOW, LED_GREEN_OR_BLUE);

                    mover.MotorForward = gpio.MotorForward;
                    mover.MotorBackwards = gpio.MotorBackwards;
                    mover.MotorLeft = gpio.MotorLeft;
                    mover.MotorRight = gpio.MotorRight;
                    mover.OnArrival = animation.OnArrivalFriendly;

                    animation.MotorForward = gpio.MotorForward;
                    animation.MotorBackwards = gpio.MotorBackwards;
                    animation.MotorLeft = gpio.MotorLeft;
                    animation.MotorRight = gpio.MotorRight;
                    animation.MotorStop = gpio.MotorStop;
                    animation.LedSet = (r, g, b) =>
                    {
                        gpio.SetLedRed(Math.Clamp(r / 255.0, 0.0, 1.0));
                        gpio.SetLedYellow(Math.Clamp(g / 255.0, 0.0, 1.0));
                        gpio.SetLedGreenOrBlue(Math.Clamp(b / 255.0, 0.0, 1.0));
                    };
                    animation.LedOff = gpio.AllLedsOff;
                }
                else
                {
                    mover.MotorForward = speed => Console.WriteLine("Motor forward {0}", speed);
                    mover.MotorBackwards = speed => Console.WriteLine("Motor backwards {0}", speed);
                    mover.MotorLeft = speed => Console.WriteLine("Motor left {0}", speed);
                    mover.MotorRight = speed => Console.WriteLine("Motor right {0}", speed);
                    mover.OnArrival = animation.OnArrivalFriendly;

                    animation.MotorForward = speed => Console.WriteLine("Anim motor forward {0}", speed);
                    animation.MotorBackwards = speed => Console.WriteLine("Anim motor backwards {0}", speed);
                    animation.MotorLeft = speed => Console.WriteLine("Anim motor left {0}", speed);
                    animation.MotorRight = speed => Console.WriteLine("Anim motor right {0}", speed);
                    animation.MotorStop = () => Console.WriteLine("Anim motor stop");
                    animation.LedSet = (r, g, b) => Console.WriteLine("LED set {0},{1},{2}", r, g, b);
                    animation.LedOff = () => Console.WriteLine("LED off");
                }

            animation.AwaitVocalFeedback.OnVocalSuccess = analyzer.DetectUnlock;
            animation.AwaitVocalFeedback.OnVocalFailure = analyzer.DetectUnlock;
            if (simulateVocal)
            {
                DateTime start = DateTime.UtcNow;
                animation.AwaitVocalFeedback.PhraseDetected = () =>
                    (DateTime.UtcNow - start).TotalMilliseconds >= 500;
            }

            int[] reference = PcmAnalyze.LoadRaw(refPath);
            mover.RefLength = reference.Length;

            int detections = 0;
            analyzer.OnDetect = sampleIdx =>
            {
                mover.OnDetectMove(sampleIdx);
                detections++;
                if (runOnce && detections >= 1)
                {
                    analyzer.DetectLock();
                }
            };

                Console.WriteLine("Running fast detection...");
                analyzer.DetectCommandFastFiles(refPath, testPath, runOnce ? 1 : 0);
            }
            finally
            {
                gpio?.Dispose();
            }

            return 0;
        }
    }
}
