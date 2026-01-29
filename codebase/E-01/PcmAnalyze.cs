using System;
using System.IO;

namespace AnimalsFox.E01
{
    public sealed class PcmAnalyze
    {
        public const int SampleRate = 16000;
        public const int BytesPerSample = 2;

        public const int FracBits = 14;
        public const int Scale = 1 << FracBits;

        public const int ThresholdFixed = 13107; // 0.80 * Scale
        public const int CoarseThresholdFixed = 9830; // 0.60 * Scale
        public const int CoarseStride = 16;

        public string RefFile { get; set; } = "ref.raw";
        public string TestFile { get; set; } = "test.raw";

        public bool DetectLocked { get; private set; }

        public Action<int> OnDetect { get; set; } = _ => { };

        public void DetectLock()
        {
            DetectLocked = true;
        }

        public void DetectUnlock()
        {
            DetectLocked = false;
        }

        public static int[] LoadRaw(string path)
        {
            byte[] bytes = File.ReadAllBytes(path);
            int evenBytes = bytes.Length & ~1;
            int samples = evenBytes / 2;
            int[] result = new int[samples];
            for (int i = 0; i < samples; i++)
            {
                int b0 = bytes[i * 2];
                int b1 = bytes[i * 2 + 1];
                short sample = (short)(b0 | (b1 << 8));
                result[i] = sample;
            }
            return result;
        }

        public static int[] LoadPcm(string path)
        {
            int[] samples = LoadRaw(path);
            Console.WriteLine("Loaded {0} samples from: {1}", samples.Length, path);
            return samples;
        }

        private static ulong ISqrt64(ulong n)
        {
            if (n == 0) return 0;
            ulong x = n / 2 + 1;
            while (true)
            {
                ulong x1 = (n / x + x) / 2;
                if (x1 >= x) return x;
                x = x1;
            }
        }

        private static ulong SumSq64(int[] a, int offset, int n)
        {
            long acc = 0;
            for (int i = 0; i < n; i++)
            {
                long x = a[offset + i];
                acc += x * x;
            }
            return (ulong)acc;
        }

        private static long Dot64(int[] a, int aOffset, int[] b, int bOffset, int n)
        {
            long acc = 0;
            for (int i = 0; i < n; i++)
            {
                long x = a[aOffset + i];
                long y = b[bOffset + i];
                acc += x * y;
            }
            return acc;
        }

        private static int CorrFixedWindow(int[] test, int tOffset, int[] reference, int rOffset, int n, ulong refNorm)
        {
            long dot = Dot64(test, tOffset, reference, rOffset, n);
            ulong sum = SumSq64(test, tOffset, n);
            ulong windowNorm = ISqrt64(sum);
            if (refNorm == 0 || windowNorm == 0) return 0;

            ulong denom = refNorm * windowNorm;
            if (denom == 0) return 0;

            bool neg = dot < 0;
            ulong numerAbs = (ulong)(neg ? -dot : dot);
            ulong scaled = numerAbs << FracBits;
            ulong q = scaled / denom;
            int result = (int)q;
            return neg ? -result : result;
        }

        public bool DetectCommand(int maxDetections = 0)
        {
            int[] reference = LoadRaw(RefFile);
            int[] test = LoadRaw(TestFile);
            return DetectCommandInternal(test, reference, false, maxDetections);
        }

        public bool DetectCommandFast(int maxDetections = 0)
        {
            int[] reference = LoadRaw(RefFile);
            int[] test = LoadRaw(TestFile);
            return DetectCommandInternal(test, reference, true, maxDetections);
        }

        public bool DetectCommandFastFiles(string refPath, string testPath, int maxDetections = 0)
        {
            int[] reference = LoadRaw(refPath);
            int[] test = LoadRaw(testPath);
            return DetectCommandInternal(test, reference, true, maxDetections);
        }

        public bool DetectCommandFiles(string refPath, string testPath, int maxDetections = 0)
        {
            int[] reference = LoadRaw(refPath);
            int[] test = LoadRaw(testPath);
            return DetectCommandInternal(test, reference, false, maxDetections);
        }

        private bool DetectCommandInternal(int[] test, int[] reference, bool coarseToFine, int maxDetections)
        {
            bool found = false;
            DetectUnlock();
            int refLen = reference.Length;
            int maxWin = Math.Max(0, test.Length - refLen);
            ulong refNorm = ISqrt64(SumSq64(reference, 0, refLen));
            int detections = 0;

            if (!coarseToFine)
            {
                for (int i = 0; i <= maxWin; i++)
                {
                    int corr = CorrFixedWindow(test, i, reference, 0, refLen, refNorm);
                    if (corr > ThresholdFixed)
                    {
                        Console.WriteLine("Detected come here at sample {0}", i + refLen);
                        found = true;
                        if (!DetectLocked)
                        {
                            DetectLock();
                            OnDetect(i + refLen);
                        }
                        detections++;
                        if (maxDetections > 0 && detections >= maxDetections)
                        {
                            break;
                        }
                    }
                }

                if (!found)
                {
                    Console.WriteLine("No match found.");
                }

                return found;
            }

            for (int i = 0; i <= maxWin; i += CoarseStride)
            {
                int corr = CorrFixedWindow(test, i, reference, 0, refLen, refNorm);
                if (corr > CoarseThresholdFixed)
                {
                    int start = Math.Max(0, i - CoarseStride);
                    int end = Math.Min(maxWin, i + CoarseStride);
                    for (int j = start; j <= end; j++)
                    {
                        int fine = CorrFixedWindow(test, j, reference, 0, refLen, refNorm);
                        if (fine > ThresholdFixed)
                        {
                            Console.WriteLine("Detected come here at sample {0}", j + refLen);
                            found = true;
                            if (!DetectLocked)
                            {
                                DetectLock();
                                OnDetect(j + refLen);
                            }
                            detections++;
                            if (maxDetections > 0 && detections >= maxDetections)
                            {
                                break;
                            }
                        }
                    }
                    if (maxDetections > 0 && detections >= maxDetections)
                    {
                        break;
                    }
                }
            }

            if (!found)
            {
                Console.WriteLine("No match found.");
            }

            return found;
        }

        public void ShowInputFiles()
        {
            Console.WriteLine("REF-FILE: {0}", RefFile);
            Console.WriteLine("TEST-FILE: {0}", TestFile);
        }
    }
}
