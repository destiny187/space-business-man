"""A compact selection of actual game portraits; contains no invented preview art."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
IDS = [
    'biota_chain_antennal_fans_50', 'biota_saddle_sails_25', 'biota_ribbon_mandibles_39',
    'biota_spiral_siphons_50', 'biota_bilateral_antennal_fans_25', 'biota_amphora_gills_09',
    'biota_plant_basket_50', 'biota_plant_fenestrate_25', 'biota_plant_orchid_39',
    'biota_plant_floating_roots_09', 'biota_microbe_scroll_50', 'biota_microbe_lace_25',
]


def main():
    rows = json.loads((ROOT / '우주-비즈니스/data/bestiary/biota_forms.json').read_text())['forms']
    forms = {row['id']: row for row in rows}
    if len(forms) != 7000:
        raise RuntimeError('This sheet requires the complete published asset catalogue')
    font_path = str(ROOT / '우주-비즈니스/assets/fonts/NotoSansKR.ttf')
    title_font = ImageFont.truetype(font_path, 31)
    name_font = ImageFont.truetype(font_path, 18)
    detail_font = ImageFont.truetype(font_path, 14)
    board = Image.new('RGB', (1600, 1210), '#14262d')
    draw = ImageDraw.Draw(board)
    draw.text((26, 18), '행성 고유 생물 · 실제 게임 모델', font=title_font, fill='#d2eeea')
    draw.text((28, 65), '신규 7,000종 중 12종  /  동물 · 식물 · 미생물 군락  /  유형별 골격과 환경 적응 구조', font=name_font, fill='#9fbdc4')
    for index, id in enumerate(IDS):
        row = forms[id]
        x = (index % 4) * 400 + 12
        y = (index // 4) * 365 + 110
        draw.rounded_rectangle((x, y, x + 376, y + 348), radius=12, fill='#eeeede')
        im = Image.open(ROOT / '우주-비즈니스/assets/ui/previews' / (id + '.png')).convert('RGBA')
        im.thumbnail((376, 292))
        board.paste(im, (x + (376 - im.width) // 2, y + 2), im)
        draw.text((x + 14, y + 292), row['name'], font=name_font, fill='#233e40')
        category = {'animal': '동물', 'plant': '식물', 'microbe': '미생물 군락'}[row['category']]
        draw.text((x + 14, y + 319), category + ' · ' + row['environment_label'], font=detail_font, fill='#537071')
    destination = ROOT / 'docs/production/media/biota/selected-game-species.jpg'
    board.save(destination, quality=94)
    print(destination)


if __name__ == '__main__':
    main()
