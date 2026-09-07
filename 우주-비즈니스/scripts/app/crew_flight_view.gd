class_name FrontierCrewFlightView
extends FrontierSpaceFlight
var navigation: Dictionary={}
var exterior:=false
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
	refits=FrontierVesselVisuals.new();ship.get_child(0).add_child(refits)
	_load_system(0)
	var layer:=CanvasLayer.new();add_child(layer)
	transit_overlay=load("res://scripts/ui/stellar_transit_overlay.gd").new();layer.add_child(transit_overlay)
	transit_audio=FrontierAudio.new();add_child(transit_audio)
	engine=AudioStreamPlayer.new();engine.bus="SFX";engine.stream=transit_audio.stream("sfx_robot_move",true);engine.volume_db=-26;add_child(engine)
	set_physics_process(false);set_process_unhandled_input(false)
func update_navigation(value: Dictionary) -> void:
	var render_system: int=int(value.system)
	if value.mode=="jump" and float(value.get("transit",{}).get("progress",0))>=.90:render_system=int(value.target)/int(state.manifest.settings.planets_per_system)
	if navigation.is_empty() or render_system!=current_system:
		_load_system(render_system);ship.position=_display_position(value)
	var phase:=FrontierCrewNavigation.phase(value)
	if phase!=last_phase:
		if value.mode=="jump" and last_phase in ["궤도 대기","직접 조종"]:transit_audio.play("sfx_robot_charge")
		if navigation.get("mode","")=="jump" and value.mode!="jump":transit_audio.play("ui_discovery")
		last_phase=phase
	navigation=value.duplicate(true)
	transit_overlay.nav=navigation
	update_orbits(float(value.get("orbit_time",0)))
func _process(delta: float) -> void:
	if navigation.is_empty():return
	ship.position=ship.position.lerp(_display_position(navigation),minf(delta*14,1))
	var facing:=FrontierCrewWorld.vector(navigation.direction)
	if navigation.mode=="jump" and float(navigation.get("transit",{}).get("progress",0))>=.90:
		facing=(FrontierCrewNavigation.center(int(navigation.target),state.manifest,float(navigation.get("orbit_time",0)))-ship.position).normalized()
	ship.quaternion=ship.quaternion.slerp(_flight_basis(facing).get_rotation_quaternion(),minf(delta*6,1))
	camera.position=Vector3(0,16,57) if exterior else Vector3(0,2,-18)
	camera.rotation=Vector3(-.15,0,0) if exterior else Vector3.ZERO
	camera.fov=lerpf(camera.fov,minf(110.0,float(FrontierClientSettings.ensure(get_tree()).values.fov)+20) if navigation.mode=="jump" else float(FrontierClientSettings.ensure(get_tree()).values.fov),minf(delta*3,1))

	_update_galactic_core()
	var in_transit: bool=navigation.mode=="jump"
	var p: float=navigation.get("transit",{}).get("progress",0.0)
	var visible_space: bool=not in_transit or p<.18 or p>=.90
	if system_art!=null:system_art.visible=visible_space
	for entry in planets.values():entry.node.visible=visible_space
	if galactic_core!=null and in_transit:galactic_core.hide()
	if in_transit:
		engine.pitch_scale=.7+sin(p*PI)*.8
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
		return target+target.normalized()*(FrontierUniverse.navigation_radius(body)+float(flight_config.arrival_clearance)+1200+(1-p)*12000)
	return FrontierCrewWorld.vector(value.position)
