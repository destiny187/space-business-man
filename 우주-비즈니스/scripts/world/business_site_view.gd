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
var occluder_shapes: Dictionary={}
var synchronous_resources:=DisplayServer.get_name()=="headless"
var ghosts: Node3D
var restore_amount:=0.0
var visual_temperature: float=NAN
var presentation_points: Array[Vector3]=[]
var labels_enabled:=true
var region_key:=Vector2i(99999,99999)
func configure(stream: FrontierTerrainStreamer,planet: Dictionary) -> void:terrain=stream;body=planet
func _entity(id: String,model: String,p: Vector3,radius: float,kind: String) -> Node3D:
	var root:=StaticBody3D.new();root.set_meta("business_kind",kind);root.set_meta("business_id",id);root.position=p
	var visual: Node3D=prepared_models[model].instantiate();FrontierInkStyle.apply(visual,cache);root.add_child(visual)
	if kind=="vein":FrontierMinerals.apply_appearance(visual,_vein_appearance(id,model))
	if kind in ["building","base"] and terrain.occlusion_enabled:
		if not occluder_shapes.has(model):occluder_shapes[model]=FrontierFieldVisibility.static_model_shape(visual)
		if occluder_shapes[model]!=null:
			var occluder:=OccluderInstance3D.new();occluder.occluder=occluder_shapes[model];root.add_child(occluder)
	var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=2.0;collision.shape=shape;collision.position.y=1;root.add_child(collision)
	var label:=Label3D.new();label.font=load("res://assets/fonts/NotoSansKR.ttf");label.font_size=40;label.pixel_size=.004;label.position.y=3.0;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.outline_size=8;label.render_priority=110;label.outline_render_priority=109;root.add_child(label)
	root.set_meta("label",label);root.set_meta("visual",visual);root.set_meta("parts",visual.find_children("Anim_*","Node3D",true,false))
	if kind=="robot":
		var rotor:=visual.find_child("ToolRotor",true,false)
		if rotor!=null:root.get_meta("parts").append(rotor)
		var intake:=Node3D.new();intake.name="DrillIntake";intake.position=Vector3(-.43,1.35,2.45);visual.add_child(intake);root.set_meta("intake",intake)
	for part in root.get_meta("parts"):
		part.set_meta("rest_position",part.position);part.set_meta("rest_transform",part.transform)
	add_child(root)
	if kind=="building":
		var top:=3.0
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			var bounds: AABB=mesh.get_aabb()
			for x in [bounds.position.x,bounds.end.x]:
				for y in [bounds.position.y,bounds.end.y]:
					for z in [bounds.position.z,bounds.end.z]:top=maxf(top,root.to_local(mesh.to_global(Vector3(x,y,z))).y+.45)
		label.position.y=top
	root.set_meta("visibility_notifier",FrontierFieldVisibility.watch(root))
	nodes[id]=root;return root
func accept(value: Dictionary) -> void:
	ledger=value
	var registered: bool=value.get("sites",{}).has(body.id)
	var site: Dictionary=value.get("sites",{}).get(body.id,{"remaining":{},"buildings":{},"robots":{},"center":[0,0,0],"environment":{"temperature":body.get("traits",{}).get("temperature",20)}})
	var wanted: Dictionary={}
	if registered:wanted["business-base"]=true
	if registered and not nodes.has("business-base"):_queue_entity("business-base","storage",FrontierExpeditionBusiness.point(site.center),1.5,"base")
	if nodes.has("business-base"):nodes["business-base"].get_meta("label").text="⊘ 현장 창고\n"+FrontierFacilityFlooding.STATUS if site.get("base_submerged",false) else "현장 창고\nF 창고 · 반납/인수"
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
		var working: bool=row.get("working",false) if row.type in ["atmosphere","thermal","water","biolab"] else row.active
		var symbol: String="⊘ " if row.get("submerged",false) else ("▶ " if working else ("✓ " if "목표" in str(row.status) else ("Ⅱ " if not row.enabled else "! ")))
		nodes[row.id].get_meta("label").text=symbol+FrontierCatalog.entry("buildings",row.type).name+"\n"+str(row.status)
		nodes[row.id].get_meta("label").modulate=Color("9bc7ef") if row.get("submerged",false) else (Color("82f5d2") if working else Color("f2c077"))
		if not row.get("engineering","").is_empty():nodes[row.id].get_meta("label").text+="\n"+str(FrontierFieldEngineering.definition(row.engineering).name)+" · 개조"
		_upgrade_visual(nodes[row.id],row,false)
		nodes[row.id].set_meta("working",row.get("working",false) if row.type in ["atmosphere","thermal","water","biolab"] else row.active)
	for row in site.robots.values():
		wanted[row.id]=true
		if not nodes.has(row.id):_queue_entity(row.id,"miner",FrontierExpeditionBusiness.point(row.position),.7,"robot");continue
		nodes[row.id].set_meta("destination",FrontierExpeditionBusiness.point(row.position))
		nodes[row.id].get_meta("label").text="%s · %d%% · %d/%d\n%s"%[FrontierCatalog.entry("grades",row.grade).name,int(row.battery),FrontierExpeditionBusiness.total(row.cargo),FrontierProductionTier2.robot_capacity(row),row.status]
		_upgrade_visual(nodes[row.id],row,true)
		nodes[row.id].set_meta("working",row.status=="채광 중")
		var vein:=FrontierExpeditionBusiness.find_vein(body,str(row.target))
		nodes[row.id].set_meta("aim",FrontierMineralWorld.point(terrain.field,vein) if not vein.is_empty() else Vector3.INF)
	for id in value.get("crates",{}):
		var row: Dictionary=value.crates[id]
		wanted[id]=true
		if not nodes.has(id):_queue_entity(id,"crew/recovery_crate",FrontierExpeditionBusiness.point(row.position),.5,"crate");continue
		nodes[id].get_meta("label").text="사업 회수 화물 · F\n"+FrontierCatalog.stock_text(row.inventory)
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
	if terrain!=null and terrain.material is ShaderMaterial:
		var native: float=body.get("traits",{}).get("temperature",20)
		var target: float=ledger.get("sites",{}).get(body.id,{}).get("environment",{}).get("temperature",native)
		if is_nan(visual_temperature):visual_temperature=native
		visual_temperature=lerpf(visual_temperature,target,1.0-exp(-dt/float(FrontierSurfaceMaterialLibrary.config().transition_seconds)))
		terrain.material.set_shader_parameter("local_temperature",visual_temperature)
	if presentation_points.is_empty() and FrontierMineralWorld.enabled(body):
		var viewer:=get_viewport().get_camera_3d()
		if viewer!=null:
			var size: float=body.mineral_profile.rules.tile_size
			var next:=Vector2i(floori(viewer.global_position.x/size),floori(viewer.global_position.z/size))
			if next!=region_key:region_key=next;accept(ledger)
	_load_one_model()
	var camera:=get_viewport().get_camera_3d()
	for node in nodes.values():
		if camera!=null:node.get_meta("label").visible=labels_enabled and node.position.distance_to(camera.global_position)<18
		var previous: Vector3=node.position
		if node.has_meta("destination"):
			node.position=node.position.lerp(node.get_meta("destination"),minf(dt*8,1))
		var parts: Array=node.get_meta("parts")
		if parts.is_empty():continue
		# Keep collision/interpolation and phase clocks current for every peer.
		# Only local model articulation sleeps while the renderer cannot see it.
		var distance_value: float=node.position.distance_to(previous)
		var travel: float=float(node.get_meta("visual_travel",0.0))+distance_value
		var motion: float=float(node.get_meta("visual_motion",0.0))+(dt if node.get_meta("working",false) else 0.0)
		node.set_meta("visual_travel",travel);node.set_meta("visual_motion",motion)
		if not FrontierFieldVisibility.active(node.get_meta("visibility_notifier",null)):continue
		if node.has_meta("destination"):
			var direction: Vector3=node.position-previous
			if node.get_meta("working",false) and node.get_meta("aim",Vector3.INF).is_finite():direction=node.get_meta("aim")-node.position
			if direction.length()>.002:node.get_meta("visual").rotation.y=lerp_angle(node.get_meta("visual").rotation.y,atan2(direction.x,direction.z),minf(dt*8,1))
		for part in parts:
			part.transform=part.get_meta("rest_transform")
			if part.name.begins_with("Anim_Piston"):
				part.position=part.get_meta("rest_position")+Vector3.UP*(sin(Time.get_ticks_msec()*.005)*.18 if node.get_meta("working",false) else 0.0)
			elif part.name.begins_with("Anim_Agitator"):part.rotate_y(fmod(motion*1.3,TAU))
			if part.name.begins_with("Anim_Wheel"):part.rotate_object_local(Vector3.UP,fmod(-travel*4,TAU))
			elif part.name=="ToolRotor":part.rotate_object_local(Vector3.UP,fmod(motion*18,TAU))
			elif part.name.begins_with("Anim_Fan") or part.name.begins_with("Anim_Drill"):part.rotate_y(fmod(motion*6,TAU))

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
	if int(row.get("tier",1))<2:return
	if int(row.get("tier",1))==3 and not node.has_meta("tier3_visual"):
		var core: Node3D=load("res://assets/models/products/control_circuit.glb").instantiate()
		FrontierInkStyle.apply(core,cache);node.get_meta("visual").add_child(core);core.position=Vector3(1.12,2.0,1.34);core.rotation=Vector3(PI/2,0,0);core.scale=Vector3.ONE*.65;node.set_meta("tier3_visual",true)
		FrontierFieldVisibility.fit(node,node.get_meta("visibility_notifier"))
	if node.has_meta("tier2_visual"):return
	var visual: Node3D=node.get_meta("visual")
	var pack: Node3D=load("res://assets/models/products/retrofit_pack.glb").instantiate()
	FrontierInkStyle.apply(pack,cache);visual.add_child(pack)
	pack.position=Vector3(0,1.1,.55) if robot else Vector3(.75,1.2,.7)
	pack.rotation.y=PI
	pack.scale=Vector3.ONE*(.8 if robot else 1.25)
	node.set_meta("tier2_visual",true)
	FrontierFieldVisibility.fit(node,node.get_meta("visibility_notifier"))
