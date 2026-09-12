"""Compact shield crack and crack+defeat edits from preserved ElevenLabs audio."""
import json
import math
from prepare_firearm_feedback_audio import ROOT, RATE, layer, mix, write


def main():
    parts = [
        ('impact_v1.wav', .045, 1.12, 700, 10500, .75, 0),
        ('shield_break_v1.wav', .20, 1.05, 280, 10800, 1.0, .008),
        ('shield_break_v1.wav', .09, 1.52, 2200, 11500, .26, .075),
        ('shield_break_v1.wav', .09, 1.31, 1800, 10500, .16, .14),
    ]
    edited = [(layer(file, length, pitch, low, high), gain, offset)
              for file, length, pitch, low, high, gain, offset in parts]
    crack = mix(edited, .30)
    crack = [v * math.exp(-max(0, i / RATE - .09) / .12) for i, v in enumerate(crack)]
    sources = ['impact_v1.wav', 'shield_break_v1.wav']
    records = [write('sfx_gun_break', crack.copy(), sources, -21, -6)]
    # The crack leads; a lower, quieter defeat tail follows, instead of masking it.
    tail = layer('shield_break_v1.wav', .16, .69, 180, 2700)
    combined = mix([(crack, 1, 0), (tail, .33, .18)], .38)
    records.append(write('sfx_gun_break_down', combined, sources, -21, -6))
    manifest = {
        'date': '2026-09-12', 'version': 3,
        'original_generation_manifest': 'audio/manifests/ground-combat-sources.json',
        'previous_master_manifest': 'audio/manifests/ground-weapon-feedback.json',
        'intent': 'Sharp shield crack, short staggered fragments, compact falling tail; crack preserved on simultaneous defeat.',
        'processing': {'crack_layers': parts, 'tail_decay_seconds': .12,
                       'simultaneous_defeat_tail': {'source': 'shield_break_v1.wav', 'pitch': .69, 'gain': .33, 'offset': .18},
                       'output': 'PCM16 mono 48kHz, 0.75ms attack / 16ms end fade, RMS -21 / peak -6 dBFS bounds'},
        'generation': 'No new generation. Existing ElevenLabs originals only; no Apex assets.',
        'listening_review': 'Subjective listening pending; runtime capture recorded separately.',
        'jobs': records,
    }
    (ROOT / 'audio/manifests/ground-shield-feedback.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
