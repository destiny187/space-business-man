class_name FrontierPlanetTraits
extends RefCounted
static var _rules: Dictionary={}
static func rules() -> Dictionary:
	if _rules.is_empty():_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_diversity.json"))
	return _rules
static func make(body: Dictionary,definition: Dictionary={}) -> Dictionary:
	var cfg: Dictionary=rules() if definition.is_empty() else definition
	var options: Array=[]
	for id in cfg.archetypes:
		if cfg.archetypes[id].kind==body.kind:options.append(id)
	options.sort()
	var seed_value: int=FrontierUniverse.derive(int(body.seed),"appearance-v1")
	var id: String=options[seed_value%options.size()]
	var result: Dictionary=cfg.archetypes[id].duplicate(true)
	result.id=id;result.version=cfg.version
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	for key in ["dust","rock"]:
		var color:=Color(result[key]);result[key]=Color.from_hsv(fposmod(color.h+rng.randf_range(-.025,.025),1),clampf(color.s*rng.randf_range(.85,1.15),0,1),clampf(color.v*rng.randf_range(.87,1.1),0,1)).to_html(false)
	result.water=clampf(float(result.water)+rng.randf_range(-5,5),0,100) if float(result.water)>0 else 0.0
	result.pressure=clampf(float(result.pressure)*rng.randf_range(.85,1.15),0,10)
	result.temperature=float(result.temperature)+rng.randf_range(-8,8)
	result.cloud=clampf(float(result.pressure)*.4,0,1)
	result.pattern_seed=float(seed_value%1048576)/1024.0
	result.relief=float(result.relief)*rng.randf_range(.85,1.15)
	return result
static func describe(body: Dictionary) -> String:
	var t: Dictionary=body.get("traits",{})
	if t.is_empty():return ""
	if not FrontierUniverse.landable(body):return t.name+" · 고체 지표 없음"
	if t.id=="volcanic":return "불타는 화산 · 냉각 후 고온 광맥 개방"
	var water: String="수자원 풍부" if float(t.water)>40 else ("수자원 일부" if float(t.water)>10 else "건조")
	var air: String="대기 양호" if float(t.oxygen)>=.15 and float(t.toxicity)<15 and float(t.pressure)>.6 else "대기 개선 필요"
	return t.name+" · "+water+" · "+air
