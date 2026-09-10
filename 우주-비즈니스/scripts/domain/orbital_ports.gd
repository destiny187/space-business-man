class_name FrontierOrbitalPorts
extends RefCounted
## Explicit new-world solar exceptions. Fixed addresses, independently persisted inventories.
const BODIES := {"solar_mars_port":3,"solar_earth_logistics":2}
static func rules(m: Dictionary) -> Dictionary:return m.settings.get("corporate_space",{}).get("ports",{})
static func definition(m: Dictionary,id: String,elapsed: float) -> Dictionary:
	var cfg:=rules(m)
	if not cfg.get("sites",{}).has(id):return {}
	var row: Dictionary=cfg.sites[id]
	var body:=FrontierUniverse.body(m,int(row.body))
	var radius:=FrontierUniverse.navigation_radius(body)+float(row.clearance)
	var angle:=float(row.phase)+elapsed/float(row.period)*TAU
	var point:=FrontierUniverse.position(m,int(row.body),elapsed)+Vector3(cos(angle)*radius,float(row.altitude),sin(angle)*radius)
	return {"id":id,"name":row.name,"short_name":row.short_name,"system":0,"body":int(row.body),"operator":"space_y","seed":FrontierUniverse.derive(int(m.seed),id),"position":FrontierExpeditionBusiness.array(point),"model":"res://assets/models/ships/"+id+".glb","goods":row.goods,"sale_ratio":cfg.sale_ratio,"fixed_port":true}
static func all(m: Dictionary,elapsed: float) -> Array:
	var result: Array=[]
	for id in rules(m).get("sites",{}):result.append(definition(m,id,elapsed))
	return result
static func market(station: Dictionary) -> Dictionary:
	var stock: Dictionary={};var prices: Dictionary={};var capacities: Dictionary={}
	for id in station.goods:
		var row: Dictionary=station.goods[id]
		stock[id]=int(row.stock);prices[id]=int(row.price);capacities[id]=int(row.capacity)
	return {"stock":stock,"prices":prices,"capacities":capacities,"sale_ratio":station.sale_ratio}
static func valid(cfg: Variant) -> bool:
	if not cfg is Dictionary or cfg.get("version")!=1 or not cfg.get("sites") is Dictionary or cfg.sites.size()!=BODIES.size():return false
	if not FrontierUniverse._finite(cfg.get("sale_ratio"),.01,.9):return false
	for id in BODIES:
		var row: Variant=cfg.sites.get(id)
		if not row is Dictionary or row.get("body")!=BODIES[id] or not row.get("name") is String or not row.get("short_name") is String:return false
		for entry in [["clearance",2000,6000],["phase",0,TAU],["period",1200,10000],["altitude",0,2000]]:
			if not FrontierUniverse._finite(row.get(entry[0]),entry[1],entry[2]):return false
		if not row.get("goods") is Dictionary or row.goods.size()!=4:return false
		for item in ["iron","copper","stone","ice"]:
			var good: Variant=row.goods.get(item)
			if not good is Dictionary:return false
			if not FrontierExpeditionBusiness.integer(good.get("stock"),0,1000) or not FrontierExpeditionBusiness.integer(good.get("capacity"),1,1000) or not FrontierExpeditionBusiness.integer(good.get("price"),2,100):return false
			if int(good.stock)>int(good.capacity):return false
	return true
