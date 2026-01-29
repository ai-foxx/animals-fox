using System;
using System.Threading;

namespace AnimalsFox.E01
{
    public sealed class AwaitVocalFeedback
    {
        public Func<bool> PhraseDetected { get; set; } = () => false;
        public Func<bool> LoudnessDetected { get; set; } = () => false;

        public Action OnVocalSuccess { get; set; } = () => { };
        public Action OnVocalFailure { get; set; } = () => { };

        public const int FeedbackWaitMs = 3000;
        public const int FeedbackPollMs = 100;

        public void Await()
        {
            int elapsed = 0;
            while (true)
            {
                if (PhraseDetected())
                {
                    OnVocalSuccess();
                    return;
                }

                if (LoudnessDetected())
                {
                    OnVocalSuccess();
                    return;
                }

                Thread.Sleep(FeedbackPollMs);
                elapsed += FeedbackPollMs;
                if (elapsed >= FeedbackWaitMs)
                {
                    break;
                }
            }

            OnVocalFailure();
        }
    }
}
