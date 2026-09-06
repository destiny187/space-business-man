class_name FrontierBusinessSiteView
extends Node3D
var terrain: FrontierTerrainStreamer
var body: Dictionary
var ledger: Dictionary={}
var nodes: Dictionary={}
var cache: Dictionary={}
var ghosts: Node3D
var restore_amount:=0.0
func configure(stream: FrontierTerrainStreamer,planet: Dictionary) -> void:terrain=stream;body=planet
func _entity(id: String,model: String,p: Vector3,radius: float,kind: String) -> Node3D:
	var root:=StaticBody3D.new();root.set_meta("business_kind",kind);root.set_meta("business_id",id);root.position=p
	var visual: Node3D=load("res://assets/models/"+model+".glb").instantiate();FrontierInkStyle.apply(visual,cache);root.add_child(visual)
	var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=2.0;collision.shape=shape;collision.position.y=1;root.add_child(collision)
	var label:=Label3D.new();label.font=load("res://assets/fonts/NotoSansKR.ttf");label.font_size=40;label.pixel_size=.004;label.position.y=3.0;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.outline_size=8;label.render_priority=110;label.outline_render_priority=109;root.add_child(label)
	root.set_meta("label",label);root.set_meta("visual",visual);root.set_meta("parts",visual.find_children("Anim_*","Node3D",true,false))
	add_child(root);nodes[id]=root;return root
func accept(value: Dictionary) -> void:
	ledger=value
	if value.is_empty() or not value.sites.has(body.id):return
	var site: Dictionary=value.sites[body.id]
	var wanted: Dictionary={"business-base":true}
	if not nodes.has("business-base"):_entity("business-base","storage",FrontierExpeditionBusiness.point(site.center),1.5,"base")
	nodes["business-base"].get_meta("label").text="현장 창고\nF 자원 반납 · B 사업"
	for row in FrontierExpeditionBusiness.veins(body):
		if site.remaining[row.id]<=0:continue
		var p:=FrontierExpeditionBusiness.ground(terrain.field,row.position[0],row.position[2])
		if not p.is_finite():continue
		wanted[row.id]=true
		if not nodes.has(row.id):_entity(row.id,"ore_"+row.resource,p,1.1,"vein")
		nodes[row.id].get_meta("label").text="%s · %d\nF 채광"%[FrontierCatalog.entry("resources",row.resource).name,int(site.remaining[row.id])]
		nodes[row.id].get_meta("visual").scale=Vector3.ONE*lerpf(.55,1,float(site.remaining[row.id])/float(row.capacity))
	for row in site.buildings.values():
		wanted[row.id]=true
		if not nodes.has(row.id):
			_entity(row.id,FrontierCatalog.entry("buildings",row.type).model,FrontierExpeditionBusiness.point(row.position),.5 if row.type=="solar" else float(FrontierCatalog.entry("buildings",row.type).radius),"building")
		nodes[row.id].get_meta("label").text=FrontierCatalog.entry("buildings",row.type).name+"\n"+str(row.status)
		nodes[row.id].set_meta("working",row.active)
	for row in site.robots.values():
		wanted[row.id]=true
		if not nodes.has(row.id):_entity(row.id,"miner",FrontierExpeditionBusiness.point(row.position),.7,"robot")
		nodes[row.id].set_meta("destination",FrontierExpeditionBusiness.point(row.position))
		nodes[row.id].get_meta("label").text="%s · %d%% · %d/%d\n%s"%[FrontierCatalog.entry("grades",row.grade).name,int(row.battery),FrontierExpeditionBusiness.total(row.cargo),int(FrontierExpeditionBusiness.config().robot_capacity),row.status]
		nodes[row.id].set_meta("working",row.status=="채광 중")
	for id in value.crates:
		var row: Dictionary=value.crates[id]
		wanted[id]=true
		if not nodes.has(id):_entity(id,"crew/recovery_crate",FrontierExpeditionBusiness.point(row.position),.5,"crate")
		nodes[id].get_meta("label").text="사업 회수 화물 · F\n"+FrontierCatalog.cost_text(row.inventory)
	for id in nodes.keys():
		if not wanted.has(id):nodes[id].queue_free();nodes.erase(id)
	restore_amount=float(site.environment.ecology)/100.0
	terrain.material.set_shader_parameter("restoration_center",FrontierExpeditionBusiness.point(site.center))
	terrain.material.set_shader_parameter("restoration_radius",float(FrontierExpeditionBusiness.config().build_radius))
	terrain.material.set_shader_parameter("restoration",restore_amount)
func target(camera: Camera3D,viewer: CollisionObject3D) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*12);query.exclude=[viewer.get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("business_kind"):return {}
	return {"id":hit.collider.get_meta("business_id"),"kind":hit.collider.get_meta("business_kind")}
func _process(dt: float) -> void:
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
