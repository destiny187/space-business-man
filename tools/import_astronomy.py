#!/usr/bin/env python3
"""Freeze a small NASA PS catalogue. Runtime never calls the archive."""
import argparse
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ENDPOINT = "https://exoplanetarchive.ipac.caltech.edu/TAP/sync"
FIELDS = {
    "pl_rade": ("radius", "earth_radius"),
    "pl_bmasse": ("mass", "earth_mass"),
    "pl_orbper": ("orbital_period", "day"),
    "pl_eqt": ("equilibrium_temperature", "K"),
    "st_lum": ("stellar_log_luminosity", "log10_solar"),
    "sy_dist": ("distance", "pc"),
}
NAMES = ["TRAPPIST-1 d", "TRAPPIST-1 e", "TRAPPIST-1 f"]


def query(sql):
    url = ENDPOINT + "?" + urllib.parse.urlencode({"query": sql, "format": "json"})
    with urllib.request.urlopen(url, timeout=45) as response:
        return response.read(), url


def normalize(rows):
    result = []
    for row in rows:
        values = {}
        for field, (key, unit) in FIELDS.items():
            value = row.get(field)
            if value is not None and (not math.isfinite(value) or (field != "st_lum" and value <= 0)):
                raise ValueError(f"Invalid {field}: {row['pl_name']}")
            values[key] = {"value": value, "unit": unit, "source_field": field,
                           "err_plus": row.get(field + "err1"), "err_minus": row.get(field + "err2"),
                           "limit": row.get(field + "lim")}
        result.append({"id": "nasa_ps:" + row["pl_name"].lower().replace(" ", "_"),
                       "name": row["pl_name"], "host": row["hostname"],
                       "provenance": "published_parameters", "values": values,
                       "mass_provenance": row.get("pl_bmassprov"),
                       "coordinates": {"ra_deg": row["ra"], "dec_deg": row["dec"], "frame": "ICRS"},
                       "references": {key: row.get(key) for key in ["pl_refname", "st_refname", "sy_refname"]},
                       "surface_map": None, "life_observed": None})
    if sorted(r["name"] for r in result) != sorted(NAMES):
        raise ValueError("Expected one default PS row per selected planet")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True, help="New immutable snapshot directory, e.g. nasa-ps-20260906")
    args = parser.parse_args()
    if not args.version.replace("-", "").isalnum():
        parser.error("version must contain only letters, digits and hyphens")
    target = ROOT / "우주-비즈니스/data/astronomy" / args.version
    if target.exists():
        parser.error("snapshot exists; choose a new version rather than replacing it")
    schema_raw, _ = query("select column_name,unit from TAP_SCHEMA.columns where table_name='ps'")
    schema = json.loads(schema_raw)
    available = {item["column_name"] for item in schema}
    fields = ["pl_name", "hostname", "default_flag", "pl_bmassprov", "ra", "dec", "pl_refname", "st_refname", "sy_refname"]
    for field in FIELDS:
        fields.extend(key for key in [field, field + "err1", field + "err2", field + "lim"] if key in available)
    if not set(fields).issubset(available) or not set(FIELDS).issubset(fields):
        raise ValueError("Archive schema changed")
    names = ",".join("'" + name + "'" for name in NAMES)
    sql = f"select {','.join(fields)} from ps where default_flag=1 and pl_name in ({names}) order by pl_name"
    raw, url = query(sql)
    records = normalize(json.loads(raw))
    document = {"version": args.version, "normalizer_version": 1,
                "retrieved_at": dt.datetime.now(dt.timezone.utc).isoformat(),
                "source_url": url, "query": sql, "raw_sha256": hashlib.sha256(raw).hexdigest(),
                "selection": "PS default_flag=1, one published solution per planet; missing fields remain null",
                "acknowledgement": "NASA Exoplanet Archive, operated by Caltech under contract with NASA under the Exoplanet Exploration Program.",
                "citation_url": "https://exoplanetarchive.ipac.caltech.edu/docs/acknowledge.html",
                "records": records}
    target.mkdir(parents=True)
    (target / "raw.json").write_bytes(raw)
    (target / "schema.json").write_bytes(schema_raw)
    (target / "catalog.json").write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n")
    print(f"Frozen {len(records)} planets: {target}")


if __name__ == "__main__":
    main()
