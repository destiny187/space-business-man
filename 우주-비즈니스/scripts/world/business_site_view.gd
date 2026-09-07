class_name FrontierBusinessSiteView
extends Node3D
var terrain: FrontierTerrainStreamer
var body: Dictionary
var ledger: Dictionary={}
var nodes: Dictionary={}
var cache: Dictionary={}
var pending_models: Dictionary={}
var requested_models: Dictionary={}
var prepared_models: Dictionary={}
var synchronous_resources:=DisplayServer.get_name()=="headless"
var ghosts: Node3D
var restore_amount:=0.0
var presentation_points: Array[Vector3]=[]
var region_key:=Vector2i(99999,99999)
func configure(stream: FrontierTerrainStreamer,planet: Dictionary) -> void:terrain=stream;body=planet
func _entity(id: String,model: String,p: Vector3,radius: float,kind: String) -> Node3D:
	var root:=StaticBody3D.new();root.set_meta("business_kind",kind);root.set_meta("business_id",id);root.position=p
	var visual: Node3D=prepared_models[model].instantiate();FrontierInkStyle.apply(visual,cache);root.add_child(visual)
	if kind=="vein":FrontierMinerals.apply_appearance(visual,_vein_appearance(id,model))
	var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=2.0;collision.shape=shape;collision.position.y=1;root.add_child(collision)
	var label:=Label3D.new();label.font=load("res://assets/fonts/NotoSansKR.ttf");label.font_size=40;label.pixel_size=.004;label.position.y=3.0;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.outline_size=8;label.render_priority=110;label.outline_render_priority=109;root.add_child(label)
	root.set_meta("label",label);root.set_meta("visual",visual);root.set_meta("parts",visual.find_children("Anim_*","Node3D",true,false))
	add_child(root);nodes[id]=root;return root
func accept(value: Dictionary) -> void:
	ledger=value
	var registered: bool=value.get("sites",{}).has(body.id)
	var site: Dictionary=value.get("sites",{}).get(body.id,{"remaining":{},"buildings":{},"robots":{},"center":[0,0,0],"environment":{"temperature":body.get("traits",{}).get("temperature",20)}})
	var wanted: Dictionary={}
	if registered:wanted["business-base"]=true
	if registered and not nodes.has("business-base"):_queue_entity("business-base","storage",FrontierExpeditionBusiness.point(site.center),1.5,"base")
	if nodes.has("business-base"):nodes["business-base"].get_meta("label").text="현장 창고\nF 창고 · 반납/인수"
	var camera:=get_viewport().get_camera_3d()
	var centers: Array[Vector3]=presentation_points.duplicate()
	if centers.is_empty():centers.append(camera.global_position if camera!=null else Vector3.ZERO)
	var veins: Dictionary={}
	for center in centers:
		for row in FrontierExpeditionBusiness.veins(body,center):veins[row.id]=row
	for row in veins.values():
		if site.remaining.get(row.id,row.capacity)<=0:continue
		var p:=FrontierMineralWorld.point(terrain.field,row)
		if not p.is_finite():continue
		if FrontierExpeditionBusiness.thermal_locked(body,site,row):continue
		wanted[row.id]=true
		if not nodes.has(row.id):_queue_entity(row.id,"ore_"+row.resource,p,1.1,"vein");continue
		nodes[row.id].get_meta("label").text="%s · %d\n%s"%[FrontierCatalog.entry("resources",row.resource).name,int(site.remaining.get(row.id,row.capacity)),"F 채광"]
		nodes[row.id].get_meta("visual").scale=nodes[row.id].get_meta("visual").get_meta("original_scale",Vector3.ONE)*lerpf(.55,1,float(site.remaining.get(row.id,row.capacity))/float(row.capacity))
	for row in site.buildings.values():
		wanted[row.id]=true
		if not nodes.has(row.id):
			_queue_entity(row.id,FrontierCatalog.entry("buildings",row.type).model,FrontierExpeditionBusiness.point(row.position),.5 if row.type=="solar" else float(FrontierCatalog.entry("buildings",row.type).radius),"building");continue
		nodes[row.id].get_meta("label").text=FrontierCatalog.entry("buildings",row.type).name+"\n"+str(row.status)
		if not row.get("engineering","").is_empty():nodes[row.id].get_meta("label").text+="\n"+str(FrontierFieldEngineering.definition(row.engineering).name)+" · 개조"
		_upgrade_visual(nodes[row.id],row,false)
		nodes[row.id].set_meta("working",row.active)
	for row in site.robots.values():
		wanted[row.id]=true
		if not nodes.has(row.id):_queue_entity(row.id,"miner",FrontierExpeditionBusiness.point(row.position),.7,"robot");continue
		nodes[row.id].set_meta("destination",FrontierExpeditionBusiness.point(row.position))
		nodes[row.id].get_meta("label").text="%s · %d%% · %d/%d\n%s"%[FrontierCatalog.entry("grades",row.grade).name,int(row.battery),FrontierExpeditionBusiness.total(row.cargo),FrontierProductionTier2.robot_capacity(row),row.status]
		_upgrade_visual(nodes[row.id],row,true)
		nodes[row.id].set_meta("working",row.status=="채광 중")
	for id in value.get("crates",{}):
		var row: Dictionary=value.crates[id]
		wanted[id]=true
		if not nodes.has(id):_queue_entity(id,"crew/recovery_crate",FrontierExpeditionBusiness.point(row.position),.5,"crate");continue
		nodes[id].get_meta("label").text="사업 회수 화물 · F\n"+FrontierCatalog.cost_text(row.inventory)
	for id in nodes.keys():
		if not wanted.has(id):nodes[id].queue_free();nodes.erase(id)
	for id in pending_models.keys():
		if not wanted.has(id):pending_models.erase(id)
	if not registered:return
	restore_amount=float(site.environment.ecology)/100.0
	terrain.material.set_shader_parameter("restoration_center",FrontierExpeditionBusiness.point(site.center))
	terrain.material.set_shader_parameter("restoration_radius",float(FrontierExpeditionBusiness.config().build_radius))
	terrain.material.set_shader_parameter("restoration",restore_amount)
	terrain.material.set_shader_parameter("soil_recovery",float(site.get("restoration2",{}).get("soil",0))/100.0)
	terrain.material.set_shader_parameter("salt_crust",float(site.get("restoration2",{}).get("salinity",0))/100.0)
	if body.get("traits",{}).get("id","")=="volcanic":terrain.material.set_shader_parameter("local_heat",clampf((float(site.environment.temperature)-float(body.traits.cooling_threshold))/maxf(1,float(body.traits.temperature)-float(body.traits.cooling_threshold)),0,1))
func target(camera: Camera3D,viewer: CollisionObject3D) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*12);query.exclude=[viewer.get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("business_kind"):return {}
	return {"id":hit.collider.get_meta("business_id"),"kind":hit.collider.get_meta("business_kind")}
func _process(dt: float) -> void:
	if presentation_points.is_empty() and FrontierMineralWorld.enabled(body):
		var viewer:=get_viewport().get_camera_3d()
		if viewer!=null:
			var size: float=body.mineral_profile.rules.tile_size
			var next:=Vector2i(floori(viewer.global_position.x/size),floori(viewer.global_position.z/size))
			if next!=region_key:region_key=next;accept(ledger)
	_load_one_model()
	for node in nodes.values():
		var camera:=get_viewport().get_camera_3d()
		if camera!=null:node.get_meta("label").visible=node.position.distance_to(camera.global_position)<18
		var previous: Vector3=node.position
		if node.has_meta("destination"):
			node.position=node.position.lerp(node.get_meta("destination"),minf(dt*8,1))
			var direction: Vector3=node.position-previous
			if direction.length()>.002:node.get_meta("visual").rotation.y=lerp_angle(node.get_meta("visual").rotation.y,atan2(-direction.x,-direction.z),minf(dt*8,1))
		for part in node.get_meta("parts"):
			if part.name.begins_with("Anim_Wheel") and node.position.distance_to(previous)>.001:part.rotate_x(-node.position.distance_to(previous)*4)
			elif node.get_meta("working",false) and (part.name.begins_with("Anim_Fan") or part.name.begins_with("Anim_Drill")):part.rotate_y(dt*6)

func _vein_appearance(id: String,model: String) -> Dictionary:
	return FrontierMinerals.appearance(model.trim_prefix("ore_").trim_suffix("_b"),int(body.get("streams",{}).get("resource",body.get("seed",0))),id)
func _queue_entity(id: String,model: String,p: Vector3,radius: float,kind: String) -> void:
	if kind=="vein":
		var appearance: Dictionary=_vein_appearance(id,model)
		if not appearance.is_empty():model=String(appearance.model).get_file().get_basename()
	pending_models[id]={"model":model,"point":p,"radius":radius,"kind":kind}
func _load_one_model() -> void:
	for model in requested_models.keys():
		var path: String="res://assets/models/"+model+".glb"
		var status: int=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			prepared_models[model]=ResourceLoader.load_threaded_get(path);requested_models.erase(model)
	for id in pending_models.keys():
		var row: Dictionary=pending_models[id]
		var model: String=row.model
		if not prepared_models.has(model):
			var path: String="res://assets/models/"+model+".glb"
			if synchronous_resources:prepared_models[model]=load(path)
			elif not requested_models.has(model) and requested_models.size()<2:
				ResourceLoader.load_threaded_request(path,"PackedScene");requested_models[model]=true
		if not prepared_models.has(model):continue
		_entity(id,model,row.point,row.radius,row.kind)
		pending_models.erase(id);accept(ledger)
		break
func _exit_tree() -> void:
	for model in requested_models:
		var path: String="res://assets/models/"+model+".glb"
		if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:ResourceLoader.load_threaded_get(path)

func _upgrade_visual(node: Node3D,row: Dictionary,robot: bool) -> void:
	if int(row.get("tier",1))!=2 or node.has_meta("tier2_visual"):return
	var visual: Node3D=node.get_meta("visual")
	var pack: Node3D=load("res://assets/models/products/retrofit_pack.glb").instantiate()
	FrontierInkStyle.apply(pack,cache);visual.add_child(pack)
	pack.position=Vector3(0,1.1,.55) if robot else Vector3(.75,1.2,.7)
	pack.rotation.y=PI
	pack.scale=Vector3.ONE*(.8 if robot else 1.25)
	node.set_meta("tier2_visual",true)
