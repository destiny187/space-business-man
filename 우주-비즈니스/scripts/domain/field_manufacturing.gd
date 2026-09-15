class_name FrontierFieldManufacturing
extends RefCounted
static var _config: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/field_manufacturing.json"))
 return _config
static func station(product_id: String) -> String:
 return "metalworks" if product_id in config().metal_products else "factory"
static func equipment_reason(member: Dictionary,site: Dictionary) -> String:
 if member.get("area","")!="surface" or member.get("aboard",false):return "지상 장비 제작대에서 제작하세요."
 var position:=FrontierCrewWorld.vector(member.position)
 for row in site.get("buildings",{}).values():
  if row.type!="equipment_workbench" or position.distance_to(FrontierCrewWorld.vector(row.position))>float(config().interaction_distance):continue
  if not row.get("enabled",true) or row.get("submerged",false) or not row.get("active",false):continue
  return ""
 return "장비 제작대를 짓고 F로 사용하세요."
