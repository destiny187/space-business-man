class_name FrontierCombatCover
extends RefCounted
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_cover.json"))
	return _config
static func is_cover(row: Dictionary) -> bool:return config().buildings.has(row.get("type",""))
static func create(row: Dictionary,yaw: float) -> void:
	row.yaw=wrapf(yaw,-PI,PI);row.cover_hp=float(config().buildings[row.type].health);row.assembly_left=float(config().assembly_seconds)
static func status(row: Dictionary) -> String:
	if float(row.get("assembly_left",0))>0:return "조립 중"
	return "파손 · F 수리" if row.get("cover_hp",0)<=0 else "내구도 %d / %d"%[int(row.cover_hp),int(config().buildings[row.type].health)]
static func ready(row: Dictionary) -> bool:return is_cover(row) and float(row.get("assembly_left",0))<=0 and float(row.get("cover_hp",0))>0
static func valid(row: Dictionary) -> bool:
	if not is_cover(row):return true
	return FrontierUniverse._finite(row.get("cover_hp"),0,float(config().buildings[row.type].health)) and FrontierUniverse._finite(row.get("assembly_left"),0,float(config().assembly_seconds))
static func tick(site: Dictionary,delta: float) -> void:
	for row in site.buildings.values():
		if is_cover(row):row.assembly_left=maxf(0,float(row.get("assembly_left",0))-delta)
static func repair(world: Dictionary,actor: String,row: Dictionary) -> String:
	var def: Dictionary=config().buildings[row.type]
	if float(row.get("assembly_left",0))>0:return "조립이 끝난 뒤 사용하세요."
	if float(row.cover_hp)>=float(def.health):return "엄폐물이 온전합니다."
	var stock:=FrontierExpeditionBusiness.bag(world,actor)
	if not FrontierExpeditionBusiness.affordable(stock,def.repair):return "수리 재료: "+FrontierCatalog.cost_text(def.repair)
	FrontierExpeditionBusiness.transfer(stock,def.repair,-1);row.cover_hp=float(def.health);row.assembly_left=float(config().assembly_seconds)
	return ""
static func collision(root: Node3D,kind: String) -> void:
	for box in config().buildings[kind].boxes:FrontierWeatherShelters.box(root,FrontierCrewWorld.vector(box[1]),FrontierCrewWorld.vector(box[0]))
	# The wreck remains selectable without blocking movement or gun rays (layer 1).
	var wreck:=StaticBody3D.new();wreck.collision_layer=4;wreck.collision_mask=0;wreck.set_meta("cover_wreck",true)
	for key in ["business_kind","business_id"]:wreck.set_meta(key,root.get_meta(key))
	root.add_child(wreck);FrontierWeatherShelters.box(wreck,Vector3(2.8,.35,.65),Vector3(0,.175,0))
static func intercept(world: Dictionary,body_id: String,origin: Vector3,aim: Vector3,reach: float) -> Dictionary:
	var result: Dictionary={};var best:=reach
	for row in world.get("business",{}).get("sites",{}).get(body_id,{}).get("buildings",{}).values():
		if not ready(row):continue
		var turn:=Basis(Vector3.UP,-float(row.yaw));var start: Vector3=turn*(origin-FrontierCrewWorld.vector(row.position));var direction: Vector3=turn*aim
		for box in config().buildings[row.type].boxes:
			var size:=FrontierCrewWorld.vector(box[1]);var bounds:=AABB(FrontierCrewWorld.vector(box[0])-size*.5,size)
			var hit: Variant=bounds.intersects_segment(start,start+direction*reach)
			if hit==null:continue
			var distance: float=start.distance_to(hit)
			if distance<=best:best=distance;result={"row":row,"distance":distance,"point":origin+aim*distance}
	return result
static func damage(hit: Dictionary,amount: float) -> void:
	if hit.is_empty():return
	hit.row.cover_hp=maxf(0,float(hit.row.cover_hp)-amount);hit.row.status=status(hit.row)
static func blocks_body(world: Dictionary,body_id: String,from: Vector3,to: Vector3,radius: float,height: float) -> bool:
	# Sweep a conservative body volume against each oriented cover part.
	var center:=Vector3.UP*height*.5;var padding:=Vector3(radius,height*.5,radius)
	for row in world.get("business",{}).get("sites",{}).get(body_id,{}).get("buildings",{}).values():
		if not ready(row):continue
		var turn:=Basis(Vector3.UP,-float(row.yaw));var position:=FrontierCrewWorld.vector(row.position)
		var start:=turn*(from+center-position);var end:=turn*(to+center-position)
		for box in config().buildings[row.type].boxes:
			var size:=FrontierCrewWorld.vector(box[1])+padding*2
			var bounds:=AABB(FrontierCrewWorld.vector(box[0])-size*.5,size)
			if bounds.has_point(start) or bounds.intersects_segment(start,end)!=null:return true
	return false
static func present(node: Node3D,row: Dictionary) -> void:
	node.rotation.y=float(row.yaw)
	var visual: Node3D=node.get_meta("visual");var assembled:=1-clampf(float(row.get("assembly_left",0))/float(config().assembly_seconds),0,1)
	var intact:=float(row.get("cover_hp",0))>0
	visual.scale.y=lerpf(.08,1,assembled) if intact else .12
	for child in node.get_children():
		if child is CollisionShape3D:child.disabled=not ready(row)
		elif child is OccluderInstance3D:child.visible=ready(row)
		elif child.has_meta("cover_wreck"):
			for shape in child.get_children():
				if shape is CollisionShape3D:shape.disabled=intact
	var label: Label3D=node.get_meta("label");label.text=str(config().buildings[row.type].name)+"\n"+status(row);label.position.y=2.6 if row.type=="combat_barricade" else 1.9
	label.modulate=Color("f0b172") if not intact else Color("a8dec8")
