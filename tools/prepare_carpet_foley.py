"""Create four short carpet steps from the CC0 recording; no generated sound."""
from pathlib import Path
import json
import sys
import numpy as np
import soundfile as sf

base = Path(__file__).resolve().parents[1] / 'assets/audio/foley'
data, rate = sf.read(base / 'carpet_steps_mihacappy.ogg')
mono = data.mean(axis=1) if data.ndim > 1 else data
window = int(rate * .025)
energy = np.array([np.sqrt(np.mean(mono[i:i+window] ** 2)) for i in range(0, len(mono)-window, window)])
# Select isolated attacks; leave enough room for a full cloth/sole decay.
ranked = np.argsort(energy)[::-1]
peaks = []
for index in ranked:
    second = float(index * window / rate)
    if .25 < second < len(mono) / rate - .5 and all(abs(second - previous) > .7 for previous in peaks):
        peaks.append(second)
        if len(peaks) == 4:
            break
segments = []
for index, peak in enumerate(sorted(peaks), 1):
    start = max(0, int((peak - .09) * rate))
    cut = mono[start:start+int(.48*rate)].copy()
    fade = min(int(rate * .035), len(cut)//3)
    cut[:fade] *= np.linspace(0, 1, fade)
    cut[-fade:] *= np.linspace(1, 0, fade)
    cut *= .65 / max(.001, float(np.max(np.abs(cut))))
    name = f'carpet_step_{index:02d}.wav'
    sf.write(base / name, cut, rate, subtype='PCM_16')
    segments.append({'file': name, 'start_seconds': round(start/rate, 4), 'duration_seconds': .48})
(base/'carpet_steps_source.json').write_text(json.dumps({
    'author':'Mihacappy', 'license':'CC0 1.0', 'title':'steps_carpet.wav',
    'source':'https://freesound.org/people/Mihacappy/sounds/848210/',
    'download':'https://cdn.freesound.org/previews/848/848210_10594370-lq.ogg',
    'note':'Public compressed preview, mono excerpts with gain normalization and edge fades.',
    'sample_rate': rate, 'segments':segments
}, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(segments))
