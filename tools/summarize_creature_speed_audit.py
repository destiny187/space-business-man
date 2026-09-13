"""Package actual Godot A/B frames and measured traces; no generated substitute artwork."""
import hashlib
import json
import statistics
import subprocess
from pathlib import Path

import imageio_ffmpeg
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'output/creature-speed-audit-20260913'
OUT = ROOT / 'docs/production/media/creature-speed-audit'
WINDOWS = {'walk': (30, 60), 'authored_run': (75, 120), 'combat': (150, 210), 'charge_or_reverse': (225, 270)}


def summarize(trace):
    result = {}
    for name, (start, end) in WINDOWS.items():
        rows = trace[start:end]
        feet = [f for r in rows for f in r['feet']]
        slip = [f['slip_m'] for f in feet if f['slip_m'] >= 0]
        result[name] = {key: {'min': min(r[key] for r in rows),
                            'mean': statistics.mean(r[key] for r in rows),
                            'max': max(r[key] for r in rows)}
                        for key in ['visual_mps', 'cycle_hz', 'clip_rate']}
        result[name].update(stance_pairs=len(slip), max_stance_frame_displacement_m=max(slip, default=0),
                            max_foot_target_error_m=max((f['target_error_m'] for f in feet), default=0),
                            zero_support_frames=sum(bool(r['feet']) and not any(f['planted'] for f in r['feet']) for r in rows),
                            max_root_error_m=max(r['root_error_m'] for r in rows),
                            max_body_error_m=max(r['body_error_m'] for r in rows),
                            clips=sorted({r['clip'] for r in rows}))
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    evidence = json.loads((BASE / 'evidence.json').read_text())
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    summaries = []
    boards = []
    for row in evidence['species']:
        name = row['art_id']
        record = {k: row[k] for k in ['species_id', 'art_id', 'kind', 'walk_mps', 'authored_run_mps', 'combat']}
        for mode in ['walk-only', 'runtime']:
            record[mode] = summarize(json.loads((BASE / name / f'{mode}.json').read_text()))
            smooth = BASE / 'smooth' / name / f'{mode}.json'
            if smooth.exists():
                record['smooth-' + mode] = summarize(json.loads(smooth.read_text()))
        summaries.append(record)
        target = OUT / f'{name}.mp4'
        subprocess.run([ffmpeg, '-y', '-v', 'error', '-framerate', '30', '-i', str(BASE / name / 'frame-%03d.png'),
                        '-frames:v', '360', '-c:v', 'libx264', '-crf', '20', '-pix_fmt', 'yuv420p',
                        '-movflags', '+faststart', str(target)], check=True)
        image = Image.open(BASE / name / 'frame-165.png').convert('RGB')
        image.thumbnail((960, 450))
        boards.append(image)
    board = Image.new('RGB', (960, 450 * len(boards)), '#b7c1ae')
    for i, frame in enumerate(boards):
        board.paste(frame, (0, i * 450))
    board.save(OUT / 'comparison-board.jpg', quality=91)
    # Consecutive frames expose stance/release and direction changes without treating one still as motion evidence.
    for name in ['sailhorn', 'pressureurn']:
        sheet = Image.new('RGB', (1280, 600), '#b7c1ae')
        for i, frame in enumerate(range(225, 237)):
            image = Image.open(BASE / name / f'frame-{frame:03d}.png').convert('RGB')
            image.thumbnail((320, 150))
            sheet.paste(image, ((i % 4) * 320, (i // 4) * 200))
            ImageDraw.Draw(sheet).text(((i % 4) * 320 + 8, (i // 4) * 200 + 153), f'frame {frame} / {frame / 30:.3f}s', fill='#203a36')
        sheet.save(OUT / f'{name}-sequence.jpg', quality=92)
    listing = BASE / 'concat.txt'
    listing.write_text(''.join(f"file '{OUT / (r['art_id'] + '.mp4')}'\n" for r in evidence['species']))
    subprocess.run([ffmpeg, '-y', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', str(listing),
                    '-c', 'copy', '-movflags', '+faststart', str(OUT / 'comparison.mp4')], check=True)
    evidence['summary'] = summaries
    evidence['blender'] = json.loads((BASE / 'blender/evidence.json').read_text())
    source_board = Image.new('RGB', (480 * 5, 400 * 2), '#b7c1ae')
    for i, row in enumerate(evidence['species']):
        for j, clip in enumerate(['move_loop', 'run_loop']):
            source_board.paste(Image.open(BASE / 'blender' / f"{row['art_id']}-{clip}.png").convert('RGB'), (480 * i, 400 * j))
    source_board.save(OUT / 'blender-board.jpg', quality=91)
    paths = ['우주-비즈니스/scripts/actors/creatures/remodel_motion.gd',
             '우주-비즈니스/scripts/actors/creatures/ground_locomotion.gd',
             '우주-비즈니스/scripts/world/surface_ecology.gd',
             '우주-비즈니스/data/wildlife_combat.json',
             '우주-비즈니스/tests/render_creature_speed_audit.gd']
    evidence['sha256'] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
    (OUT / 'evidence.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n')
    for r in summaries:
        print(r['art_id'], 'combat m/s', r['combat']['speed'], 'walk/run mean rate',
              round(r['walk-only']['combat']['clip_rate']['mean'], 2), round(r['runtime']['combat']['clip_rate']['mean'], 2),
              'stance slip', round(r['runtime']['combat']['max_stance_frame_displacement_m'], 3))


if __name__ == '__main__':
    main()
