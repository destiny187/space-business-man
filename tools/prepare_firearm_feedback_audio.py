"""Re-master preserved ElevenLabs originals for compact ground weapon feedback.

No generated/synthesized substitute: all layers below are edits of recorded ElevenLabs
sources. Originals, original prompts and v1 manifests remain unchanged.
"""
from pathlib import Path
import array
import hashlib
import json
import math
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'audio/source/elevenlabs/ground-combat'
ASSETS = ROOT / '우주-비즈니스/assets/audio'
RATE = 48000


def read(path):
    with wave.open(str(path), 'rb') as stream:
        assert stream.getsampwidth() == 2 and stream.getframerate() == RATE
        channels = stream.getnchannels()
        raw = array.array('h', stream.readframes(stream.getnframes()))
    return [sum(raw[i:i + channels]) / (32768 * channels) for i in range(0, len(raw), channels)]


def lowpass(samples, hz):
    alpha = 1 - math.exp(-2 * math.pi * hz / RATE)
    value = 0.0
    out = []
    for sample in samples:
        value += alpha * (sample - value)
        out.append(value)
    return out


def layer(filename, duration, pitch=1.0, low=80, high=10500):
    samples = read(SOURCE / filename)
    threshold = max(abs(v) for v in samples) * .018
    onset = next((i for i, v in enumerate(samples) if abs(v) > threshold), 0)
    samples = samples[max(0, onset - 48):]
    count = min(int(duration * RATE), int((len(samples) - 1) / pitch))
    pitched = []
    for i in range(count):
        pos = i * pitch
        index = int(pos)
        pitched.append(samples[index] * (1 - pos + index) + samples[index + 1] * (pos - index))
    bass = lowpass(pitched, low)
    return lowpass([a - b for a, b in zip(pitched, bass)], high)


def write(id, samples, sources, target_rms=-19.0, peak_db=-5.0):
    for i in range(len(samples)):
        samples[i] *= min(1, i / (RATE * .00075), (len(samples) - 1 - i) / (RATE * .016))
    peak = max(abs(v) for v in samples)
    rms = math.sqrt(sum(v * v for v in samples) / len(samples))
    gain = min(10 ** (peak_db / 20) / max(peak, 1e-9), 10 ** (target_rms / 20) / max(rms, 1e-9))
    result = array.array('h', (round(v * gain * 32767) for v in samples))
    path = ASSETS / (id + '.wav')
    with wave.open(str(path), 'wb') as stream:
        stream.setnchannels(1); stream.setsampwidth(2); stream.setframerate(RATE); stream.writeframes(result.tobytes())
    record = {
        'id': id, 'provider': 'ElevenLabs original reuse and mastering; no new generation',
        'sources': [{'path': str((SOURCE / s).relative_to(ROOT)), 'sha256': hashlib.sha256((SOURCE / s).read_bytes()).hexdigest()} for s in sources],
        'game_file': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'duration': len(result) / RATE, 'peak_dbfs': 20 * math.log10(max(abs(v) for v in result) / 32768),
        'rms_dbfs': 20 * math.log10(math.sqrt(sum(float(v) ** 2 for v in result) / len(result)) / 32768),
        'clipped_samples': sum(abs(v) >= 32767 for v in result),
    }
    print(id, round(record['duration'], 3), 's', round(record['peak_dbfs'], 2), 'dBFS')
    return record


def mix(layers, duration):
    out = [0.0] * int(duration * RATE)
    for samples, gain, offset in layers:
        start = int(offset * RATE)
        for i, sample in enumerate(samples[:len(out) - start]):out[i + start] += sample * gain
    return out


def main():
    families = {'carbine': (.23, 1.18, .065), 'pistol': (.23, 1.25, .075),
                'smg': (.135, 1.13, .040), 'shotgun': (.36, 1.18, .110),
                'lmg': (.24, 1.17, .070), 'marksman': (.27, 1.24, .080),
                'sniper': (.37, 1.21, .125), 'plasma': (.31, 1.12, .115)}
    required = [name + '_v1.wav' for name in families] + ['impact_v1.wav', 'shield_break_v1.wav']
    for name in required:
        if not (SOURCE / name).is_file():raise SystemExit('Missing preserved ElevenLabs source: ' + name)
    records = []
    for name, (duration, attack, tail) in families.items():
        samples = layer(name + '_v1.wav', duration, low=65 if name in ['shotgun', 'sniper', 'plasma'] else 90)
        samples = [v * (1 + (attack - 1) * math.exp(-i / (RATE * .024))) * math.exp(-max(0, i / RATE - tail) / .12) for i, v in enumerate(samples)]
        records.append(write('sfx_gun_' + name, samples, [name + '_v1.wav'], -19.0))
    definitions = {
        'hit_armor': ([('impact_v1.wav', .115, 1.0, 180, 9000, 1.0, 0)], .13),
        'hit_organic': ([('shotgun_v1.wav', .09, .72, 110, 1450, .42, 0), ('impact_v1.wav', .065, .82, 250, 2400, .7, 0)], .115),
        'hit_shield': ([('impact_v1.wav', .07, 1.2, 1100, 9500, .75, 0), ('shield_break_v1.wav', .11, 1.24, 650, 8500, .45, .012)], .145),
        'hit_weak': ([('impact_v1.wav', .11, 1.18, 180, 10500, 1.0, 0), ('marksman_v1.wav', .075, 1.45, 1800, 6500, .20, .012)], .15),
        'break': ([('impact_v1.wav', .055, 1.05, 250, 9000, .65, 0), ('shield_break_v1.wav', .225, .95, 200, 10500, 1.0, .01)], .25),
        'down': ([('impact_v1.wav', .075, .80, 140, 4500, .75, 0), ('shield_break_v1.wav', .15, .76, 200, 5500, .65, .045)], .23),
    }
    for id, (parts, duration) in definitions.items():
        layers = [(layer(file, length, pitch, low, high), gain, offset) for file, length, pitch, low, high, gain, offset in parts]
        records.append(write('sfx_gun_' + id, mix(layers, duration), sorted({p[0] for p in parts}), -22.0, -7.0))
    manifest = {
        'date': '2026-09-12', 'version': 2,
        'original_generation_manifest': 'audio/manifests/ground-combat-sources.json',
        'previous_master_manifest': 'audio/manifests/ground-combat.json',
        'intent': 'Short attack, restrained tail, distinct armor/organic/shield/weak/break/down confirmation. Original ElevenLabs sources only.',
        'processing': 'Onset trim; 0.75ms attack / 16ms end fades; source-specific band shaping; transient emphasis; exponential tail; peak/RMS bounded PCM16 mono 48kHz. Confirmation layers edited from the named sources.',
        'listening_review': 'Subjective listening pending; runtime playback and recorded signal review are recorded separately.',
        'jobs': records,
    }
    (ROOT / 'audio/manifests/ground-weapon-feedback.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':main()
