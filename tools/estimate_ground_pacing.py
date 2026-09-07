#!/usr/bin/env python3
"""문서용 시간 예산 계산. 게임/저장을 실행하거나 수정하지 않는다."""
import json
import math
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "우주-비즈니스" / "data"


def read(name):
    return json.loads((DATA / name).read_text())


def main():
    catalog, cfg = read("catalog.json"), read("expedition_business.json")
    equipment = read("equipment.json")["items"]
    counts = dict(solar=2, charger=1, factory=1, atmosphere=1,
                  thermal=1, water=1, biolab=1)
    costs = Counter(catalog["robots"]["miner"]["cost"])
    for key, count in counts.items():
        for resource, amount in catalog["buildings"][key]["cost"].items():
            costs[resource] += count * amount
    print("현재 기본 시설 8개+로봇 1대 재료:", dict(costs))
    for key in ("miner_1", "miner_2"):
        tool = equipment[key]
        print(key, "이론 채집량/초:", round(tool["amount"] / tool["interval"], 3))
    power = [catalog["buildings"][k]["power"] * n for k, n in counts.items()]
    print("현행 주간/상수 공급, 수요:", 2 - sum(min(0, p) for p in power),
          sum(max(0, p) for p in power))
    products = read("production_tier2.json")["products"]
    recipe = Counter(reinforced_frame=6, control_circuit=2,
                     heat_transfer_unit=2, refined_copper=4)
    processing = 0
    for key in ("reinforced_frame", "control_circuit", "heat_transfer_unit",
                "refined_iron", "refined_copper"):
        amount = recipe.pop(key, 0)
        product = products[key]
        batches = math.ceil(amount/product["amount"])
        processing += batches * product["seconds"]
        for resource, count in product["cost"].items():
            recipe[resource] += batches * count
    print("제안 로버 원광 등가량:", dict(recipe),
          "부품/본체 포함 시간:", processing, processing+45)
    print("현행 환경: 모든 설비 동시 가동 후 기본 계약 환경/생태 충족 추정(분)")
    # Constant rates, sufficient power and ice; excludes build times, T2
    # salinity/soil, upgrades, network/tick jitter and any player actions.
    for name, env in read("planet_diversity.json")["archetypes"].items():
        if env["kind"] in ("gas_giant", "ice_giant"):
            continue
        threshold = cfg["contract_environment_minimum"]
        air = max(
            max(0, abs(env["oxygen"] - .21) - (100-threshold)/500) / cfg["oxygen_rate"],
            max(0, abs(env["pressure"] - 1) - (100-threshold)/110) / cfg["pressure_rate"],
            max(0, env["toxicity"] - (100-threshold)) / cfg["toxicity_rate"])
        heat = max(0, abs(env["temperature"]-18)-(100-threshold)/1.7) / cfg["thermal_rate"]
        water = math.ceil(max(0, threshold/1.5-env["water"])/cfg["water_per_ice"]) * cfg["water_cycle_seconds"]
        tail = max(cfg["contract_ecology_minimum"]/cfg["biolab_rate"],
                   cfg["contract_stable_seconds"])
        print(name, round((max(air, heat, water)+tail)/60, 2))

    # Proposed budgets in minutes. Appropriate-tier mandatory equipment is
    # already included. Research is an additional bonus, never a second Mk.2.
    # setup, manual/handling, travel, decisions, production, residual environment,
    # final stability, return. Only the environment overlaps the field block.
    budgets = [
        (3, 4.8, 2, 2.2, 1, 5.2, .5, 1),
        (4, 8, 5, 3, 4, 10, 1, 1.5),
        (5, 12, 7, 5, 8, 18, 1.5, 2),
        (6, 18, 10, 7, 12, 27, 2, 2),
        (7, 24, 14, 9, 18, 40, 2, 3),
    ]
    # setup skill, gathering factor, travel factor, decision skill, process factor
    profiles = {"첫 경험": (.8, .8, .85, .8, 1),
                "기본": (1, 1, 1, 1, 1),
                "연구+숙련": (1.2, 1.5*1.2, 1.2*1.2, 1.5, 1.5)}
    print("제안 시간 예산 — 실측 아님")
    for tier, (o, h, v, d, p, e, s, r) in enumerate(budgets, 1):
        values = {}
        for name, (skill, gather, move, decide, process) in profiles.items():
            field = h/gather + v/move + d/decide + p/process
            values[name] = round(o/skill + max(field, e/process) + s + r/move, 2)
        print("T"+str(tier), values)
    print("T1 수동/취급 4.8분 근거: 770/(5*0.65)/60 + 0.85 =",
          round(770/(equipment["miner_1"]["amount"]/equipment["miner_1"]["interval"]*.65)/60+.85, 2))
    for distance in (20, 30, 40):
        cycle = cfg["robot_capacity"]/cfg["robot_mine_amount"] + 2*distance/catalog["robots"]["miner"]["speed"] + 2
        print("기본 로봇 편도", distance, "m 순생산/초(충전 제외):", round(cfg["robot_capacity"]/cycle, 2))


if __name__ == "__main__":
    main()
