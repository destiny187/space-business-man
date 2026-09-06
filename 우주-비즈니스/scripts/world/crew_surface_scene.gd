class_name FrontierCrewSurfaceScene
extends Node3D
var session: FrontierCrewSession
var viewer: Node3D
var terrain: FrontierTerrainStreamer
var distant: FrontierDistantTerrain
var ecology: FrontierSurfaceEcology
var body: Dictionary
var epoch:=0
var applied_edits:=0
var incoming: Array=[]
var config: Dictionary
var material_cache: Dictionary={}
var lamp: SpotLight3D
var environment: Environment
var last_anchor:=Vector3i(99999,99999,99999)
var tick:=0.0
var business_view: FrontierBusinessSiteView

func configure(connection: FrontierCrewSession,packet: Dictionary,player: Node3D,camera: Camera3D) -> void:
	session=connection;viewer=player;epoch=int(packet.epoch)
	body=FrontierUniverse.body_from_id(session.manifest,packet.body_id)
	config=packet.terrain_settings
	_setup_environment()
	var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/terrain.gdshader");mat.set_shader_parameter("rough",.96)
	if body.kind=="glacial":mat.set_shader_parameter("rock_color",Color("4e777f"));mat.set_shader_parameter("dust_color",Color("b9cdd0"))
	elif body.kind=="sulfur":mat.set_shader_parameter("rock_color",Color("7c634b"));mat.set_shader_parameter("dust_color",Color("b39962"))
	terrain=FrontierTerrainStreamer.new();terrain.configure(int(body.streams.terrain),packet.edits,mat,config);add_child(terrain)
	applied_edits=packet.edits.size();incoming=packet.edits.duplicate(true)
	distant=FrontierDistantTerrain.new();add_child(distant)
	var ship: Node3D=load("res://assets/models/ships/kestrel.glb").instantiate();ship.position=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position);FrontierInkStyle.apply(ship,material_cache);add_child(ship)
	ecology=FrontierSurfaceEcology.new();ecology.configure(_ecology(packet),body,terrain,viewer);add_child(ecology)
	lamp=SpotLight3D.new();lamp.position=Vector3(.15,-.1,0);lamp.light_color=Color("d5f0eb");lamp.spot_range=60;lamp.spot_angle=48;lamp.shadow_enabled=true;lamp.light_energy=0;camera.add_child(lamp)
	terrain.geometry_changed.connect(func():_refresh_distant();ecology.invalidate())
	business_view=FrontierBusinessSiteView.new();add_child(business_view);business_view.configure(terrain,body);business_view.accept(packet.get("business",{}))
	_update_interest()

func _ecology(packet: Dictionary) -> Dictionary:
	return session.authority.world.ecology if session.hosting else packet.ecology

func accept(packet: Dictionary) -> void:
	if packet.body_id!=body.id or int(packet.epoch)!=epoch:return
	if packet.edits.size()!=incoming.size():ecology.invalidate()
	incoming=packet.edits.duplicate(true)
	ecology.ecology=_ecology(packet)
	ecology.refresh_timer=0
	business_view.accept(packet.get("business",{}))

func _setup_environment() -> void:
	var world:=WorldEnvironment.new();environment=Environment.new()
	environment.background_mode=Environment.BG_SKY
	var sky:=Sky.new();var sky_mat:=ProceduralSkyMaterial.new();sky_mat.sky_top_color=Color("253748");sky_mat.sky_horizon_color=Color("c6ae91");sky_mat.ground_horizon_color=Color("b99977");sky_mat.ground_bottom_color=Color("433844");sky.sky_material=sky_mat;environment.sky=sky
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("a2b5c5");environment.ambient_light_energy=.28
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.fog_enabled=true;environment.fog_light_color=Color("b8a080");environment.fog_density=.0007
	environment.ssao_enabled=true;environment.ssao_radius=1.2;environment.ssao_intensity=1.2;world.environment=environment;add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);sun.light_color=Color("ffe1b5");sun.light_energy=1.8;sun.shadow_enabled=true;sun.directional_shadow_max_distance=180;add_child(sun)

func _update_interest() -> void:
	var points: Array[Vector3]=[viewer.position]
	if session.hosting:
		points.clear()
		for peer in session.authority.peers:points.append(FrontierCrewWorld.vector(session.authority.world.crew.members[session.authority.peers[peer]].position))
	if session.hosting:
		var site:=FrontierExpeditionBusiness.site(session.authority.world)
		for robot in site.get("robots",{}).values():points.append(FrontierExpeditionBusiness.point(robot.position))
	terrain.update_interests(points)
	if session.hosting:ecology.observers=points
	else:ecology.observers.clear()
	var anchor:=terrain.field.key_at(viewer.position)
	if anchor!=last_anchor:last_anchor=anchor;_refresh_distant()

func _refresh_distant() -> void:
	distant.rebuild(terrain.field,terrain.field.key_at(viewer.position),int(config.active_radius),terrain.material)

func _process(delta: float) -> void:
	if session==null or terrain==null:return
	if session.hosting and session.authority.world.has("ecology"):ecology.ecology=session.authority.world.ecology
	_update_interest()
	if applied_edits<incoming.size() and terrain.batch.is_empty():
		var edit: Dictionary=incoming[applied_edits]
		terrain.dig(FrontierCrewWorld.vector(edit.center),float(edit.radius));applied_edits+=1
	var underground: float=clampf(-viewer.position.y/10.0,0,1)
	environment.ambient_light_energy=lerpf(.28,.035,underground);environment.fog_density=lerpf(.0007,.002,underground)
	tick-=delta
	if tick<=0:
		tick=.15
		var camera:=lamp.get_parent() as Camera3D
		var covered: bool=terrain.field.density(camera.global_position+Vector3.UP*8)>0
		var energy:=0.0
		if covered:
			var query:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*60)
			if viewer is CollisionObject3D:query.exclude=[viewer.get_rid()]
			var hit:=get_world_3d().direct_space_state.intersect_ray(query)
			var distance: float=60.0 if hit.is_empty() else camera.global_position.distance_to(hit.position)
			energy=clampf(24.0*pow(distance/8.0,2),.8,24.0)
		lamp.light_energy=energy

func ready_at(point: Vector3) -> bool:
	return terrain!=null and terrain.ready_at(point+Vector3.UP) and applied_edits==incoming.size()

func _exit_tree() -> void:
	if is_instance_valid(lamp):lamp.queue_free()
