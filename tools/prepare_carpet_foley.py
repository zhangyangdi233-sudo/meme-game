"""Shape the CC0 carpet recording into soft, muffled steps on thick pile."""
from pathlib import Path
import json
import argparse
import numpy as np
import soundfile as sf

base = Path(__file__).resolve().parents[1] / 'assets/audio/foley'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--verify', action='store_true', help='Check committed clips without writing them')
args = parser.parse_args()


def soften_pile(cut, rate):
    # Filter the recording itself. Padding avoids wrapping a footfall's tail
    # around to its attack; the soft rolloff avoids a brick-wall ringing edge.
    padding = int(rate * .12)
    padded = np.pad(cut, (padding, padding))
    frequencies = np.fft.rfftfreq(len(padded), 1 / rate)
    lowpass = 1 / np.sqrt(1 + (frequencies / 1150.0) ** 8)
    highpass = frequencies ** 2 / (frequencies ** 2 + 65.0 ** 2)
    filtered = np.fft.irfft(np.fft.rfft(padded) * lowpass * highpass, n=len(padded))
    return filtered[padding:padding + len(cut)]


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
measurements = []
for index, peak in enumerate(sorted(peaks), 1):
    start = max(0, int((peak - .09) * rate))
    cut = mono[start:start+int(.48*rate)].copy()
    # Normalize before damping, never boost the softened tail back to a click.
    cut *= .65 / max(.001, float(np.max(np.abs(cut))))
    untreated = cut.copy()
    cut = soften_pile(cut, rate)
    fade = min(int(rate * .045), len(cut)//3)
    cut[:fade] *= np.linspace(0, 1, fade)
    cut[-fade:] *= np.linspace(1, 0, fade)
    name = f'carpet_step_{index:02d}.wav'
    if args.verify:
        stored, stored_rate = sf.read(base / name)
        assert stored_rate == rate and stored.shape == cut.shape, name + ': format changed'
        assert np.max(np.abs(stored - cut)) <= 1.01 / 32768, name + ': regenerate the clip'
    else:
        sf.write(base / name, cut, rate, subtype='PCM_16')
    spectrum = np.abs(np.fft.rfft(cut)) ** 2
    frequencies = np.fft.rfftfreq(len(cut), 1 / rate)
    high_share = float(spectrum[frequencies >= 2500].sum() / max(spectrum.sum(), 1e-12))
    rms_ratio = float(np.sqrt(np.mean(cut ** 2) / max(np.mean(untreated ** 2), 1e-12)))
    assert high_share < .01 and rms_ratio < 1.0, name + ': footfall must be softer, not brighter or louder'
    measurements.append({'file': name, 'high_band_energy_fraction': round(high_share, 6), 'rms_ratio_to_source_cut': round(rms_ratio, 4)})
    segments.append({'file': name, 'start_seconds': round(start/rate, 4), 'duration_seconds': .48})
metadata = {
    'author':'Mihacappy', 'license':'CC0 1.0', 'title':'steps_carpet.wav',
    'source':'https://freesound.org/people/Mihacappy/sounds/848210/',
    'download':'https://cdn.freesound.org/previews/848/848210_10594370-lq.ogg',
    'note':'Public compressed preview, mono excerpts normalized before soft filtering. No post-filter gain normalization. Thick-pile damping: 1150 Hz soft low-pass, 65 Hz rumble reduction, 45 ms edge fades. Playback -20 dB.',
    'sample_rate': rate, 'segments':segments
}
if not args.verify:
    (base/'carpet_steps_source.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
print(json.dumps({'verified': args.verify, 'clips': measurements}, indent=2))
