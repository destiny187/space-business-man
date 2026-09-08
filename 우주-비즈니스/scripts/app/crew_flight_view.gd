class_name FrontierCrewFlightView
extends FrontierSpaceFlight
signal planet_scanned(ordinal: int)
var navigation: Dictionary={}
var announced_system: int=-1
var orbit_clock:=0.0
var drive: FrontierVesselDriveEffects
var previous_hull:=100.0
var previous_braking:=false
var warning_clock:=0.0
var scan_enabled:=true
var scan_target: int=-1
var scan_progress:=0.0
var scanned: Dictionary={}
var exterior:=false
var look_offset:=Vector2.ZERO
var transit_overlay: Control
var transit_audio: FrontierAudio
var soundscape: FrontierSpaceAudio
var presentation_blocked:=false
var engine: AudioStreamPlayer
var last_phase: String=""
var station_excluded: int=-1
var station_model: Node3D
var departure_heading:=Vector3.FORWARD
var departure_initial:=Vector3.FORWARD
var departure_origin:=Vector3.ZERO
var transit_geometry: Array[GeometryInstance3D]=[]
var refits: FrontierVesselVisuals
func _ready() -> void:
	test_mode=true
	flight_config=state.manifest.settings.flight
	_setup_space();_build_ui();ui_root.hide()
	camera.far=float(FrontierUniverse.presentation().stellar_transition.camera_far)
	ship.get_child(0).scale=Vector3.ONE*2
	drive=FrontierVesselDriveEffects.new();ship.get_child(0).add_child(drive)
	refits=FrontierVesselVisuals.new();ship.get_child(0).add_child(refits)
	# First authoritative navigation builds the actual system once.
	current_system = -1
	var layer:=CanvasLayer.new();add_child(layer)
	transit_overlay=load("res://scripts/ui/stellar_transit_overlay.gd").new();layer.add_child(transit_overlay)
	transit_audio=FrontierAudio.new();add_child(transit_audio)
	soundscape=FrontierSpaceAudio.new();add_child(soundscape)
	engine=AudioStreamPlayer.new();engine.bus="SFX";engine.stream=transit_audio.stream("sfx_vessel_engine",true);engine.volume_db=-26;add_child(engine)
	set_physics_process(false);set_process_unhandled_input(false)
func update_navigation(value: Dictionary) -> void:
	var initial_view:=navigation.is_empty()
	var solar_start: bool=initial_view and int(value.system)==0 and value.mode=="idle"
	station_excluded=int(value.get("first_stellar_system",-1))
	if value.mode=="jump" and navigation.get("mode","")!="jump":
		departure_origin=ship.position if not navigation.is_empty() else FrontierCrewWorld.vector(value.position)
		var route: Dictionary=value.get("transit",{})
		if route.has("departure_origin"):departure_origin=FrontierCrewWorld.vector(route.departure_origin)
		departure_initial=FrontierCrewWorld.vector(route.get("initial_direction",value.direction)).normalized()
		departure_heading=FrontierCrewWorld.vector(route.departure_direction) if route.has("departure_direction") else FrontierCrewNavigation.departure_direction(state.manifest,int(value.system),departure_origin,departure_initial,float(value.get("orbit_time",0)),float(route.get("duration",12)))
		if departure_heading==Vector3.ZERO:departure_heading=departure_initial
		transit_overlay.arrival_age=100.0
	if value.mode=="jump":prepare_system(FrontierUniverse.system_index(state.manifest,int(value.target)))
	var render_system: int=int(value.system)
	if value.mode=="jump" and float(value.get("transit",{}).get("progress",0))>=float(FrontierUniverse.presentation().stellar_transition.swap_progress):render_system=FrontierUniverse.system_index(state.manifest,int(value.target))
	if navigation.is_empty() or render_system!=current_system:
		_load_system(render_system);ship.position=_display_position(value)
		if initial_view:ship.quaternion=_flight_basis(FrontierCrewWorld.vector(value.direction)).get_rotation_quaternion()
	_apply_transit_visibility(value)
	if render_system!=announced_system and value.mode!="jump":
		announced_system=render_system
		var system:=FrontierUniverse.system(state.manifest,render_system)
		if not solar_start:soundscape.enter(int(system.band))
		var layout:=FrontierUniverse.system_layout(state.manifest,render_system)
		var theme_name: String={"satellites":"위성 군집","giant_court":"거대행성 군집","open":"넓은 항로","debris":"소행성 회랑"}.get(layout.theme,"미지의 탐사권")
		if not solar_start:transit_overlay.announce(system.star.name,"항성계 진입  ·  %s형 항성  ·  %d개 행성  ·  %s"%[system.star.spectral_type,system.body_ids.size(),theme_name])
	var phase:=FrontierCrewNavigation.phase(value)
	if phase!=last_phase:
		if value.mode=="jump" and last_phase in ["궤도 대기","직접 조종"]:soundscape.transition("sfx_vessel_boost")
		last_phase=phase
	if float(value.get("hull",100))<previous_hull and not value.get("star_warning",false):transit_audio.play("sfx_build_invalid")
	if value.get("boosting",false) and not navigation.get("boosting",false):soundscape.transition("sfx_vessel_boost")
	var braking: bool=value.mode!="jump" and (value.get("proximity_braking",false) or (float(navigation.get("speed",0))>60 and float(value.speed)<float(navigation.get("speed",0))-5))
	if braking and not previous_braking:soundscape.transition("sfx_vessel_brake")
	previous_braking=braking
	previous_hull=float(value.get("hull",100))
	orbit_clock=float(value.get("orbit_time",0))
	navigation=value.duplicate(true)
	transit_overlay.nav=navigation
	transit_overlay.telemetry=FrontierFlightTelemetry.read(state.manifest,navigation)
	update_orbits(float(value.get("orbit_time",0)))
func _process(delta: float) -> void:
	if navigation.is_empty():return
	if navigation.mode=="jump":step_preparation()
	soundscape.blocked=presentation_blocked
	transit_overlay.presentation_blocked=presentation_blocked
	engine.stream_paused=presentation_blocked
	orbit_clock+=delta;update_orbits(orbit_clock)
	var previous_view:=camera.global_basis.get_rotation_quaternion()
	ship.position=ship.position.lerp(_display_position(navigation),minf(delta*14,1))
	var facing:=FrontierCrewWorld.vector(navigation.direction)
	if navigation.mode=="jump" and float(navigation.get("transit",{}).get("progress",0))>=float(FrontierUniverse.presentation().stellar_transition.swap_progress):
		facing=(FrontierUniverse.entry_focus(state.manifest,int(navigation.target),float(navigation.get("orbit_time",0)))-ship.position).normalized()
	if navigation.mode=="jump" and float(navigation.get("transit",{}).get("progress",0))<float(FrontierUniverse.presentation().stellar_transition.swap_progress):
		var align:=smoothstep(0,float(FrontierUniverse.presentation().stellar_transition.departure_start),float(navigation.transit.progress))
		ship.quaternion=_flight_basis(departure_initial).get_rotation_quaternion().slerp(_flight_basis(departure_heading).get_rotation_quaternion(),align)
	else:ship.quaternion=ship.quaternion.slerp(_flight_basis(facing).get_rotation_quaternion(),minf(delta*6,1))
	camera.position=(Vector3(0,8,21) if refits.hull_id=="finch" else Vector3(0,16,57)) if exterior else (Vector3(0,5.3,-1.2) if refits.hull_id=="finch" else Vector3(0,2,-18))
	camera.rotation=(Vector3(-.15,0,0) if exterior else Vector3.ZERO)+Vector3(look_offset.y,look_offset.x,0)
	if navigation.mode=="jump":camera.global_basis=Basis(previous_view.slerp(camera.global_basis.get_rotation_quaternion(),minf(delta*6,1)))
	camera.fov=lerpf(camera.fov,minf(110.0,float(FrontierClientSettings.ensure(get_tree()).values.fov)+20) if navigation.mode=="jump" or navigation.get("boosting",false) else float(FrontierClientSettings.ensure(get_tree()).values.fov),minf(delta*3,1))

	warning_clock=maxf(0,warning_clock-delta)
	if navigation.get("star_warning",false) and warning_clock<=0 and not presentation_blocked:
		transit_audio.play("sfx_stellar_warning");warning_clock=2.2 if navigation.get("star_danger",false) else 4.0
	if not navigation.get("star_warning",false):warning_clock=0
	transit_overlay.guidance=FrontierSpaceGuidance.read(state.manifest,navigation,camera,Vector2(get_viewport().get_visible_rect().size))
	_update_planet_scan(delta)
	soundscape.update(delta,scan_target>=0 and scan_progress<1.0,scan_progress)
	_update_galactic_core()
	var in_transit: bool=navigation.mode=="jump"
	var p: float=navigation.get("transit",{}).get("progress",0.0)
	_apply_transit_visibility(navigation)
	if galactic_core!=null and in_transit:galactic_core.hide()
	var thrust: float=clampf(absf(float(navigation.speed))/700.0,0,1)
	if in_transit:thrust=0.0 if p<float(FrontierUniverse.presentation().stellar_transition.departure_start) else maxf(.2,sin(p*PI))
	var boosted: bool=in_transit or navigation.get("boosting",false)
	drive.set_thrust(thrust,boosted)
	if thrust>.02:
		engine.pitch_scale=.65+thrust*(.8 if boosted else .4)
		engine.volume_db=lerpf(-34,float(soundscape.config.engine_boost_db if boosted else soundscape.config.engine_normal_db),thrust)
		if not engine.playing:engine.play()
	elif engine.playing:engine.stop()

func pick_planet(point: Vector2) -> int:
	if navigation.get("mode","")=="jump":return -1
	var ray:=camera.project_ray_normal(point)
	var nearest:=INF;var found: int=-1
	for ordinal in planets:
		var entry: Dictionary=planets[ordinal]
		var offset: Vector3=entry.node.global_position-camera.global_position
		var along:=offset.dot(ray)
		if along>0 and along<nearest and (offset-ray*along).length()<float(entry.radius):nearest=along;found=int(ordinal)
	return found

func _display_position(value: Dictionary) -> Vector3:
	if value.mode!="jump":return FrontierCrewWorld.vector(value.position)
	var cfg: Dictionary=FrontierUniverse.presentation().stellar_transition
	var p: float=value.get("transit",{}).get("progress",0)
	var midpoint: float=cfg.swap_progress
	if p>=midpoint:
		var elapsed: float=value.get("orbit_time",0)
		var entry:=FrontierUniverse.entry_position(state.manifest,int(value.target),elapsed)
		var focus:=FrontierUniverse.entry_focus(state.manifest,int(value.target),elapsed)
		return entry+(entry-focus).normalized()*float(cfg.distant_offset)*(1.0-smoothstep(midpoint,1.0,p))
	return departure_origin+departure_heading*float(cfg.distant_offset)*smoothstep(float(cfg.departure_start),midpoint,p)

func _apply_transit_visibility(value: Dictionary) -> void:
	var opacity:=1.0
	if value.mode=="jump":
		var cfg: Dictionary=FrontierUniverse.presentation().stellar_transition
		var p: float=value.get("transit",{}).get("progress",0)
		opacity=1.0-smoothstep(float(cfg.departure_fade_start),float(cfg.swap_progress),p) if p<float(cfg.swap_progress) else smoothstep(float(cfg.swap_progress),float(cfg.arrival_fade_end),p)
	for geometry in transit_geometry:
		geometry.transparency=1.0-opacity
	if system_art!=null:system_art.visible=opacity>0.0
	for entry in planets.values():entry.node.visible=opacity>0.0

func _collect_transit_geometry(node: Node) -> void:
	if node is GeometryInstance3D:transit_geometry.append(node)
	for child in node.get_children():_collect_transit_geometry(child)

func _load_system(index: int) -> void:
	transit_geometry.clear()
	super._load_system(index)
	station_model=null
	var station:=FrontierSpaceStation.definition(state.manifest,index,station_excluded)
	if not station.is_empty():
		station_model=load(FrontierSpaceStation.config().model).instantiate();station_model.position=FrontierCrewWorld.vector(station.position)
		FrontierInkStyle.apply(station_model,cache);system_art.add_child(station_model)
	for entry in planets.values():_collect_transit_geometry(entry.node)
	if system_art!=null:_collect_transit_geometry(system_art)
	# Names belong to the gaze scanner, not permanent labels across the sky.
	for entry in planets.values():
		for node in entry.node.get_children():
			if node is Label3D:node.hide()
	if system_art!=null:
		for node in system_art.get_children():
			if node is Label3D:node.hide()

func _update_planet_scan(delta: float) -> void:
	var target: int=pick_planet(Vector2(get_viewport().get_visible_rect().size)*.5) if scan_enabled and not presentation_blocked and transit_overlay.arrival_age>=float(FrontierCelestialNames.rules().arrival_seconds)-1.8 else -1
	if target!=scan_target:scan_target=target;scan_progress=0.0
	if target<0:
		transit_overlay.scan_body={};return
	var body:=FrontierUniverse.body(state.manifest,target)
	if scanned.has(body.id):scan_progress=1.0
	else:
		scan_progress=minf(1.0,scan_progress+delta/float(flight_config.get("scan_seconds",1.8)))
		if scan_progress>=1.0:
			scanned[body.id]=true;soundscape.complete();planet_scanned.emit(target)
	transit_overlay.scan_body=body
	transit_overlay.scan_progress=scan_progress

func looking_at_station() -> bool:
	if navigation.is_empty() or navigation.mode!="idle" or station_model==null:return false
	var offset:=station_model.global_position-camera.global_position
	return offset.length()>1 and offset.normalized().dot(-camera.global_basis.z)>.992
