#!/usr/bin/env python3
"""Collect only completed native-game benchmark runs, retaining their raw measurements."""
import argparse
import hashlib
import json
from pathlib import Path


def duration(seconds):
    value = round(seconds)
    return f"{value // 60}분 {value % 60:02d}초"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("solo", type=Path)
    parser.add_argument("duo", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    results = []
    for expected, folder in enumerate((args.solo, args.duo), 1):
        data = json.loads((folder / "benchmark.json").read_text())
        if data.get("diagnostic") or not data.get("completed") or data.get("failures") or not data.get("valid_save"):
            raise SystemExit(f"Incomplete or failed benchmark: {folder}")
        if data["players"] != expected or data.get("t3_tier") != 3:
            raise SystemExit(f"Unexpected benchmark endpoint: {folder}")
        world = json.loads((folder / "world.json").read_text())
        factories = [building for site in world["business"]["sites"].values()
                     for building in site["buildings"].values()
                     if building["type"] == "factory" and building["tier"] == 3]
        if not factories or world["business"]["credits"] != data["credits"]:
            raise SystemExit(f"Saved progression does not match measurements: {folder}")
        data["saved_mk3_factories"] = [building["id"] for building in factories]
        conditions = {"seed": world["manifest"]["seed"], "settings": world["manifest"]["settings"]}
        data["generation_conditions"] = conditions
        if world["crew"]["landing"].get("body_id") != world["location"] or not world["location"].endswith(":planet:356688"):
            raise SystemExit(f"Saved character did not land at the measured T3 destination: {folder}")
        data["condition_hash"] = hashlib.sha256(json.dumps(conditions, sort_keys=True).encode()).hexdigest()
        data["raw_total"] = sum(data["mined"].values())
        data["ship_transactions"] = sum(row["kind"] in ("withdraw", "deposit") for row in data["transfers"])
        data["warehouse_transactions"] = sum(row["kind"].startswith("business_") for row in data["transfers"])
        data["milestone_intervals"] = {}
        previous = 0.0
        for mark in ("first_landing", "factory_mk2", "metal_freight_ready", "cold_landing",
                     "mk3_parts_ready", "blueprint_acquired", "factory_mk3", "t3_landing"):
            value = data["marks"][mark]
            if value < previous:
                raise SystemExit(f"Out-of-order milestone {mark}: {folder}")
            data["milestone_intervals"][mark] = value - previous
            previous = value
        results.append(data)
    if results[0]["condition_hash"] != results[1]["condition_hash"]:
        raise SystemExit("World generation conditions differ")
    args.output.mkdir(parents=True, exist_ok=True)
    for data in results:
        (args.output / f"players-{data['players']}.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    a, b = results
    rows = [("첫 행성 착륙", *[duration(d["marks"]["first_landing"]) for d in results]),
            ("제작소 Mk.2", *[duration(d["marks"]["factory_mk2"]) for d in results]),
            ("금속 거점 선적 준비", *[duration(d["marks"]["metal_freight_ready"]) for d in results]),
            ("T2 저온 거점 첫 착륙", *[duration(d["marks"]["cold_landing"]) for d in results]),
            ("Mk.3 가공 부품 준비", *[duration(d["marks"]["mk3_parts_ready"]) for d in results]),
            ("정거장 제작소 설계도 구매", *[duration(d["marks"]["blueprint_acquired"]) for d in results]),
            ("T3 제작소 해금·설치", *[duration(d["marks"]["factory_mk3"]) for d in results]),
            ("생산 준비 후 T3 첫 착륙", *[duration(d["marks"]["t3_landing"]) for d in results]),
            ("공동 크레딧 사용", *[f"{6000 - d['credits']:,.0f} Cr" for d in results]),
            ("공동 크레딧 잔액", *[f"{d['credits']:,.0f} Cr" for d in results]),
            ("추가 채집 원료", *[str(d["raw_total"]) for d in results]),
            ("성간 경유", *[str(len(d["flights"])) for d in results]),
            ("선박 화물 입출고 명령", *[str(d["ship_transactions"]) for d in results])]
    print("| 항목 | 1인 | 2인 |\n| --- | ---: | ---: |")
    for row in rows:
        print("| " + " | ".join(row) + " |")
    saved = a["marks"]["t3_landing"] - b["marks"]["t3_landing"]
    print(f"\nT3 도달 차이: {saved:.2f}초 ({saved / a['marks']['t3_landing'] * 100:.2f}%)")


if __name__ == "__main__":
    main()
