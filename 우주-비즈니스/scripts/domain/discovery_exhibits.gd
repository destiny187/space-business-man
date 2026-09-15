class_name FrontierDiscoveryExhibits
extends RefCounted
## Static authored replicas use shared research and ordinary paid field construction.
static var _config: Dictionary={}
static var _projects: Dictionary={}
static var _buildings: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/discovery_exhibits.json"))
 return _config
static func is_exhibit(kind: String) -> bool:return config().items.has(kind)
static func buildings() -> Dictionary:
 if _buildings.is_empty():
  for key in config().items:
   var d: Dictionary=config().items[key]
   _buildings[key]={"name":d.name,"model":d.model,"tier":1,"tech":"","power":0,"radius":d.radius,"cost":d.cost,"description":d.description}
 return _buildings
static func projects() -> Dictionary:
 if _projects.is_empty():
  for key in config().items:
   var d: Dictionary=config().items[key]
   _projects[key]={"name":d.name+" 설계","model":d.model,"price":d.price,"cost":d.research_cost,"effect":d.description+"\n연구 후 B → 발견 장식에서 배낭 재료로 제작하고 배치합니다.","discoveries":[d.template],"source":d.source}
 return _projects
static func usage(template: String,source: String,finished: bool,studied: bool=false) -> String:
 var d: Dictionary=config().items.get("exhibit_"+template,{})
 if d.is_empty() or d.source!=source:return ""
 var utility:=""
 for project in FrontierDiscoveryUtilities.config().projects.values():
  if template in project.discoveries:utility="실용 설비  "+str(project.name)+"\n"+str(project.effect)+"\n조사 완료 후 착륙선 F → 연구 → 공동 설비 → 설비에서 별도 연구"
 return (utility+"\n\n" if not utility.is_empty() else "")+"현재 전시 활용\n"+str(d.use)+"\n\n연구 후 장식  "+str(d.name)+"\n"+("전시 설계 연구 완료  " if studied else "조사 완료  " if finished else "조사 완료 필요  ")+"착륙선 F → 연구 → 공동 설비 → 발견 장식\n연구 후 B → 발견 장식에서 제작 / 배치\n전시용 복제품  생산 / 능력치 효과 없음"
