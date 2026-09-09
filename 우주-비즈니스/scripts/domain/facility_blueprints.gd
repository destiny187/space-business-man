class_name FrontierFacilityBlueprints
extends RefCounted
## Host-internal bridge. Exploration/station content registers licenses; no grant RPC.
static func definitions() -> Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string("res://data/facility_blueprints.json"))
static func required(row: Dictionary,next_tier: int) -> String:
 for id in definitions():
  if definitions()[id].building==row.get("type","") and int(definitions()[id].tier)==next_tier:return id
 return str(row.get("blueprint_id","")) if next_tier>=3 else ""
static func owned(world: Dictionary,id: String) -> bool:
 if not world.get("manifest",{}).get("settings",{}).has("regional_rules"):return true
 return id.is_empty() or world.get("expedition_research",{}).get("licenses",{}).has(id)
static func reason(world: Dictionary,row: Dictionary,next_tier: int) -> String:
 var id:=required(row,next_tier)
 return "" if owned(world,id) else "Mk.%d 설계도가 필요합니다. 공동 원정 설계도 보유 상태를 확인하세요."%next_tier
static func register(world: Dictionary,id: String,source: String,reference: String) -> bool:
 if not definitions().has(id) or source not in ["exploration","station"] or reference.is_empty() or reference.length()>160:return false
 FrontierExpeditionResearch.ensure(world)
 if world.expedition_research.licenses.has(id):return false
 world.expedition_research.licenses[id]={"source":source,"reference":reference};return true
static func valid(id: String,value: Variant) -> bool:
 return definitions().has(id) and value is Dictionary and value.size()==2 and value.get("source") in ["exploration","station"] and value.get("reference") is String and not value.reference.is_empty() and value.reference.length()<=160
static func public_view(world: Dictionary) -> Array:
 var result: Array=[]
 for id in definitions():
  if owned(world,id):result.append(id)
 return result
