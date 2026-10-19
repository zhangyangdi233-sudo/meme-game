"""Validate delivered recordings without prescribing a synthetic sound profile."""
from array import array
import hashlib
import math
from pathlib import Path
import sys
import unittest
import wave

BASE = Path(__file__).resolve().parents[1] / 'assets/audio/foley'


class CarpetAudioTests(unittest.TestCase):
    def test_recorded_contacts_have_valid_pcm_and_clean_edit_boundaries(self):
        paths = sorted(BASE.glob('carpet_step_??.wav'))
        self.assertEqual([path.name for path in paths],
                         [f'carpet_step_{index:02d}.wav' for index in range(1, 5)],
                         'all four runtime variations must be present')
        fingerprints = set()
        for path in paths:
            with self.subTest(clip=path.name), wave.open(str(path), 'rb') as stream:
                self.assertEqual(stream.getcomptype(), 'NONE', 'runtime contacts must be uncompressed PCM')
                self.assertEqual(stream.getnchannels(), 1)
                self.assertEqual(stream.getsampwidth(), 2)
                self.assertEqual(stream.getframerate(), 48000)
                frames = stream.getnframes()
                self.assertGreater(frames, 0, 'the recording must not be empty')
                self.assertLessEqual(frames, round(48000 * .28), 'a contact must fit the unchanged running interval')
                raw = stream.readframes(frames)
                self.assertEqual(len(raw), frames * 2, 'the PCM payload must not be truncated')
                fingerprints.add(hashlib.sha256(raw).hexdigest())
                samples = array('h', raw)
                if sys.byteorder != 'little':
                    samples.byteswap()
                peak = max(abs(value) for value in samples)
                rms = math.sqrt(sum(value * value for value in samples) / frames)
                self.assertGreater(rms, 1.0, 'a valid recording must contain audible sample data, not silence')
                self.assertLess(peak, 32767, 'the delivered PCM must not hit either full-scale clipping rail')
                self.assertEqual(samples[0], 0, 'the entry cut must fade from zero')
                self.assertEqual(samples[-1], 0, 'the exit cut must fade to zero')
                # Inspect only the edit boundary. Natural pressure, heel/toe
                # motion, fibre rub and multiple envelope peaks remain valid.
                tail = samples[-min(frames, 48):]  # final 1 ms at 48 kHz
                tail_rms = math.sqrt(sum(value * value for value in tail) / len(tail))
                self.assertLessEqual(tail_rms, max(2.0, peak * .02), 'the last millisecond must settle before playback stops')
                tail_jump = max((abs(b - a) for a, b in zip(tail, tail[1:])), default=0)
                self.assertLessEqual(tail_jump, max(2.0, peak * .02), 'the final fade must not contain a discontinuous jump')
        self.assertEqual(len(fingerprints), 4, 'the four variations must contain different recorded waveforms')


if __name__ == '__main__':
    unittest.main()
