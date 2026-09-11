"""Build five-state sheets for each anatomical construction, from actual game captures."""
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from biota_review_state import motion_matches

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'docs/production/media/biota'
STATES = ['idle', 'move', 'feed', 'dormant', 'stressed']


def main():
    name = 'biota_preview_forms.json' if '--preview' in sys.argv else 'biota_forms.json'
    forms = json.loads((ROOT / '우주-비즈니스/data/bestiary' / name).read_text())['forms']
    motion_hash = hashlib.sha256((ROOT / '우주-비즈니스/scripts/actors/creatures/bestiary_actor.gd').read_bytes()).hexdigest()
    grouped = {}
    for row in forms:
        if '--unchanged' in sys.argv and (row.get('replacement') or row['family']=='biota_plant_spiralcone'):continue
        if row['anatomy'] != 0 and not (row.get('replacement') and row['organ_system']=='armor'):
            continue
        record = BASE / 'render-records' / (row['id'] + '.json')
        if not record.exists():
            continue
        data = json.loads(record.read_text())
        if data.get('model_sha256') != row['lods']['near']['sha256'] or not motion_matches(data,row) or data.get('failures'):
            continue
        key=row['id'] if row.get('replacement') else row['family']
        if not all((BASE / 'motion' / (key + '-' + state + '.png')).exists() for state in STATES):
            continue
        grouped.setdefault((row['category'], row.get('anatomical_type',row['construction'])), row)
    selected = [grouped[key] for key in sorted(grouped)]
    out = BASE / 'review'
    out.mkdir(exist_ok=True)
    font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 15)
    index = []
    for start in range(0, len(selected), 4):
        batch = selected[start:start + 4]
        board = Image.new('RGB', (1500, len(batch) * 278 + 48), '#12232b')
        draw = ImageDraw.Draw(board)
        for x, state in enumerate(STATES):
            draw.text((x * 300 + 12, 15), state.upper(), font=font, fill='#c4eeec')
        for y, row in enumerate(batch):
            index.append({'id': row['id'], 'construction': row['construction'], 'category': row['category'], 'page': start // 4 + 1, 'model_sha256': row['lods']['near']['sha256']})
            for x, state in enumerate(STATES):
                key=row['id'] if row.get('replacement') else row['family']
                im = Image.open(BASE / 'motion' / (key + '-' + state + '.png')).convert('RGB')
                im.thumbnail((296, 246))
                board.paste(im, (x * 300 + (300 - im.width) // 2, y * 278 + 48))
                draw.text((x * 300 + 8, y * 278 + 297), row['id'].removeprefix('biota_'), font=font, fill='#d1e8ed')
        board.save(out / ('motion-types-%02d.jpg' % (start // 4 + 1)), quality=91)
    (out / 'motion-index.json').write_text(json.dumps(index, ensure_ascii=False, indent=2) + '\n')
    print('BIOTA_MOTION_SHEETS', len(selected), 'anatomical silhouettes')


if __name__ == '__main__':
    main()
