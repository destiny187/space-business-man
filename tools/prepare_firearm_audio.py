"""Prepare downloaded ElevenLabs combat WAVs; preserve originals and QA provenance."""
from pathlib import Path
import array
import hashlib
import json
import math
import wave

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / '우주-비즈니스/assets/audio'
SOURCES = ROOT / 'audio/source/elevenlabs/ground-combat'


def prepare(job):
    original = SOURCES / job['source']
    with wave.open(str(original), 'rb') as source:
        rate, channels = source.getframerate(), source.getnchannels()
        if source.getsampwidth() != 2:
            raise ValueError(f'Expected PCM16: {original}')
        raw = array.array('h', source.readframes(source.getnframes()))
    mono = [sum(raw[i:i + channels]) / channels for i in range(0, len(raw), channels)]
    source_duration = len(mono) / rate
    threshold = max(80, max(abs(v) for v in mono) * .012)
    onset = next((i for i, value in enumerate(mono) if abs(value) >= threshold), 0)
    end = next((i for i in range(len(mono) - 1, -1, -1) if abs(mono[i]) >= threshold), len(mono) - 1)
    start = max(0, onset - int(rate * .003))
    stop = min(len(mono), end + int(rate * .02), start + int(rate * job['trim_max']))
    samples = mono[start:stop]
    if len(samples) < rate * .03:
        raise ValueError('Sound too short: ' + job['id'])
    for i in range(len(samples)):
        samples[i] *= min(1, i / (rate * .002), (len(samples) - 1 - i) / (rate * .015))
    peak = max(abs(v) for v in samples)
    rms = math.sqrt(sum(v * v for v in samples) / len(samples))
    gain = min(32768 * 10 ** (-5 / 20) / max(peak, 1), 32768 * 10 ** (-19 / 20) / max(rms, 1))
    out = array.array('h', (round(v * gain) for v in samples))
    target = ASSETS / (job['id'] + '.wav')
    with wave.open(str(target), 'wb') as result:
        result.setnchannels(1)
        result.setsampwidth(2)
        result.setframerate(rate)
        result.writeframes(out.tobytes())
    return {**job, 'source': str(original.relative_to(ROOT)), 'game_file': str(target.relative_to(ROOT)),
            'source_sha256': hashlib.sha256(original.read_bytes()).hexdigest(),
            'sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'source_duration': source_duration,
            'duration_seconds': len(out) / rate, 'trim_start_seconds': start / rate,
            'format': f'PCM16 mono {rate}Hz', 'peak_dbfs': 20 * math.log10(max(abs(v) for v in out) / 32768),
            'rms_dbfs': 20 * math.log10(math.sqrt(sum(v * v for v in out) / len(out)) / 32768),
            'processing': 'Stereo average; trim onset/tail; 2ms/15ms fades; -19dBFS RMS target / -5dBFS peak ceiling',
            'status': 'generated_integrated_pending_game_review'}


def main():
    settings = json.loads((ROOT / 'audio/manifests/ground-combat-sources.json').read_text())
    missing = [job['source'] for job in settings['jobs'] if not (SOURCES / job['source']).exists()]
    if missing:
        raise SystemExit('Missing downloaded sources; no game files changed: ' + ', '.join(missing))
    records = [prepare(job) for job in settings['jobs']]
    settings['jobs'] = records
    settings['previous_reuse_manifest'] = 'audio/manifests/ground-combat-reuse.json'
    settings['new_generation_status'] = 'Downloaded originals preserved; all eight weapon families use dedicated ElevenLabs sources.'
    (ROOT / 'audio/manifests/ground-combat.json').write_text(json.dumps(settings, ensure_ascii=False, indent=2) + '\n')
    for job in records:
        print(job['id'], round(job['duration_seconds'], 3), 's', round(job['peak_dbfs'], 1), 'dBFS')


if __name__ == '__main__':
    main()
