class_name FrontierOrbitalTerraform
extends RefCounted
## Read-only orbital presentation derived from committed business records, including old saves.
static var _rules: Dictionary={}
var cache: Dictionary={}
static func config() -> Dictionary:
	if _rules.is_empty():_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/orbital_terraforming.json"))
	return _rules
func summaries(world: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for id in world.get("business",{}).get("sites",{}):
		var site: Dictionary=world.business.sites[id]
		var stamp: String=str([world.manifest.id,site.get("state",""),site.get("time",0),site.get("free_terraform",{}).get("revision",0),site.get("settlement",{})])
		if not cache.has(id) or cache[id].stamp!=stamp:
			var body:=FrontierUniverse.body_from_id(world.manifest,id)
			cache[id]={"stamp":stamp,"summary":describe(body,site)}
		if not cache[id].summary.is_empty():result[id]=cache[id].summary
	for id in cache.keys():
		if not world.get("business",{}).get("sites",{}).has(id):cache.erase(id)
	return result
static func describe(body: Dictionary,site: Dictionary) -> Dictionary:
	if not FrontierUniverse.landable(body) or site.is_empty():return {}
	var completed: bool=not site.get("settlement",{}).is_empty()
	if not completed and site.get("state","")!="active":return {}
	var extent: float=site.get("free_terraform",{}).get("rules",{}).get("extent",config().legacy_extent)
	var air_cells: Array=[];var air_size: Array=[1,1]
	if FrontierFreeTerraform.active(site):
		var f: Dictionary=site.free_terraform
		air_size=[int(f.rules.air_columns),int(f.rules.air_rows)]
		var base: Dictionary=f.base.duplicate();var original:=float(FrontierEvaluator.scores(base).atmosphere)/100
		for index in f.air.size():
			var air: Array=f.air[index];base.oxygen=air[0];base.pressure=air[1];base.toxicity=air[2]
			var quality:=float(FrontierEvaluator.scores(base).atmosphere)/100
			if quality>original+.01:air_cells.append([index,snappedf(quality,.01),snappedf(clampf((quality-original)/.4,0,1),.01)])
	var samples: Array=[]
	if FrontierFreeTerraform.active(site):
		for cell in site.free_terraform.cells.values():
			if cell.get("treated",false):samples.append(cell)
	elif FrontierRegionalTerraform.enabled(site):
		for region in site.regions.values():samples.append_array(region.get("cells",[]))
	else:samples.append({"position":site.center,"environment":site.environment,"restoration2":site.get("restoration2",{})})
	# JSON saves sort dictionary keys; stable spatial ordering keeps the same sums after reload.
	samples.sort_custom(func(a: Dictionary,b: Dictionary):return float(a.position[0])<float(b.position[0]) if not is_equal_approx(float(a.position[0]),float(b.position[0])) else float(a.position[2])<float(b.position[2]))
	var groups: Dictionary={}
	for cell in samples:
		var e: Dictionary=cell.environment.duplicate();e.merge(cell.get("restoration2",{}),true)
		e.toxicity=maxf(float(e.get("toxicity",0)),float(cell.get("pollution",0)))
		var state:=FrontierSurfaceRecovery.conditions(e)
		if not completed and float(e.get("ecology",0))<=0 and not cell.get("treated",false):continue
		var p:=Vector2(float(cell.position[0]),float(cell.position[2]))
		var lon:=p.x/extent*PI;var sy:=clampf(p.y/extent,-1,1)
		var ring:=sqrt(maxf(0,1-sy*sy));var direction:=Vector3(sin(lon)*ring,sy,cos(lon)*ring)
		var key:=clampi(floori((sy+1)*2),0,3)*4+posmod(floori((lon+PI)/TAU*4),4)
		if not groups.has(key):groups[key]={"points":[],"sum":Vector3.ZERO,"green":0.0,"wet":0.0,"air":0.0,"temperature":0.0}
		var group: Dictionary=groups[key]
		group.points.append(direction);group.sum+=direction
		group.green+=maxf(float(state.grass),float(state.life));group.wet+=float(state.wet)
		group.air+=float(FrontierEvaluator.scores(e).atmosphere)/100;group.temperature+=float(e.temperature)
	var patches: Array=[]
	var group_keys:=groups.keys();group_keys.sort()
	for key in group_keys:
		var group: Dictionary=groups[key];var count:=float(group.points.size());var center: Vector3=group.sum.normalized()
		var radius:=float(config().minimum_visible_radius)
		for point in group.points:radius=maxf(radius,center.angle_to(point)+.02)
		patches.append({"point":[center.x,center.y,center.z,radius],"values":[snappedf(group.green/count,.01),snappedf(group.wet/count,.01),snappedf(group.temperature/count,.5),snappedf(group.air/count,.01)]})
	if patches.is_empty() and air_cells.is_empty():return {}
	return {"version":1,"completed":completed,"patches":patches,"air_size":air_size,"air_cells":air_cells}
