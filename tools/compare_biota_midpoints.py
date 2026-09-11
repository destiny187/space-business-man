"""Compose real before/after Godot captures without altering specimen images."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from biota_review_state import motion_matches

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'docs/production/media/biota'
BEFORE = ROOT / 'output/biota-midpoint-before'
SPECIMENS = [
    ('biota_spindle_armor_25', '사슴형'),
    ('biota_radial_armor_25', '거북형'),
    ('biota_tower_armor_25', '기린형'),
    ('biota_chain_armor_25', '캥거루형'),
    ('biota_bilateral_armor_26', '올빼미형'),
    ('biota_amphora_armor_25', '게형'),
    ('biota_ribbon_armor_26', '뱀형'),
    ('biota_branch_armor_25', '사마귀형'),
]


def main():
    forms = {r['id']: r for r in json.loads((ROOT / '우주-비즈니스/data/bestiary/biota_preview_forms.json').read_text())['forms']}
    font_path = '/System/Library/Fonts/AppleSDGothicNeo.ttc'
    title = ImageFont.truetype(font_path, 32)
    label = ImageFont.truetype(font_path, 21)
    board = Image.new('RGB', (1600, 1680), '#12232b')
    draw = ImageDraw.Draw(board)
    draw.text((25, 15), '비슷했던 중간 슬롯 → 다른 체형으로 교체', font=title, fill='#e6f3ed')
    draw.text((25, 59), '실제 Godot 렌더 · 각 쌍의 왼쪽: 이전 / 오른쪽: 교체 후 · 대표 8종', font=label, fill='#a5c9ca')
    for i, (identity, name) in enumerate(SPECIMENS):
        form = forms[identity]
        record = json.loads((BASE / 'render-records' / (identity + '.json')).read_text())
        if record.get('model_sha256') != form['lods']['near']['sha256'] or record.get('failures') or not motion_matches(record, form):
            raise RuntimeError('Before/after comparison needs a current passing capture: ' + identity)
        x = (i % 2) * 800
        y = 104 + (i // 2) * 390
        for j, folder in enumerate([BEFORE / 'game', BASE / 'game']):
            picture = Image.open(folder / (identity + '.png')).convert('RGB')
            picture.thumbnail((395, 332))
            board.paste(picture, (x + j * 400 + (400 - picture.width) // 2, y))
        draw.text((x + 14, y + 336), name + '  ·  ' + identity.removeprefix('biota_'), font=label, fill='#c4eeec')
    destination = BASE / 'midpoints' / 'before-after-game.jpg'
    board.save(destination, quality=95)
    print(destination)


if __name__ == '__main__':
    main()
