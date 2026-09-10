class_name FrontierCrewFlightView
extends FrontierSpaceFlight
signal planet_scanned(ordinal: int)
var navigation: Dictionary={}
var announced_system: int=-1
var orbit_clock:=0.0
var drive: FrontierVesselDriveEffects
var opening_clock:=0.0
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
var transition_preparing:=false
var pending_navigation: Dictionary={}
var visual_suspended:=false
var engine: AudioStreamPlayer
var vessel_sound: FrontierVesselSound
var last_phase: String=""
var station_excluded: int=-1
var station_model: Node3D
var station_models: Dictionary={}
var traffic: FrontierSpaceTrafficView
var corporate_models: Dictionary={}
var corporate_view: FrontierCorporateSiteView
var freight_view: FrontierFreightSalvageView
var freight_records: Dictionary={}
var freight_activity: Array=[]
var freight_vessels: Array=[]
var freight_carrier: String="crew"
var freight_pilot:=false
var trace_view: FrontierCorporateTraceView
var trace_records: Dictionary={}
var trace_scan: Dictionary={}
var departure_heading:=Vector3.FORWARD
var departure_initial:=Vector3.FORWARD
var departure_origin:=Vector3.ZERO
var arrival_heading:=Vector3.FORWARD
var transit_clock:=0.0
var transit_camera_rotation:=Quaternion.IDENTITY
var transit_geometry: Array[GeometryInstance3D]=[]
var refits: FrontierVesselVisuals
var orbital_debris: FrontierOrbitalDebris
var engine_turn:=Vector2.ZERO
var engine_brake:=0.0
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
	vessel_sound=FrontierVesselSound.new();add_child(vessel_sound);engine=vessel_sound.layers.turbine
	set_physics_process(false);set_process_unhandled_input(false)
func _visual_hidden() -> bool:
	var viewport:=get_viewport()
	return viewport is SubViewport and viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED

func update_navigation(value: Dictionary) -> void:
	# Arrival owns camera motion and may need system preparation behind its cover.
	if _visual_hidden() and not transition_preparing:
		pending_navigation=value.duplicate(true)
		return
	pending_navigation={}
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
		var arrival_time:=float(value.get("orbit_time",0))+float(value.jump_left)
		arrival_heading=(FrontierUniverse.entry_focus(state.manifest,int(value.target),arrival_time)-FrontierUniverse.entry_position(state.manifest,int(value.target),arrival_time)).normalized()
		transit_clock=float(route.get("duration",12))*float(route.get("progress",0))
		transit_camera_rotation=ship.quaternion if not initial_view else _flight_basis(departure_initial).get_rotation_quaternion()
		transit_overlay.arrival_age=100.0
	if value.mode=="jump":
		transit_clock=maxf(transit_clock,float(value.get("transit",{}).get("duration",12))*float(value.get("transit",{}).get("progress",0)))
		prepare_system(FrontierUniverse.system_index(state.manifest,int(value.target)))
	var render_system: int=int(value.system)
	if value.mode=="jump" and FrontierCrewNavigation.transit_progress(value)>=float(FrontierUniverse.presentation().stellar_transition.swap_progress):render_system=FrontierUniverse.system_index(state.manifest,int(value.target))
	if navigation.is_empty() or render_system!=current_system:
		_load_system(render_system);ship.position=_display_position(value)
		if initial_view:
			ship.quaternion=_transit_rotation(value) if value.mode=="jump" else _flight_basis(FrontierCrewWorld.vector(value.direction)).get_rotation_quaternion()
			transit_camera_rotation=ship.quaternion
	_apply_transit_visibility(value)
	if render_system!=announced_system and value.mode!="jump":
		announced_system=render_system
		var system:=FrontierUniverse.system(state.manifest,render_system)
		if not solar_start or FrontierSolarOpening.active(value):soundscape.enter(int(system.band))
		if FrontierSolarOpening.active(value) or not solar_start:transit_overlay.announce(system.star.name,not FrontierSolarOpening.active(value) and (initial_view or value.get("transit",{}).get("revisit",false)))
	var phase:=FrontierCrewNavigation.phase(value)
	if phase!=last_phase:
		last_phase=phase
	if float(value.get("hull",100))<previous_hull and not value.get("star_warning",false):transit_audio.play("sfx_build_invalid")
	var braking: bool=value.mode!="jump" and (value.get("proximity_braking",false) or (float(navigation.get("speed",0))>60 and float(value.speed)<float(navigation.get("speed",0))-5))
	previous_braking=braking
	previous_hull=float(value.get("hull",100))
	orbit_clock=float(value.get("orbit_time",0))
	if not navigation.is_empty():
		var dt:=maxf(.02,float(value.get("orbit_time",0))-float(navigation.get("orbit_time",0)))
		var next_direction:=FrontierCrewWorld.vector(value.direction)
		var local_turn:=_flight_basis(FrontierCrewWorld.vector(navigation.direction)).inverse()*next_direction
		engine_turn=Vector2(clampf(local_turn.x/dt,-1,1),clampf(local_turn.y/dt,-1,1))
		engine_brake=clampf((absf(float(navigation.speed))-absf(float(value.speed)))/dt/300.0,0,1)
		if float(value.speed)<-1:engine_brake=maxf(engine_brake,clampf(absf(float(value.speed))/700.0,0,1))
	navigation=value.duplicate(true)
	if FrontierSolarOpening.active(value):opening_clock=float(value.solar_opening.elapsed)
	transit_overlay.nav=navigation
	transit_overlay.telemetry=FrontierFlightTelemetry.read(state.manifest,navigation)
	update_orbits(float(value.get("orbit_time",0)))
func _process(delta: float) -> void:
	if _visual_hidden():
		if not visual_suspended:
			visual_suspended=true;vessel_sound.suspend();soundscape.scan.stop();soundscape.arrival.stream_paused=true
			if is_instance_valid(traffic):traffic.suspend()
			if is_instance_valid(corporate_view):corporate_view.update(orbit_clock,true)
			if is_instance_valid(trace_view):trace_view.update(orbit_clock,true)
			if is_instance_valid(freight_view):freight_view.update(0,orbit_clock,true)
			scan_target=-1;scan_progress=0.0;transit_overlay.scan_body={}
		return
	visual_suspended=false
	if not pending_navigation.is_empty():
		update_navigation(pending_navigation)
		ship.position=_display_position(navigation)
		ship.quaternion=_transit_rotation(navigation) if navigation.mode=="jump" else _flight_basis(FrontierCrewWorld.vector(navigation.direction)).get_rotation_quaternion()
		transit_camera_rotation=ship.quaternion
	if navigation.is_empty():return
	if navigation.mode=="jump":step_preparation()
	var presentation_paused:=presentation_blocked or get_tree().has_meta("startup_loader")
	var opening:=FrontierSolarOpening.active(navigation)
	soundscape.blocked=presentation_paused
	transit_overlay.presentation_blocked=presentation_paused
	transit_overlay.opening=opening
	engine.stream_paused=presentation_paused
	orbit_clock+=delta;update_orbits(orbit_clock)
	var presented:=_transit_presentation(delta,presentation_paused)
	transit_overlay.nav=presented
	ship.position=_display_position(presented) if navigation.mode=="jump" else ship.position.lerp(_display_position(navigation),minf(delta*14,1))
	var facing:=FrontierCrewWorld.vector(navigation.direction)
	if navigation.mode=="jump":
		var previous_basis:=ship.basis
		ship.quaternion=_transit_rotation(presented)
		var local_turn:=previous_basis.inverse()*(-ship.basis.z)
		engine_turn=Vector2(clampf(local_turn.x/maxf(delta,.001),-1,1),clampf(local_turn.y/maxf(delta,.001),-1,1))
	else:ship.quaternion=ship.quaternion.slerp(_flight_basis(facing).get_rotation_quaternion(),1.0-exp(-delta*6.0))
	camera.position=(Vector3(0,8,21) if refits.hull_id=="finch" else Vector3(0,16,57)) if exterior else (Vector3(0,5.3,-1.2) if refits.hull_id=="finch" else Vector3(0,2,-18))
	camera.rotation=(Vector3(-.15,0,0) if exterior else Vector3.ZERO)+Vector3(look_offset.y,look_offset.x,0)
	if navigation.mode=="jump":
		transit_camera_rotation=transit_camera_rotation.slerp(ship.quaternion,1.0-exp(-delta*float(FrontierUniverse.presentation().stellar_transition.camera_follow_speed)))
		var follow_basis:=Basis(transit_camera_rotation)
		var local_camera:=camera.transform
		camera.global_position=ship.position+follow_basis*local_camera.origin
		camera.global_basis=follow_basis*local_camera.basis
	var base_fov:=float(FrontierClientSettings.ensure(get_tree()).values.fov)
	if navigation.mode=="jump":camera.fov=_transit_fov(presented,base_fov)
	else:camera.fov=lerpf(camera.fov,minf(110.0,base_fov+20) if navigation.get("boosting",false) else base_fov,minf(delta*3,1))

	if opening:
		if not presentation_paused:opening_clock=minf(float(navigation.solar_opening.elapsed)+.2,opening_clock+delta)
		var shot:=FrontierSolarOpening.pose(navigation.solar_opening,opening_clock)
		ship.position=shot.position;ship.quaternion=shot.rotation
		camera.position=FrontierCrewWorld.vector(FrontierSolarOpening.config().camera_start).lerp(Vector3(0,16,57),shot.turn)
		camera.rotation=Vector3(-.15*float(shot.turn),0,0)
		var finish_fov:=float(FrontierClientSettings.ensure(get_tree()).values.fov)
		camera.fov=lerpf(float(FrontierSolarOpening.config().fov),finish_fov,shot.turn)
		transit_overlay.arrival_age=opening_clock
		engine_brake=.65 if absf(float(navigation.speed))>1 else 0.0

	warning_clock=maxf(0,warning_clock-delta)
	if navigation.get("star_warning",false) and warning_clock<=0 and not presentation_blocked:
		transit_audio.play("sfx_stellar_warning");warning_clock=2.2 if navigation.get("star_danger",false) else 4.0
	if not navigation.get("star_warning",false):warning_clock=0
	transit_overlay.guidance=FrontierSpaceGuidance.read(state.manifest,navigation,camera,Vector2(get_viewport().get_visible_rect().size))
	if is_instance_valid(traffic):traffic.update(delta,orbit_clock,presentation_paused or opening)
	if is_instance_valid(trace_view):trace_view.update(orbit_clock,presentation_paused or opening)
	if is_instance_valid(corporate_view):corporate_view.update(orbit_clock,presentation_paused or opening)
	if is_instance_valid(freight_view):freight_view.update(delta,orbit_clock,presentation_paused or opening)
	if opening:scan_target=-1;scan_progress=0.0;transit_overlay.scan_body={}
	else:_update_planet_scan(delta)
	var site_scanning: bool=is_instance_valid(corporate_view) and not corporate_view.selected.is_empty() and corporate_view.progress<1.0
	var trace_scanning: bool=(is_instance_valid(trace_view) and trace_view.scanning) or (is_instance_valid(freight_view) and freight_view.scanning)
	soundscape.update(delta,trace_scanning or (scan_target>=0 and scan_progress<1.0) or site_scanning,float(trace_scan.get("progress",0)) if trace_scanning else (corporate_view.progress if site_scanning else scan_progress))
	orbital_presentation.update(delta,orbit_clock)
	_update_galactic_core()
	var in_transit: bool=navigation.mode=="jump"
	var p: float=FrontierCrewNavigation.transit_progress(presented)
	_apply_transit_visibility(presented)
	if galactic_core!=null and in_transit:galactic_core.hide()
	var thrust: float=clampf(absf(float(navigation.speed))/700.0,0,1)
	if in_transit:thrust=0.0 if p<float(FrontierUniverse.presentation().stellar_transition.departure_start) else maxf(.2,sin(p*PI))
	var boosted: bool=in_transit or navigation.get("boosting",false)
	if not in_transit:thrust*=1.0-engine_brake
	drive.set_thrust(thrust,boosted)
	drive.set_motion(engine_turn,engine_brake,presentation_paused)
	vessel_sound.update(delta,navigation,thrust,engine_turn,engine_brake,refits.hull_id=="finch",exterior,presentation_paused)

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
	var p: float=FrontierCrewNavigation.transit_progress(value)
	var midpoint: float=cfg.swap_progress
	if p>=midpoint:
		var elapsed: float=value.get("orbit_time",0)
		var entry:=FrontierUniverse.entry_position(state.manifest,int(value.target),elapsed)
		var focus:=FrontierUniverse.entry_focus(state.manifest,int(value.target),elapsed)
		return entry+(entry-focus).normalized()*float(cfg.distant_offset)*(1.0-smoothstep(midpoint,1.0,p))
	return departure_origin+departure_heading*float(cfg.distant_offset)*smoothstep(float(cfg.departure_start),midpoint,p)

func _transit_presentation(delta: float,paused: bool) -> Dictionary:
	if navigation.mode!="jump":return navigation
	var cfg: Dictionary=FrontierUniverse.presentation().stellar_transition
	var route: Dictionary=navigation.get("transit",{})
	var duration:=maxf(1.0,float(route.get("duration",12)))
	var host_progress:=float(route.get("progress",0))
	if not paused:transit_clock=minf(host_progress*duration+float(cfg.progress_lead_seconds),transit_clock+delta)
	var progress:=minf(transit_clock/duration,1.0)
	# Never display destination coordinates before the host swaps the loaded system.
	var swap:=FrontierCrewNavigation.elapsed_progress(route,float(cfg.swap_progress))
	if host_progress<swap:progress=minf(progress,swap-.00001)
	var result:=navigation.duplicate()
	result.transit=route.duplicate();result.transit.progress=progress
	return result

func _transit_fov(value: Dictionary,base_fov: float) -> float:
	var cfg: Dictionary=FrontierUniverse.presentation().stellar_transition
	var p:=FrontierCrewNavigation.transit_progress(value)
	var gain:=smoothstep(float(cfg.departure_start),float(cfg.fov_acceleration_end),p)*(1.0-smoothstep(float(cfg.fov_deceleration_start),float(cfg.fov_deceleration_end),p))
	return lerpf(base_fov,minf(110,base_fov+float(cfg.fov_gain)),gain)

func _transit_rotation(value: Dictionary) -> Quaternion:
	var cfg: Dictionary=FrontierUniverse.presentation().stellar_transition
	var progress:=float(FrontierCrewNavigation.transit_progress(value))
	var departure:=_flight_basis(departure_heading).get_rotation_quaternion()
	if progress<float(cfg.departure_start):
		return _flight_basis(departure_initial).get_rotation_quaternion().slerp(departure,smoothstep(0,float(cfg.departure_start),progress))
	# Carry the turn through the hidden system swap instead of changing facing at its boundary.
	return departure.slerp(_flight_basis(arrival_heading).get_rotation_quaternion(),smoothstep(float(cfg.departure_fade_start),float(cfg.arrival_fade_end),progress))

func _apply_transit_visibility(value: Dictionary) -> void:
	var opacity:=1.0
	if value.mode=="jump":
		var cfg: Dictionary=FrontierUniverse.presentation().stellar_transition
		var p: float=FrontierCrewNavigation.transit_progress(value)
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
	station_model=null;station_models.clear()
	for station in FrontierSpaceStation.all(state.manifest,index,station_excluded,orbit_time):
		var model: Node3D=load(station.get("model",FrontierSpaceStation.config().model)).instantiate()
		model.position=FrontierCrewWorld.vector(station.position)
		FrontierInkStyle.apply(model,cache);system_art.add_child(model);station_models[station.id]=model
		if station_model==null:station_model=model
	corporate_models.clear()
	for site in FrontierCorporateSites.all(state.manifest,index,orbit_time):
		var model: Node3D=load(site.model).instantiate();model.position=FrontierCrewWorld.vector(site.position)
		FrontierInkStyle.apply(model,cache);system_art.add_child(model);corporate_models[site.id]=model
	corporate_view=FrontierCorporateSiteView.new();system_art.add_child(corporate_view);corporate_view.configure(self)
	trace_view=FrontierCorporateTraceView.new();system_art.add_child(trace_view);trace_view.configure(self)
	freight_view=FrontierFreightSalvageView.new();system_art.add_child(freight_view);freight_view.configure(self)
	traffic=null
	if not FrontierSpaceTraffic.all(state.manifest,index,orbit_time).is_empty():
		traffic=FrontierSpaceTrafficView.new();system_art.add_child(traffic);traffic.configure(self)
	orbital_presentation.collect(system_art)
	orbital_debris=FrontierOrbitalDebris.new();system_art.add_child(orbital_debris);orbital_debris.configure(self)
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
	var target: int=pick_planet(Vector2(get_viewport().get_visible_rect().size)*.5) if scan_enabled and not presentation_blocked and not transit_overlay.presenting_arrival() else -1
	if is_instance_valid(traffic) and not traffic.selected.is_empty():target=-1
	if is_instance_valid(corporate_view) and not corporate_view.selected.is_empty():target=-1
	if is_instance_valid(trace_view) and not trace_view.selected.is_empty():target=-1
	if is_instance_valid(freight_view) and not freight_view.selected.is_empty():target=-1
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

func update_orbits(elapsed: float) -> void:
	super.update_orbits(elapsed)
	for station in FrontierSpaceStation.all(state.manifest,current_system,station_excluded,elapsed):
		if station_models.has(station.id) and is_instance_valid(station_models[station.id]):station_models[station.id].position=FrontierCrewWorld.vector(station.position)
	for site in FrontierCorporateSites.all(state.manifest,current_system,elapsed):
		if corporate_models.has(site.id):corporate_models[site.id].position=FrontierCrewWorld.vector(site.position)
func station_in_sight() -> String:
	if navigation.is_empty() or navigation.mode!="idle":return ""
	var best: String="";var alignment:=.992
	for id in station_models:
		var node: Node3D=station_models[id]
		if not is_instance_valid(node):continue
		var offset:=node.global_position-camera.global_position
		var dot:=offset.normalized().dot(-camera.global_basis.z)
		if offset.length()>1 and dot>alignment:
			# A planet must not become transparent to an occluded port interaction.
			var hidden:=false
			for entry in planets.values():
				var delta: Vector3=entry.node.global_position-camera.global_position
				var along:=delta.dot(offset.normalized())
				if along>0 and along<offset.length() and (delta-offset.normalized()*along).length()<float(entry.radius):hidden=true;break
			if not hidden:best=id;alignment=dot
	return best
func looking_at_station() -> bool:return not station_in_sight().is_empty()
