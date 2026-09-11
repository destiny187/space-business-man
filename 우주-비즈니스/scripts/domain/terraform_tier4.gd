extends RefCounted
## Paid thermal protection inside the persistent T4 source area.
static var cached: Dictionary={}
static func config() -> Dictionary:
 if cached.is_empty():cached=JSON.parse_string(FileAccess.get_file_as_string("res://data/terraforming_tier4.json"))
 return cached
static func active(site: Dictionary) -> bool:return int(site.get("free_terraform",{}).get("tier",0))==4 and site.has("tier3")
static func protected_machine(site: Dictionary,b: Dictionary) -> bool:
 return active(site) and b.type=="thermal" and FrontierFreeTerraform.in_pollution(site,Vector2(b.position[0],b.position[2]))
static func thermal_seconds(site: Dictionary,b: Dictionary,dt: float) -> float:
 if int(b.get("tier",1))<3:b.status="극한 구역: Mk.3 열교환 모듈 필요";return 0.0
 var rules: Dictionary=site.tier3.rules;var item: String=rules.profiles[site.tier3.profile].item
 var used:=FrontierTerraformTier3.fuel(site,b,item,dt,float(rules.treatment_pack_seconds))
 b.status="극한 열교환 중" if used>=dt else FrontierProductionTier2.product(item).name+" 보급 필요"
 return used
static func drift(site: Dictionary,dt: float) -> void:
 if not active(site):return
 var rules: Dictionary=site.tier3.rules;var profile: Dictionary=rules.profiles[site.tier3.profile]
 var budget:=float(rules.thermal_drift)*(1-float(site.tier3.suppression))*dt
 for cell in site.free_terraform.cells.values():
  if FrontierFreeTerraform.in_pollution(site,Vector2(cell.position[0],cell.position[2])):
   cell.environment.temperature=move_toward(float(cell.environment.temperature),float(profile.temperature),budget)
