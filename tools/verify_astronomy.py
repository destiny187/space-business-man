#!/usr/bin/env python3
"""Verify frozen provenance and normalization without contacting the archive."""
import hashlib
import json
from pathlib import Path
from import_astronomy import normalize

root = Path(__file__).resolve().parents[1] / "우주-비즈니스/data/astronomy"
for directory in sorted(root.iterdir()):
    catalog = json.loads((directory / "catalog.json").read_text())
    raw = (directory / "raw.json").read_bytes()
    assert catalog["version"] == directory.name
    assert hashlib.sha256(raw).hexdigest() == catalog["raw_sha256"]
    assert normalize(json.loads(raw)) == catalog["records"]
    assert catalog["source_url"].startswith("https://exoplanetarchive.ipac.caltech.edu/TAP/sync?")
    for record in catalog["records"]:
        assert record["surface_map"] is None and record["life_observed"] is None
        assert record["references"]["pl_refname"]
        assert record["values"]["equilibrium_temperature"]["unit"] == "K"
    print(f"ASTRONOMY_VERIFIED {directory.name}: {len(catalog['records'])} published records, original hash, uncertainties and nulls")
