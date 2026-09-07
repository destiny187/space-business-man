class_name FrontierCrewFlightView
extends FrontierSpaceFlight
var navigation: Dictionary={}
var orbit_clock:=0.0
var drive: FrontierVesselDriveEffects
var previous_hull:=100.0
var warning_clock:=0.0
var scan_enabled:=true
var scan_target: int=-1
var scan_progress:=0.0
var scanned: Dictionary={}
var exterior:=false
var look_offset:=Vector2.ZERO
var transit_overlay: Control
var transit_audio: FrontierAudio
var engine: AudioStreamPlayer
var last_phase: String=""
var refits: FrontierVesselVisuals
func _ready() -> void:
	test_mode=true
	flight_config=state.manifest.settings.flight
	_setup_space();_build_ui();ui_root.hide()
	ship.get_child(0).scale=Vector3.ONE*2
	drive=FrontierVesselDriveEffects.new();ship.get_child(0).add_child(drive)
	refits=FrontierVesselVisuals.new();ship.get_child(0).add_child(refits)
	_load_system(0)
	var layer:=CanvasLayer.new();add_child(layer)
	transit_overlay=load("res://scripts/ui/stellar_transit_overlay.gd").new();layer.add_child(transit_overlay)
	transit_audio=FrontierAudio.new();add_child(transit_audio)
	engine=AudioStreamPlayer.new();engine.bus="SFX";engine.stream=transit_audio.stream("sfx_robot_move",true);engine.volume_db=-26;add_child(engine)
	set_physics_process(false);set_process_unhandled_input(false)
func update_navigation(value: Dictionary) -> void:
	var render_system: int=int(value.system)
	if value.mode=="jump" and float(value.get("transit",{}).get("progress",0))>=.90:render_system=FrontierUniverse.system_index(state.manifest,int(value.target))
	if navigation.is_empty() or render_system!=current_system:
		_load_system(render_system);ship.position=_display_position(value)
	var phase:=FrontierCrewNavigation.phase(value)
	if phase!=last_phase:
		if value.mode=="jump" and last_phase in ["궤도 대기","직접 조종"]:transit_audio.play("sfx_robot_charge")
		if navigation.get("mode","")=="jump" and value.mode!="jump":transit_audio.play("ui_discovery")
		last_phase=phase
	if float(value.get("hull",100))<previous_hull and not value.get("star_warning",false):transit_audio.play("sfx_build_invalid")
	previous_hull=float(value.get("hull",100))
	orbit_clock=float(value.get("orbit_time",0))
	navigation=value.duplicate(true)
	transit_overlay.nav=navigation
	update_orbits(float(value.get("orbit_time",0)))
func _process(delta: float) -> void:
	if navigation.is_empty():return
	orbit_clock+=delta;update_orbits(orbit_clock)
	ship.position=ship.position.lerp(_display_position(navigation),minf(delta*14,1))
	var facing:=FrontierCrewWorld.vector(navigation.direction)
	if navigation.mode=="jump" and float(navigation.get("transit",{}).get("progress",0))>=.90:
		facing=(FrontierCrewNavigation.center(int(navigation.target),state.manifest,float(navigation.get("orbit_time",0)))-ship.position).normalized()
	ship.quaternion=ship.quaternion.slerp(_flight_basis(facing).get_rotation_quaternion(),minf(delta*6,1))
	camera.position=Vector3(0,16,57) if exterior else Vector3(0,2,-18)
	camera.rotation=(Vector3(-.15,0,0) if exterior else Vector3.ZERO)+Vector3(look_offset.y,look_offset.x,0)
	camera.fov=lerpf(camera.fov,minf(110.0,float(FrontierClientSettings.ensure(get_tree()).values.fov)+20) if navigation.mode=="jump" or navigation.get("boosting",false) else float(FrontierClientSettings.ensure(get_tree()).values.fov),minf(delta*3,1))

	warning_clock=maxf(0,warning_clock-delta)
	if navigation.get("star_warning",false) and warning_clock<=0:
		transit_audio.play("sfx_build_invalid");warning_clock=1.4 if navigation.get("star_danger",false) else 3.0
	if not navigation.get("star_warning",false):warning_clock=0
	_update_planet_scan(delta)
	_update_galactic_core()
	var in_transit: bool=navigation.mode=="jump"
	var p: float=navigation.get("transit",{}).get("progress",0.0)
	var visible_space: bool=not in_transit or p<.18 or p>=.90
	if system_art!=null:system_art.visible=visible_space
	for entry in planets.values():entry.node.visible=visible_space
	if galactic_core!=null and in_transit:galactic_core.hide()
	var thrust: float=clampf(absf(float(navigation.speed))/700.0,0,1)
	if in_transit:thrust=maxf(.2,sin(p*PI))
	var boosted: bool=in_transit or navigation.get("boosting",false)
	drive.set_thrust(thrust,boosted)
	if thrust>.02:
		engine.pitch_scale=.65+thrust*(.8 if boosted else .4)
		engine.volume_db=-30+thrust*(13 if boosted else 7)
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
	var p: float=value.get("transit",{}).get("progress",0)
	if value.mode=="jump" and p>=.90:
		var body:=FrontierUniverse.body(state.manifest,int(value.target))
		var target:=FrontierCrewNavigation.center(int(value.target),state.manifest,float(value.get("orbit_time",0)))
		return FrontierUniverse.entry_position(state.manifest,int(value.target),float(value.get("orbit_time",0)),(1-p)*12000)
	return FrontierCrewWorld.vector(value.position)

func _load_system(index: int) -> void:
	super._load_system(index)
	# Names belong to the gaze scanner, not permanent labels across the sky.
	for entry in planets.values():
		for node in entry.node.get_children():
			if node is Label3D:node.hide()
	if system_art!=null:
		for node in system_art.get_children():
			if node is Label3D:node.hide()

func _update_planet_scan(delta: float) -> void:
	var target: int=pick_planet(Vector2(get_viewport().get_visible_rect().size)*.5) if scan_enabled else -1
	if target!=scan_target:scan_target=target;scan_progress=0.0
	if target<0:
		transit_overlay.scan_body={};return
	var body:=FrontierUniverse.body(state.manifest,target)
	if scanned.has(body.id):scan_progress=1.0
	else:
		scan_progress=minf(1.0,scan_progress+delta/float(flight_config.get("scan_seconds",1.8)))
		if scan_progress>=1.0:
			scanned[body.id]=true;transit_audio.play("ui_discovery")
	transit_overlay.scan_body=body
	transit_overlay.scan_progress=scan_progress
