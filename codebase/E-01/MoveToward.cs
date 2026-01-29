using System;

namespace AnimalsFox.E01
{
    public sealed class MoveToward
    {
        public const int MaxLag = 32;
        public const int MaxSpeed = 100;

        public string LeftFile { get; set; } = "left.raw";
        public string RightFile { get; set; } = "right.raw";

        public int RefLength { get; set; }

        public Action<int> MotorForward { get; set; } = _ => { };
        public Action<int> MotorBackwards { get; set; } = _ => { };
        public Action<int> MotorLeft { get; set; } = _ => { };
        public Action<int> MotorRight { get; set; } = _ => { };

        public Action OnArrival { get; set; } = () => { };

        private static long CorrLag(int[] left, int leftOffset, int[] right, int rightOffset, int n, int lag)
        {
            long acc = 0;
            if (lag >= 0)
            {
                int m = Math.Max(0, n - lag);
                for (int i = 0; i < m; i++)
                {
                    long a = left[leftOffset + lag + i];
                    long b = right[rightOffset + i];
                    acc += a * b;
                }
            }
            else
            {
                int m = Math.Max(0, n + lag);
                int lagAbs = -lag;
                for (int i = 0; i < m; i++)
                {
                    long a = left[leftOffset + i];
                    long b = right[rightOffset + lagAbs + i];
                    acc += a * b;
                }
            }

            return acc;
        }

        private static long Abs64(long v)
        {
            return v < 0 ? -v : v;
        }

        private static int EstimateLag(int[] left, int leftOffset, int[] right, int rightOffset, int n, int maxLag)
        {
            int bestLag = 0;
            long bestVal = 0;
            for (int lag = -maxLag; lag <= maxLag; lag++)
            {
                long val = Abs64(CorrLag(left, leftOffset, right, rightOffset, n, lag));
                if (val > bestVal)
                {
                    bestVal = val;
                    bestLag = lag;
                }
            }

            return bestLag;
        }

        private void SteerToward(int lag)
        {
            int magnitude = Math.Min(MaxLag, Math.Abs(lag));
            if (magnitude == 0)
            {
                MotorForward(MaxSpeed);
                return;
            }

            int speed = (MaxSpeed * magnitude) / MaxLag;
            if (lag < 0)
            {
                MotorLeft(speed);
            }
            else
            {
                MotorRight(speed);
            }
        }

        public void OnDetectMove(int sampleIdx)
        {
            int[] left = PcmAnalyze.LoadRaw(LeftFile);
            int[] right = PcmAnalyze.LoadRaw(RightFile);
            int count = Math.Min(left.Length, right.Length);

            int start = Math.Max(0, sampleIdx - RefLength);
            int end = Math.Min(start + RefLength, count);
            int win = Math.Max(0, end - start);

            if (win > 0)
            {
                int lag = EstimateLag(left, start, right, start, win, MaxLag);
                SteerToward(lag);
            }

            OnArrival();
        }
    }
}
