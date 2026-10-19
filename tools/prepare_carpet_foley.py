"""Restore the user's chosen A recording with complete, naturally paced contacts."""
from pathlib import Path
import hashlib
import json
import argparse
import wave
import numpy as np
import soundfile as sf

base = Path(__file__).resolve().parents[1] / 'assets/audio/foley'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--verify', action='store_true', help='Check committed clips without writing them')
args = parser.parse_args()


SOURCE = base / 'carpet_steps_mihacappy.ogg'
SOURCE_URL = 'https://freesound.org/people/Mihacappy/sounds/848210/'
DURATION = .28


def soften_pile(cut, rate):
    # Preserve A's recording and existing soft EQ, rather than synthesizing a
    # different timbre. Filter the original full excerpt before trimming its tail.
    padding = int(rate * .12)
    padded = np.pad(cut, (padding, padding))
    frequencies = np.fft.rfftfreq(len(padded), 1 / rate)
    lowpass = 1 / np.sqrt(1 + (frequencies / 1150.0) ** 8)
    highpass = frequencies ** 2 / (frequencies ** 2 + 65.0 ** 2)
    filtered = np.fft.irfft(np.fft.rfft(padded) * lowpass * highpass, n=len(padded))
    return filtered[padding:padding + len(cut)]


data, rate = sf.read(SOURCE)
mono = data.mean(axis=1) if data.ndim > 1 else data
window = int(rate * .025)
energy = np.array([np.sqrt(np.mean(mono[i:i + window] ** 2))
                   for i in range(0, len(mono) - window, window)])
# These are the same source contacts selected for A, which the user preferred
# after comparing recorded alternatives. Do not substitute procedural noise.
peaks = []
for index in np.argsort(energy)[::-1]:
    second = float(index * window / rate)
    if .25 < second < len(mono) / rate - .5 and all(abs(second - old) > .7 for old in peaks):
        peaks.append(second)
        if len(peaks) == 4:
            break


segments = []
measurements = []
for index, peak in enumerate(sorted(peaks), 1):
    start = max(0, int((peak - .09) * rate))
    original = mono[start:start + int(.48 * rate)].copy()
    original *= .65 / max(.001, float(abs(original).max()))
    original = soften_pile(original, rate)
    fade = int(rate * .045)
    original[:fade] *= np.linspace(0, 1, fade)
    original[-fade:] *= np.linspace(1, 0, fade)
    trim_start = int(rate * .04)
    contact = original[trim_start:trim_start + int(rate * DURATION)].copy()
    contact[:int(rate * .006)] *= np.linspace(0, 1, int(rate * .006))
    contact[-int(rate * .018):] *= np.linspace(1, 0, int(rate * .018))
    pcm = np.round(np.clip(contact, -1, 1) * 32767).astype('<i2')
    name = f'carpet_step_{index:02d}.wav'
    if args.verify:
        with wave.open(str(base / name), 'rb') as stored:
            assert stored.getframerate() == rate and stored.getnchannels() == 1 and stored.getsampwidth() == 2
            assert stored.readframes(stored.getnframes()) == pcm.tobytes(), name + ': regenerate the clip'
    else:
        with wave.open(str(base / name), 'wb') as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(rate)
            output.writeframes(pcm.tobytes())
    cut = pcm.astype(float) / 32768
    measurements.append({'file': name, 'peak': round(float(abs(cut).max()), 4),
                         'rms': round(float(np.sqrt(np.mean(cut ** 2))), 4)})
    segments.append({'file': name, 'original_A_start_seconds': round(start / rate, 4),
                     'source_start_seconds': round((start + trim_start) / rate, 4),
                     'duration_seconds': DURATION,
                     'sha256': hashlib.sha256((base / name).read_bytes()).hexdigest()})
metadata = {
    'active_source': 'User-selected A real carpet recording, natural walking cadence, 2026-10-19',
    'author': 'Mihacappy', 'license': 'CC0 1.0', 'title': 'steps_carpet.wav',
    'source': SOURCE_URL, 'source_file': SOURCE.name,
    'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'download': 'https://cdn.freesound.org/previews/848/848210_10594370-lq.ogg',
    'license_url': 'https://creativecommons.org/publicdomain/zero/1.0/',
    'license_verified_on': '2026-10-19',
    'generator': 'tools/prepare_carpet_foley.py',
    'note': 'Real recording, not synthesis. Restores the four A source contacts and its 65 Hz / 1150 Hz soft EQ. Trim each A excerpt at 40-320 ms with 6/18 ms edge fades; preserve natural transients and pitch. Ordinary walking is 1.95/3.3 = 0.5909 seconds per contact, matching the recording; actual sprinting remains separate at 0.3112 s. No resynthesis or time stretching. Runtime gain remains -20 dB.',
    'sample_rate': rate, 'segments': segments
}
if args.verify:
    assert json.loads((base / 'carpet_steps_source.json').read_text(encoding='utf-8')) == metadata, 'Source manifest differs; regenerate'
else:
    (base/'carpet_steps_source.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
print(json.dumps({'verified': args.verify, 'clips': measurements}, indent=2))
