using System;
using System.IO;

namespace AnimalsFox.E01
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            bool runOnce = false;
            bool simulateVocal = false;
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

            return 0;
        }
    }
}
