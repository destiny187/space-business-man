"""Assemble unretouched Blender/Godot renders into reproducible review sheets."""
from pathlib import Path
import shutil
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "output/advanced-hulls"
DEST = ROOT / "docs/production/media/advanced-hulls"
DEST.mkdir(parents=True, exist_ok=True)
FONT = ROOT / "우주-비즈니스/assets/fonts/NotoSansKR.ttf"
BG = "#f8f4e6"
INK = "#15262c"
TEAL = "#247f7d"


def font(size):
    return ImageFont.truetype(str(FONT), size)


def lineup():
    sheet = Image.new("RGB", (1800, 1170), BG)
    d = ImageDraw.Draw(sheet)
    d.text((42, 25), "새 원정 선체 6종", font=font(40), fill=INK)
    d.text((43, 85), "Godot Forward+ · 실제 INK v1 렌더", font=font(23), fill=TEAL)
    for col, name in enumerate(["균형 탐사", "고속 탐사", "대형 적재"]):
        d.text((col * 600 + 42, 151), name, font=font(26), fill=INK)
    rows = [("aster", "peregrine", "ox"), ("orion", "spectre", "atlas")]
    for row, ids in enumerate(rows):
        for col, id in enumerate(ids):
            x, y = col * 600 + 22, row * 450 + 201
            image = Image.open(SOURCE / "ink" / f"{id}.png").convert("RGB")
            # Remove only the renderer's large blank margin and repeated captions.
            crop = image.crop((130, 285, 1310, 1020))
            sheet.paste(ImageOps.contain(crop, (556, 355)), (x, y))
            d.text((x + 20, y + 358), f"T{3 if row == 0 else 5}  {id.upper()}", font=font(28), fill=INK)
    d.text((43, 1124), "Blender 원본 · 방열판 / 노즐 / 센서 가동 · 실제 배기 소켓", font=font(21), fill=TEAL)
    sheet.save(DEST / "hull-lineup.png")


def blender_sheet():
    ids = ["aster", "peregrine", "ox", "orion", "spectre", "atlas", "combat_skill_emitter", "combat_decoy", "combat_mine"]
    sheet = Image.new("RGB", (1800, 1380), BG)
    d = ImageDraw.Draw(sheet)
    d.text((35, 15), "Blender Cycles · 원본 렌더 검수", font=font(33), fill=INK)
    for index, id in enumerate(ids):
        x, y = index % 3 * 600 + 15, index // 3 * 425 + 80
        im = Image.open(SOURCE / "blender" / f"{id}.png").convert("RGB")
        im = ImageOps.contain(im, (570, 365))
        sheet.paste(im, (x + (570 - im.width) // 2, y))
        d.text((x + 15, y + 370), id.upper(), font=font(21), fill=INK)
    sheet.save(DEST / "blender-sources.png")


if __name__ == "__main__":
    lineup()
    blender_sheet()
    for name in ["skills-960", "hulls-station", "multi-lock-flight", "lance-charging", "barrier-flight"]:
        shutil.copy2(SOURCE / "play" / f"{name}.png", DEST / f"{name}.png")
    print(DEST)
