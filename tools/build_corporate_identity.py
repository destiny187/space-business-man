"""Export corporate vector marks, outlined signatures and their review board.

Uses only Python's standard library. Does not edit game assets or Blender models.
The four SVG masters and identity.json are the editable source of truth.
"""
from copy import deepcopy
from html import escape
from pathlib import Path
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/branding/corporations"
OUTPUT = SOURCE / "exports"
BOARD = ROOT / "docs/game/media/corporations/company-symbols-v1.svg"
NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", NS)

# Original geometric lettering, stored as vector strokes rather than font text.
# Widths include optical adjustments; strokes remain editable and font independent.
GLYPHS = {
    "L": (34, "M4 0V44H32"),
    "O": (38, "M12 0H26Q35 0 35 10V34Q35 44 26 44H12Q3 44 3 34V10Q3 0 12 0Z"),
    "T": (38, "M1 0H37M19 0V44"),
    "U": (38, "M3 0V33Q3 44 14 44H24Q35 44 35 33V0"),
    "S": (37, "M34 4Q31 0 24 0H12Q3 0 3 10Q3 20 12 21L25 23Q34 24 34 34Q34 44 25 44H12Q5 44 2 40"),
    "P": (37, "M4 44V0H25Q34 0 34 11Q34 22 25 22H4"),
    "A": (40, "M2 44L17 0H23L38 44M8 29H32"),
    "C": (38, "M35 4Q32 0 25 0H13Q3 0 3 11V33Q3 44 13 44H25Q32 44 35 40"),
    "E": (35, "M32 0H4V44H32M4 21H27"),
    "Y": (40, "M1 0L20 24L39 0M20 24V44"),
    "I": (8, "M4 0V44"),
    "m": (54, "M4 44V9M4 20Q4 8 15 8Q27 8 27 20V44M27 20Q27 8 39 8Q50 8 50 20V44"),
    "i": (12, "M6 16V44M6 0V1"),
    "n": (34, "M4 44V9M4 20Q4 8 17 8Q30 8 30 20V44"),
    "e": (36, "M4 26H32V21Q32 8 18 8Q4 8 4 22V31Q4 44 18 44Q28 44 32 39"),
}


def mark(source, variant):
    root = ET.parse(source).getroot()
    group = root.find(f"{{{NS}}}g[@id='{variant}']")
    if group is None:
        raise ValueError(f"Missing {variant} in {source}")
    group = deepcopy(group)
    group.attrib.pop("display", None)
    group.attrib.pop("id", None)
    # No fragment IDs are needed in exported marks; copies can coexist freely.
    text = ET.tostring(group, encoding="unicode")
    return text.replace(f' xmlns="{NS}"', "")


def svg(width, height, content, title):
    return (f'<svg xmlns="{NS}" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}" role="img" aria-label="{escape(title)}">\n'
            f'<title>{escape(title)}</title>\n{content}\n</svg>\n')


def lettering(company):
    pieces = []
    offset = 0
    for letter in company["wordmark"]:
        if letter == " ":
            offset += 24
            continue
        width, path = GLYPHS[letter]
        pieces.append(f'<path transform="translate({offset} 0)" d="{path}"/>')
        offset += width + company["tracking"]
    width = offset - company["tracking"] + 8
    return (f'<g fill="none" stroke="currentColor" stroke-width="6.5" '
            f'stroke-linecap="square" stroke-linejoin="round">{"".join(pieces)}</g>', width)


def main():
    cfg = json.loads((SOURCE / "identity.json").read_text())
    drawings = []
    outputs = []
    for company in cfg["companies"]:
        primary = mark(SOURCE / company["source"], "primary")
        compact = mark(SOURCE / company["source"], "compact")
        word, word_width = lettering(company)
        folder = OUTPUT / company["id"]
        folder.mkdir(parents=True, exist_ok=True)
        for name, variant, color in (
            ("primary", primary, company["color"]),
            ("positive", primary, cfg["ink_positive"]),
            ("reverse", primary, cfg["ink_reverse"]),
            ("compact", compact, company["color"]),
            ("compact-positive", compact, cfg["ink_positive"]),
            ("compact-reverse", compact, cfg["ink_reverse"]),
        ):
            target = folder / f"{name}.svg"
            target.write_text(svg(256, 256, f'<g color="{color}">{variant}</g>', f'{company["name"]} {name}'))
            outputs.append(str(target.relative_to(ROOT)))
        signature = (f'<g color="{cfg["ink_positive"]}">'
                     f'<g transform="translate(8 8) scale(.5)">{primary}</g>'
                     f'<g transform="translate(159 48)">{word}</g></g>')
        target = folder / "signature.svg"
        target.write_text(svg(round(176 + word_width), 144, signature, company["name"] + " signature"))
        outputs.append(str(target.relative_to(ROOT)))
        drawings.append((company, primary, compact, word, word_width))

    # Design review sheet; neutral flat color makes the actual contours inspectable.
    w, h = 1600, 1010
    parts = [
        '<rect width="1600" height="1010" fill="#112128"/>',
        '<g font-family="Noto Sans KR, Apple SD Gothic Neo, sans-serif">',
        '<text x="56" y="56" fill="#AEC3C8" font-size="18" letter-spacing="3">SPACE BUSINESS MAN / IDENTITY SYSTEM 01</text>',
        '<text x="56" y="114" fill="#F1F0E9" font-size="38" font-weight="600">네 회사, 네 가지 형태 언어</text>',
        '<text x="1544" y="111" fill="#AEC3C8" text-anchor="end" font-size="21">VECTOR MASTERS · 2026.09.10</text>',
        '<path d="M56 143H1544" stroke="#38515A"/>',
    ]
    for index, (company, primary, compact, word, word_width) in enumerate(drawings):
        left = 56 + index * 376
        center = left + 180
        color = company["color"]
        if index:
            parts.append(f'<path d="M{left-8} 178V598" stroke="#2D434C"/>')
        parts.extend([
            f'<text x="{left+8}" y="192" fill="#AEC3C8" font-size="18">0{index+1} / {escape(company["name"])}</text>',
            f'<g transform="translate({center-115} 217) scale(.9)" color="{color}">{primary}</g>',
        ])
        scale = min(1.04, 292 / word_width)
        x = center - word_width * scale / 2 + 4
        parts.extend([
            f'<g transform="translate({x:.3f} 479) scale({scale:.4f})" color="#F1F0E9">{word}</g>',
            f'<text x="{center}" y="566" text-anchor="middle" fill="#D6E1DE" font-size="23">{company["role_ko"]}</text>',
            f'<text x="{center}" y="601" text-anchor="middle" fill="#AEC3C8" font-size="20">{company["concept_ko"]}</text>',
        ])
    parts.extend([
        '<path d="M56 639H1544" stroke="#38515A"/>',
        '<text x="56" y="678" fill="#AEC3C8" font-size="20">작은 표시 · 24 / 32 / 48 px</text>',
    ])
    for index, (company, primary, compact, word, word_width) in enumerate(drawings):
        left = 56 + index * 376
        for size, shift in ((24, 104), (32, 157), (48, 221)):
            parts.append(f'<g transform="translate({left+shift} {716-size/2}) scale({size/256})" color="{company["color"]}">{compact}</g>')
    parts.extend([
        '<rect x="56" y="762" width="1488" height="173" fill="#ECEDE5"/>',
        '<text x="80" y="798" fill="#455D63" font-size="19">단색 각인용</text>',
    ])
    for index, (company, primary, compact, word, word_width) in enumerate(drawings):
        center = 236 + index * 376
        parts.append(f'<g transform="translate({center-45} 816) scale(.35)" color="#14242B">{primary}</g>')
    parts.extend([
        '<text x="56" y="980" fill="#AEC3C8" font-size="19">주형 ≥ 48 px · 소형 ≥ 24 px · 보호 여백 ≥ 24/256 · 심볼과 서명 모두 벡터</text>',
        '<text x="1544" y="980" text-anchor="end" fill="#AEC3C8" font-size="19">제작안 v1 / 3D·게임 적용 전</text>',
        '</g>',
    ])
    BOARD.parent.mkdir(parents=True, exist_ok=True)
    BOARD.write_text(svg(w, h, "\n".join(parts), "기업 심볼 제작안 v1"))
    (OUTPUT / "manifest.json").write_text(json.dumps({"version": cfg["version"], "generator": "tools/build_corporate_identity.py", "files": outputs, "board": str(BOARD.relative_to(ROOT))}, ensure_ascii=False, indent=2) + "\n")
    print(f"Generated {len(outputs)} SVGs and {BOARD.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
