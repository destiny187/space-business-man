extends RefCounted
static var fallback: float=0.0
static func extent(body: Dictionary) -> float:
 if fallback<=0:fallback=float(JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json")).region_half_extent)
 return float(body.get("mineral_profile",{}).get("rules",{}).get("region_half_extent",fallback))
static func identity_cells(body: Dictionary) -> int:
 # Keep the old edge identity margin, including already recorded observations.
 return ceili(extent(body)/float(FrontierEcologyCatalog.placement_config(body).cell_span))
