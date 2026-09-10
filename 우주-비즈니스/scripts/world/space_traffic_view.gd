class_name FrontierSpaceTrafficView
extends Node3D
var sampler:=FrontierTrafficSampler.new()
var flight: FrontierCrewFlightView
var models: Dictionary={}
var rows: Array=[]
var selected: Dictionary={}
var audio: FrontierAudio
var engine: AudioStreamPlayer
var radio: AudioStreamPlayer
var last_stages: Dictionary={}
var radio_cooldown:=0.0
var last_radio: String=""
var material_cache: Dictionary={}
var overlay: Control
func configure(view: FrontierCrewFlightView) -> void:
	flight=view
	audio=FrontierAudio.new();add_child(audio)
	engine=AudioStreamPlayer.new();engine.stream=audio.stream("sfx_vessel_engine",true);engine.volume_db=-34;engine.bus="SFX";add_child(engine)
	radio=AudioStreamPlayer.new();radio.stream=audio.stream("sfx_orbital_complete");radio.volume_db=-26;radio.bus="UI";add_child(radio)
	var layer:=CanvasLayer.new();add_child(layer);overlay=load("res://scripts/ui/space_traffic_overlay.gd").new();layer.add_child(overlay)
	for row in FrontierSpaceTraffic.all(flight.state.manifest,flight.current_system,flight.orbit_clock):
		var root:=Node3D.new();root.name=row.call_sign;add_child(root)
		var near: Node3D=load("res://assets/models/ships/"+row.model+".glb").instantiate();root.add_child(near);FrontierInkStyle.apply(near,material_cache)
		var far: Node3D=load("res://assets/models/ships/"+row.model+"_lod1.glb").instantiate();root.add_child(far);FrontierInkStyle.apply(far,material_cache);far.hide()
		var pods: Array=[];var engines: Array=[]
		for model in [near,far]:
			for n in model.find_children("Anim_Pod_*","Node3D",true,false):pods.append({"node":n,"home":n.position})
			for n in model.find_children("Anim_Engine_*","Node3D",true,false):engines.append(n)
		var plumes: Array=[]
		for socket in near.find_children("Socket_Exhaust_*","Node3D",true,false):
			var mesh:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=2.0 if row.kind=="fighter" else 3.4;shape.bottom_radius=.15;shape.height=15;mesh.mesh=shape;mesh.rotation.x=-PI*.5;mesh.position.z=7.5
			var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(.28,.75,1,.42);mesh.material_override=mat;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;socket.add_child(mesh);plumes.append(mesh)
		models[row.id]={"root":root,"near":near,"far":far,"pods":pods,"engines":engines,"plumes":plumes,"far_mode":false,"sensors":near.find_children("Anim_Sensor","Node3D",true,false),"geometry":near.find_children("*","GeometryInstance3D",true,false)+far.find_children("*","GeometryInstance3D",true,false)}
func update(delta: float,t: float,blocked: bool) -> void:
	var enabled: bool=not blocked and flight.navigation.get("mode","")!="jump"
	var focus: String=selected.get("id","")
	selected={};radio_cooldown=maxf(0,radio_cooldown-delta)
	engine.stream_paused=not enabled;radio.stream_paused=not enabled
	rows=sampler.sample(flight.state.manifest,flight.current_system,t,flight.camera.global_position,flight.navigation.get("traffic_observers",[]),flight.navigation.get("traffic_patrols",{}),focus)
	var closest:=INF;var thrust:=0.0;var best:=.992
	for row in rows:
		if not models.has(row.id):continue
		var visual: Dictionary=models[row.id];var root: Node3D=visual.root
		root.position=row.position
		var up:=Vector3.FORWARD if absf(row.direction.dot(Vector3.UP))>.98 else Vector3.UP
		var target:=Basis.looking_at(row.direction,up)
		if not root.has_meta("facing"):root.basis=target;root.set_meta("facing",true)
		else:root.quaternion=root.quaternion.slerp(target.get_rotation_quaternion(),minf(1,delta*2.5))
		var distance:=root.global_position.distance_to(flight.camera.global_position)
		var cfg:=FrontierSpaceTraffic.rules(flight.state.manifest)
		if distance>float(cfg.near_distance)*1.2:visual.far_mode=true
		elif distance<float(cfg.near_distance):visual.far_mode=false
		visual.near.visible=not visual.far_mode;visual.far.visible=visual.far_mode
		# Keep stable objects through camera turns; fade only beyond useful silhouette scale.
		for geometry in visual.geometry:geometry.transparency=smoothstep(float(cfg.far_distance)*.8,float(cfg.far_distance),distance)
		var power:=.6 if row.stage in ["ascend","cruise","patrol","inspect_approach","return"] else (.15 if row.stage in ["depart","dock","descend"] else 0.0)
		for plume in visual.plumes:plume.visible=power>0;plume.scale.y=.3+power
		for pivot in visual.engines:pivot.rotation.x=sin(t*1.2+int(row.index))*.045*power
		for sensor in visual.sensors:sensor.rotation.y=sin(t*2.0)*.55 if row.stage=="inspect" else 0.0
		if row.kind=="fighter":root.rotate_object_local(Vector3.FORWARD,float(row.bank)*delta*2.5)
		var lost_pod:=FrontierFreightSalvage.missing_pod(flight.state.manifest,row)
		for i in visual.pods.size():
			var pod: Dictionary=visual.pods[i];var transfer:=0.0
			if row.stage=="unload":transfer=smoothstep(float(i%4)*.18,float(i%4)*.18+.4,float(row.u))
			elif row.stage=="load":transfer=1.0-smoothstep(float(i%4)*.18,float(i%4)*.18+.4,float(row.u))
			pod.node.visible=transfer<.995 and not (i%4==0 and lost_pod)
			pod.node.position=pod.home+Vector3(signf(pod.home.x)*60*smoothstep(.45,1,transfer),38*sin(transfer*PI*.5),0)
		if row.kind=="freighter":_crane(row,t)
		if distance<closest:closest=distance;thrust=power
		var offset:=root.global_position-flight.camera.global_position
		var dot:=offset.normalized().dot(-flight.camera.global_basis.z)
		if enabled and flight.scan_enabled and distance<11000 and dot>best and not occluded(root.global_position):best=dot;selected=row.duplicate();selected.distance=distance
		var key: String=row.stage+":"+str(row.leg)
		if last_stages.has(row.id) and last_stages[row.id]!=key and enabled and distance<6500 and radio_cooldown<=0 and row.stage in ["depart","wait","unload","inspect","return"]:
			last_radio=row.call_sign+"  "+row.label;radio_cooldown=15
			if radio.stream!=null:radio.play()
		last_stages[row.id]=key
	var gain:=thrust*(1.0-smoothstep(300,4000,closest)) if enabled else 0.0
	engine.volume_db=lerpf(engine.volume_db,-34+linear_to_db(maxf(.001,gain)),minf(1,delta*3));engine.pitch_scale=.78+thrust*.2
	if gain>.001 and engine.stream!=null and not engine.playing:engine.play()
	elif gain<=.001:engine.stop()
	overlay.row=selected;overlay.radio_text=last_radio if radio_cooldown>11 and enabled else "";overlay.queue_redraw()
func _crane(row: Dictionary,t: float) -> void:
	var id: String=row.from
	var ports: Dictionary=flight.station_models if flight.station_models.has(id) else flight.corporate_models
	if not ports.has(id):return
	var node:=ports[id].find_child("Anim_Crane_"+str(row.side),true,false) as Node3D
	if node!=null:node.rotation.y=sin(float(row.u)*TAU*2)*.35 if row.stage in ["load","unload"] else 0.0
func suspend() -> void:
	engine.stop();radio.stop();overlay.row={};overlay.radio_text="";overlay.queue_redraw()
func occluded(point: Vector3) -> bool:
	var origin:=flight.camera.global_position;var ray:=point-origin;var distance:=ray.length();ray=ray.normalized()
	for entry in flight.planets.values():
		var offset: Vector3=entry.node.global_position-origin;var along:=offset.dot(ray)
		if along>0 and along<distance and (offset-ray*along).length()<float(entry.radius):return true
	var along:=(-origin).dot(ray)
	return along>0 and along<distance and (-origin-ray*along).length()<float(FrontierUniverse.star_settings(flight.state.manifest,flight.current_system).star_radius)
