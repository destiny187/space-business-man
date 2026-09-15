class_name FrontierDiscoveryUtilities
extends RefCounted
static var _config: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/discovery_utilities.json"))
 return _config
static func building(kind: String) -> bool:return config().buildings.has(kind)
static func specimen_allowed(key: String) -> bool:
 var sample:=FrontierSpecimenItems.decode(key)
 if sample.is_empty():return false
 var form:=FrontierEcologyCatalog.form(sample.form_id)
 return form.get("category","")=="microbe" and form.get("environment","") in config().tank.environments
static func conditions(site: Dictionary,b: Dictionary) -> Dictionary:
 if b.type!="luminous_vivarium":return {"ready":true,"reason":"사용 가능"}
 if b.get("specimen_stock",{}).is_empty():return {"ready":false,"reason":"F에서 온대 / 습지 / 해양 미생물 표본 넣기"}
 var t:=float(site.environment.temperature)
 if t<float(config().tank.minimum_temperature) or t>float(config().tank.maximum_temperature):return {"ready":false,"reason":"배양 온도 0~55°C 필요  현재 %.0f°C"%t}
 return {"ready":true,"reason":"발광 배양 가능"}
static func apply(world: Dictionary,actor: String,args: Dictionary) -> String:
 var site:=FrontierExpeditionBusiness.site(world);var b: Dictionary=site.get("buildings",{}).get(str(args.get("building_id","")),{})
 if b.is_empty() or not building(str(b.get("type",""))):return "발견 실용 설비를 선택하세요."
 if FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(b.position))>8:return "설비 8m 이내로 접근하세요."
 var action:=str(args.get("action",""))
 if action=="mute" and b.type in ["resonance_garden","flood_sentinel"]:b.muted=not b.get("muted",false);return ""
 if action=="tone" and b.type=="resonance_garden":b.resonance_tone=(int(b.get("resonance_tone",1))+1)%3;return ""
 if b.type!="luminous_vivarium":return "이 설비에서 지원하지 않는 조작입니다."
 if action=="install":
  if not b.get("specimen_stock",{}).is_empty():return "먼저 기존 표본을 회수하세요."
  var key:=str(args.get("specimen",""))
  if not specimen_allowed(key):return "실제 온대, 습지 또는 해양 미생물 표본이 필요합니다."
  var stock:=FrontierExpeditionBusiness.bag(world,actor)
  if int(stock.get(key,0))!=1:return "선택한 표본이 내 배낭에 없습니다."
  stock.erase(key);b.specimen_stock={key:1};return ""
 if action=="remove":
  var stock: Dictionary=b.get("specimen_stock",{})
  if stock.is_empty():return "회수할 표본이 없습니다."
  var key: String=stock.keys()[0]
  if FrontierItemInventory.room(world,actor,key)<1:return "표본을 받을 배낭 공간이 필요합니다."
  world.business.bags[actor][key]=1;b.specimen_stock={};b.working=false;b.active=false;return ""
 return "표본 넣기 또는 회수를 선택하세요."
static func wet_targets(buildings: Dictionary,b: Dictionary,wet: Callable) -> String:
 var at:=FrontierCrewWorld.vector(b.position);var radius:=float(config().alarm.radius)
 for id in buildings:
  var other: Dictionary=buildings[id]
  if other.id==b.id or FrontierDiscoveryExhibits.is_exhibit(str(other.type)):continue
  var p:=FrontierCrewWorld.vector(other.position)
  if Vector2(p.x-at.x,p.z-at.z).length()>radius:continue
  # A wet foundation is already at risk before full-roof immersion stops a facility.
  if wet.call(p+Vector3.UP*.1):return str(id)
 return ""
static func tick(world: Dictionary,site: Dictionary,dt: float) -> void:
 for b in site.buildings.values():
  if not building(b.type):continue
  b.working=b.active
  if b.type=="shell_refuge":
   if b.active:b.status="지붕 아래 강우 보호"
   continue
  if b.type=="luminous_vivarium":
   if b.active:b.status="발광 중  조명 반경 10m"
   continue
  if b.type=="resonance_garden":
   b.working=b.active and not b.get("muted",false)
   if b.active:b.status="소리 꺼짐" if b.get("muted",false) else "공명 중  음높이 %d"%(int(b.get("resonance_tone",1))+1)
   continue
  if not b.active:b.alarm_target="";continue
  b.utility_elapsed=float(b.get("utility_elapsed",0))+dt
  if b.utility_elapsed<float(config().alarm.interval):continue
  b.utility_elapsed=0.
  var field:=FrontierCrewSurface.field(world);var record: Dictionary=world.get("surface_water",{}).get(world.location,{})
  var native:=FrontierSurfaceDrainage.liquid(field.traits)
  b.alarm_target=wet_targets(site.get("utility_neighbors",site.get("placement_neighbors",site.buildings)),b,func(p: Vector3):return FrontierFacilityFlooding.wet_at(p,record,field,native,-4.))
  b.status="감시 중  기초 침수 없음" if b.alarm_target.is_empty() else "기초 침수 감지  "+str(FrontierCatalog.entry("buildings",site.get("utility_neighbors",site.get("placement_neighbors",site.buildings))[b.alarm_target].type).name)
  if b.get("muted",false):b.status+="  경고음 꺼짐"
static func valid(b: Dictionary) -> bool:
 if not building(str(b.get("type",""))):return not b.has("specimen_stock")
 if not b.get("muted",false) is bool or not FrontierExpeditionBusiness.integer(b.get("resonance_tone",1),0,2):return false
 if not FrontierUniverse._finite(b.get("utility_elapsed",0),0,10) or not b.get("alarm_target","") is String:return false
 var stock: Variant=b.get("specimen_stock",{})
 if not stock is Dictionary or stock.size()>1:return false
 for key in stock:
  if b.type!="luminous_vivarium" or not key is String or not specimen_allowed(key) or stock[key]!=1:return false
 return true
