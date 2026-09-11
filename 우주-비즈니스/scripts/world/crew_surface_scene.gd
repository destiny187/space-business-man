class_name FrontierCrewSurfaceScene
extends Node3D
const Wildlife=preload("res://scripts/world/wildlife_behavior.gd")
var presentation_points: Array[Vector3]=[]
var presentation_ecology_refreshed:=false
var shuttle_models: Dictionary={}
var landing_ship: Node3D
var landing_effects: FrontierLandingSurfaceEffects
var seated_hull: String="kestrel"
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
var atmospheric_particles: Node3D
var atmosphere: RefCounted
var environment: Environment
var last_anchor:=Vector3i(99999,99999,99999)
var tick:=0.0
var fallback_tick:=0.0
var fallback_jobs:=-1
var fallback_distant_builds:=-1
var preferences: FrontierClientSettings
var rendered_distance:=0.0
var refits: FrontierVesselVisuals
var business_view: FrontierBusinessSiteView
var water_columns: Dictionary={}
var water_interactions: FrontierWaterInteractions
var physical_water: FrontierSurfaceWaterView
var hydrology: FrontierSurfaceHydrology
var presence: FrontierSurfacePresence
var surface_details: FrontierSurfaceDetails
var incidents: FrontierIncidentView
var discoveries: FrontierDiscoveryView

func configure(connection: FrontierCrewSession,packet: Dictionary,player: Node3D,camera: Camera3D) -> void:
	session=connection;viewer=player;epoch=int(packet.epoch)
	water_columns=packet.get("water_columns",{})
	body=FrontierUniverse.body_from_id(session.manifest,packet.body_id)
	config=packet.terrain_settings
	_setup_environment()
	atmosphere.configure_cycles(session.manifest,packet.get("sky_region",{}),float(session.latest.crew.navigation.orbit_time))
	atmosphere.accept(packet.get("business",{}))
	atmosphere.current=atmosphere.target_at(viewer.position);atmosphere.paint()
	var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/terrain.gdshader");mat.set_shader_parameter("rough",.96)
	if body.kind=="glacial":mat.set_shader_parameter("rock_color",Color("4e777f"));mat.set_shader_parameter("dust_color",Color("b9cdd0"))
	elif body.kind=="sulfur":mat.set_shader_parameter("rock_color",Color("7c634b"));mat.set_shader_parameter("dust_color",Color("b39962"))
	if body.has("traits"):
		mat.set_shader_parameter("molten",body.traits.id=="volcanic");mat.set_shader_parameter("rock_color",Color(body.traits.rock));mat.set_shader_parameter("dust_color",Color(body.traits.dust))
		mat.set_shader_parameter("surface_pattern",{"oxidized":1,"frozen":2,"fractured":2,"salt":3}.get(body.traits.id,0))
		mat.set_shader_parameter("geology_phase",FrontierSurfaceGeology.phase(body.traits))
		mat.set_shader_parameter("biome_style",["oxidized","continental","cratered","fractured","tundra","frozen","volcanic","salt","ochre"].find(body.traits.id))
	FrontierSurfaceMaterialLibrary.configure(mat,body)
	terrain=FrontierTerrainStreamer.new();terrain.configure(int(body.streams.terrain),packet.edits,mat,config,body.get("terrain_traits",{}));add_child(terrain)
	hydrology=FrontierSurfaceHydrology.new();add_child(hydrology);hydrology.configure(self);hydrology.accept(packet.get("business",{}))
	physical_water=FrontierSurfaceWaterView.new();add_child(physical_water);physical_water.configure(self);physical_water.accept(packet.get("water",FrontierSurfaceWater.create()))
	applied_edits=packet.edits.size();incoming=packet.edits.duplicate(true)
	distant=FrontierDistantTerrain.new();distant.material_override=mat;add_child(distant)
	var ship: Node3D=load("res://assets/models/ships/kestrel.glb").instantiate();ship.position=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position);FrontierInkStyle.apply(ship,material_cache);add_child(ship)
	# Seat the existing Blender hull on the landing plateau, rather than leaving it at a fixed hover height.
	var bottom:=0.0
	for mesh in ship.find_children("*","MeshInstance3D",true,false):
		var bounds: AABB=(ship.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		bottom=minf(bottom,bounds.position.y)
	ship.position.y=terrain.field.height(ship.position.x,ship.position.z)-bottom
	var arrival_spawn:=FrontierCrewWorld.vector(FrontierCrewSurface.config().landing_spawn_positions[0])+Vector3(-4,0,0)
	ship.rotation.y=atan2(arrival_spawn.x-ship.position.x,arrival_spawn.z-ship.position.z)
	landing_ship=ship
	refits=FrontierVesselVisuals.new();ship.add_child(refits);refits.update_loadout({"hull":"finch"} if not session.latest.get("local_shuttle","").is_empty() else session.latest.get("vessel",{}))
	ecology=FrontierSurfaceEcology.new();ecology.configure(_ecology(packet),body,terrain,viewer);add_child(ecology)
	ecology.wildlife_cue.connect(_wildlife_cue)
	lamp=SpotLight3D.new();lamp.light_cull_mask=((1 << 20)-1)^FrontierExpeditionFeedback.HANDHELD_LAYER;lamp.position=Vector3(.15,-.1,0);lamp.light_color=Color("d5f0eb");lamp.spot_range=60;lamp.spot_angle=48;lamp.shadow_enabled=true;lamp.light_energy=0;camera.add_child(lamp)
	terrain.geometry_changed.connect(func():
		_refresh_distant();ecology.invalidate()
		if business_view!=null:business_view.accept(business_view.ledger)
	)
	business_view=FrontierBusinessSiteView.new();add_child(business_view);business_view.configure(terrain,body);business_view.accept(packet.get("business",{}))
	surface_details=FrontierSurfaceDetails.new();add_child(surface_details);surface_details.configure(terrain,body,viewer);surface_details.accept(packet.get("business",{}))
	preferences=FrontierClientSettings.ensure(get_tree())
	preferences.changed.connect(func():
		if not is_equal_approx(rendered_distance,float(preferences.values.view_distance)):_refresh_distant())
	atmospheric_particles=load("res://scripts/world/surface_atmosphere_particles.gd").new()
	add_child(atmospheric_particles);atmospheric_particles.configure(self,camera)
	presence=FrontierSurfacePresence.new();add_child(presence);presence.configure(self)
	water_interactions=FrontierWaterInteractions.new();add_child(water_interactions);water_interactions.configure(self)
	discoveries=FrontierDiscoveryView.new();add_child(discoveries);discoveries.configure(self,camera)
	incidents=FrontierIncidentView.new();add_child(incidents);incidents.configure(self,camera)
	var deep_gallery=preload("res://scripts/world/deep_cave_view.gd").new();deep_gallery.name="DeepGallery";add_child(deep_gallery);deep_gallery.configure(self)
	_update_interest()
	_update_shuttles()

func _ecology(packet: Dictionary) -> Dictionary:
	return session.authority.world.ecology if session.hosting else packet.ecology

func accept(packet: Dictionary) -> void:
	if packet.body_id!=body.id or int(packet.epoch)!=epoch:return
	if packet.edits.size()!=incoming.size():ecology.invalidate()
	incoming=packet.edits.duplicate(true)
	water_columns=packet.get("water_columns",{})
	ecology.ecology=_ecology(packet)
	ecology.refresh_timer=0
	business_view.accept(packet.get("business",{}))
	surface_details.accept(packet.get("business",{}))
	atmosphere.accept(packet.get("business",{}));_update_shuttles()
	if presence!=null:presence.accept(packet.get("business",{}))
	if hydrology!=null:hydrology.accept(packet.get("business",{}))
	if physical_water!=null:physical_water.accept(packet.get("water",FrontierSurfaceWater.create()))

func _setup_environment() -> void:
	var world:=WorldEnvironment.new();environment=Environment.new()
	environment.background_mode=Environment.BG_SKY
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.fog_enabled=true;environment.fog_sky_affect=0.0
	environment.ssao_enabled=true;environment.ssao_radius=1.2;environment.ssao_intensity=1.2;environment.ssao_light_affect=.35;world.environment=environment;add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);sun.light_color=Color("ffe1b5");sun.light_energy=1.8;sun.shadow_enabled=true;sun.directional_shadow_max_distance=180;add_child(sun)
	atmosphere=load("res://scripts/world/surface_atmosphere.gd").new()
	atmosphere.configure(body,environment,sun)

func _update_interest() -> void:
	var points: Array[Vector3]=[viewer.position]
	if session.hosting:
		points.clear()
		for peer in session.authority.peers:
			var id: String=session.authority.peers[peer]
			if FrontierShuttles.area_key(session.authority.world,id)=="surface:"+str(body.id):points.append(FrontierCrewWorld.vector(session.authority.world.crew.members[id].position))
	if session.hosting:
		var site:=FrontierExpeditionBusiness.site(FrontierShuttles.context(session.authority.world,session.latest.self_id))
		for robot in site.get("robots",{}).values():points.append(FrontierExpeditionBusiness.point(robot.position))
	terrain.update_interests(points)
	if session.hosting:ecology.observers=points
	else:ecology.observers.clear()
	var anchor:=terrain.field.key_at(viewer.position)
	if anchor.x!=last_anchor.x or anchor.z!=last_anchor.z:last_anchor=anchor;_refresh_distant()

func _refresh_distant() -> void:
	rendered_distance=float(preferences.values.view_distance)
	distant.request_rebuild(terrain.field,terrain.field.key_at(viewer.position),int(config.active_radius),terrain.material,float(preferences.values.view_distance))
	distant.request_fallback(terrain.field,terrain.field.key_at(viewer.position),int(config.active_radius),terrain.chunks)
	fallback_jobs=terrain.completed_jobs;fallback_distant_builds=distant.build_count

func _process(delta: float) -> void:
	if session==null or terrain==null or not session.active or not session.latest.has("crew"):return
	if session.hosting and session.authority.world.has("ecology"):ecology.ecology=session.authority.world.ecology
	refits.update_loadout({"hull":"finch"} if not session.latest.get("local_shuttle","").is_empty() else session.latest.get("vessel",{}))
	if refits.requested_hull.is_empty() and seated_hull!=refits.hull_id:seat_vessel()
	_update_interest()
	fallback_tick-=delta
	if fallback_tick<=0 and (fallback_jobs!=terrain.completed_jobs or fallback_distant_builds!=distant.build_count):
		fallback_tick=.5;fallback_jobs=terrain.completed_jobs;fallback_distant_builds=distant.build_count
		distant.request_fallback(terrain.field,terrain.field.key_at(viewer.position),int(config.active_radius),terrain.chunks)
	if applied_edits<incoming.size() and terrain.batch.is_empty():
		var edit: Dictionary=incoming[applied_edits]
		terrain.dig(FrontierCrewWorld.vector(edit.center),float(edit.radius));applied_edits+=1
	var underground: float=clampf((terrain.field.height(viewer.position.x,viewer.position.z)-viewer.position.y-2.0)/10.0,0,1)
	atmosphere.sync_clock(float(session.latest.crew.navigation.orbit_time))
	_sync_wildlife()
	ecology.sync_clock(float(session.latest.crew.navigation.orbit_time))
	atmosphere.step(delta,viewer.position,underground,float(preferences.values.fog))
	tick-=delta
	if tick<=0:
		tick=.15
		var camera:=lamp.get_parent() as Camera3D
		var covered: bool=terrain.field.density(camera.global_position+Vector3.UP*8)>0
		var energy:=0.0
		if covered or atmosphere.daylight<.55:
			var query:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*60)
			if viewer is CollisionObject3D:query.exclude=[viewer.get_rid()]
			var hit:=get_world_3d().direct_space_state.intersect_ray(query)
			var distance: float=60.0 if hit.is_empty() else camera.global_position.distance_to(hit.position)
			var base_energy: float=24.0 if covered else float(atmosphere.cycles.get("worklight_energy",12.0))
			energy=clampf(base_energy*pow(distance/8.0,2),.8,24.0)
		lamp.light_energy=energy

func ready_at(point: Vector3) -> bool:
	return terrain!=null and distant.mesh!=null and terrain.ready_at(point+Vector3.UP) and applied_edits==incoming.size()

func _exit_tree() -> void:
	if is_instance_valid(lamp):lamp.queue_free()

func prepare_landing_view(points: Array[Vector3]) -> void:
	presentation_points=points.duplicate();presentation_ecology_refreshed=false
	business_view.presentation_points=points.duplicate()
	business_view.accept(business_view.ledger)
	_update_interest()

func landing_view_ready() -> bool:
	var points: Array[Vector3]=[viewer.position]
	if not terrain.ready_for(points) or applied_edits!=incoming.size():return false
	if distant.mesh==null or distant.task_id!=-1 or not distant.queued.is_empty():return false
	# Candidates are discovered only after their supporting terrain exists.
	if not presentation_ecology_refreshed:
		ecology.refresh();presentation_ecology_refreshed=true
	if not ecology.pending.is_empty() or not ecology.resource_requests.is_empty():return false
	return business_view.pending_models.is_empty() and business_view.requested_models.is_empty() and surface_details.presentation_ready()

func finish_landing_view() -> void:
	presentation_points.clear();business_view.presentation_points.clear()
	business_view.region_key=Vector2i(99999,99999)

func _update_shuttles() -> void:
	var value: Dictionary=session.latest
	var fleet: Dictionary=value.crew.get("shuttles",{})
	var at_mother: bool=value.get("local_shuttle","").is_empty()
	for id in shuttle_models.keys():
		if not at_mother or not fleet.has(id) or fleet[id].state!="docked":shuttle_models[id].queue_free();shuttle_models.erase(id)
	if not at_mother:return
	for id in fleet:
		if fleet[id].state!="docked" or shuttle_models.has(id):continue
		var ship: Node3D=load(FrontierShuttles.config().model).instantiate();add_child(ship);FrontierInkStyle.apply(ship,{})
		var point:=FrontierCrewWorld.vector(FrontierShuttles.config().pad);point.x+=float(fleet[id].get("pad_slot",0))*7.0;point.y=terrain.field.height(point.x,point.z)
		ship.position=point;shuttle_models[id]=ship
		var label:=Label3D.new();label.text="LOTUS 공용 FINCH" if fleet[id].get("company",false) else "FINCH · "+str(value.crew.members[id].profile.name);label.position.y=3.5;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=44;label.pixel_size=.006;ship.add_child(label)

func seat_vessel() -> void:
	seated_hull=refits.hull_id
	var cfg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_arrival.json"))
	if cfg.clearance.has(seated_hull):landing_ship.position.y=terrain.field.height(landing_ship.position.x,landing_ship.position.z)+float(cfg.clearance[seated_hull])

func water_depth(p: Vector3) -> float:
	if physical_water==null:return 0.0
	var value:=FrontierSurfaceWater.depth(physical_water.state,p)
	var base:=terrain.field.height(p.x,p.z)
	if hydrology.native_liquid and base<float(hydrology.cfg.sea_level) and p.y>=base:value=maxf(value,float(hydrology.cfg.sea_level)-p.y)
	var level:=float(water_columns.get("%d:%d"%[floori(p.x),floori(p.z)],-INF))
	if p.y>=base-.1 and level>p.y and terrain.field.density(Vector3(p.x,base-.35,p.z))>=0:value=maxf(value,level-p.y)
	return maxf(0,value)

func _sync_wildlife() -> void:
	var points: Array[Vector3]=[]
	var time: float=session.latest.crew.navigation.orbit_time
	if session.hosting:
		points=Wildlife.observers(session.authority.world,session.authority.peers,str(body.id))
		var local:=FrontierShuttles.context(session.authority.world,session.latest.self_id)
		time=float(local.crew.navigation.orbit_time)
	else:
		var ids: Array=session.latest.crew.members.keys();ids.sort()
		for id in ids:
			var member: Dictionary=session.latest.crew.members[id]
			if member.get("connected",false) and member.area=="surface" and not member.aboard and member.get("place_key","")=="surface:"+str(body.id):points.append(FrontierCrewWorld.vector(member.position))
	var app:=session.get_parent() as FrontierCrewExpedition
	var stopped: bool=session.offline and app!=null and (app.any_menu_open() or not app.get_window().has_focus())
	ecology.sync_behavior(time,points,stopped,session.authority.world.crew if session.hosting else session.latest.crew)

func _wildlife_cue(point: Vector3,kind: String) -> void:
	var app:=session.get_parent() as FrontierCrewExpedition
	if app==null or app.feedback==null or app.any_menu_open() or app.feedback.blocked() or not app.get_window().has_focus():return
	if app.onboarding!=null and app.onboarding.letter.visible:return
	if kind=="alert":app.feedback.audio.play("sfx_creature_call",point)
	else:app.feedback.effects.burst(point,Color("a89677"),2)
