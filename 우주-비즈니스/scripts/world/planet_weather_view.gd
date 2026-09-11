class_name FrontierPlanetWeatherView
extends Node3D
## Bounded local precipitation. Ground/roof samples clip drops before interiors.
var surface: FrontierCrewSurfaceScene
var camera: Camera3D
var drops: MultiMeshInstance3D
var splashes: MultiMeshInstance3D
var columns: Array=[]
var tick:=0.0
var elapsed:=0.0
var wet:=0.0
var strength:=0.0
var rain: AudioStreamPlayer
var acid: AudioStreamPlayer
var thunder: AudioStreamPlayer3D
var layer: CanvasLayer
var badge: FrontierWeatherBadge
var bolts: Dictionary={}
var last_event:=-1
var notice_serial:=-1
var alert: AudioStreamPlayer
var rain_material: StandardMaterial3D
func configure(owner_surface: FrontierCrewSurfaceScene,view_camera: Camera3D) -> void:
	surface=owner_surface;camera=view_camera
	drops=batch(240,false);splashes=batch(48,true)
	rain=audio_loop("amb_weather_rain");acid=audio_loop("amb_weather_acid")
	thunder=AudioStreamPlayer3D.new();thunder.stream=load("res://assets/audio/sfx_weather_thunder.wav");thunder.bus="SFX";thunder.max_distance=180;thunder.unit_size=18;thunder.volume_db=-3;add_child(thunder)
	alert=AudioStreamPlayer.new();alert.stream=load("res://assets/audio/sfx_incident_beacon.wav");alert.bus="SFX";alert.volume_db=-13;add_child(alert)
	layer=CanvasLayer.new();layer.layer=24;add_child(layer);badge=FrontierWeatherBadge.new();layer.add_child(badge)
func audio_loop(id: String) -> AudioStreamPlayer:
	var player:=AudioStreamPlayer.new();var stream: AudioStreamWAV=load("res://assets/audio/"+id+".wav").duplicate();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=roundi(stream.get_length()*stream.mix_rate);player.stream=stream;player.bus="Ambience" if AudioServer.get_bus_index("Ambience")>=0 else "SFX";player.volume_db=-80;add_child(player);return player
func batch(count: int,splash: bool) -> MultiMeshInstance3D:
	var node:=MultiMeshInstance3D.new();var mesh: PrimitiveMesh
	if splash:
		var ring:=TorusMesh.new();ring.inner_radius=.12;ring.outer_radius=.15;ring.rings=8;ring.ring_segments=4;mesh=ring
	else:
		var streak:=CylinderMesh.new();streak.top_radius=.008;streak.bottom_radius=.012;streak.height=.58;streak.radial_segments=3;mesh=streak
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("96b7bd");mesh.material=material
	if not splash:rain_material=material
	node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=mesh;node.multimesh.instance_count=count;node.multimesh.visible_instance_count=0;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node
func _physics_process(delta: float) -> void:
	if surface==null or camera==null:return
	tick-=delta
	if tick>0 or strength<.01:return
	tick=.4;columns.clear()
	var center:=camera.global_position;var space:=get_world_3d().direct_space_state
	for i in 48:
		var x:=center.x+float(i%8)*4-14;var z:=center.z+float(i/8)*4-10
		var top:=Vector3(x,center.y+14,z);var floor_y:=surface.terrain.field.height(x,z)
		var query:=PhysicsRayQueryParameters3D.create(top,Vector3(x,center.y-35,z),1)
		var hit:=space.intersect_ray(query)
		if not hit.is_empty():floor_y=maxf(floor_y,float(hit.position.y))
		columns.append({"top":top,"floor":floor_y})
func _process(delta: float) -> void:
	if surface==null:return
	elapsed+=delta
	var state: Dictionary=surface.session.latest.get("weather",{})
	var active: bool=surface.session.active and state.get("body_id","")==surface.body.id and camera!=null and camera.current
	var e: Dictionary=state.get("event",{}) if active else {}
	var clock:=float(state.get("clock",0));var desired:=FrontierPlanetWeather.intensity(e,clock,camera.global_position) if active else 0.0
	strength=move_toward(strength,desired,delta*.6);wet=move_toward(wet,strength,delta*(.09 if strength>wet else .025))
	visible=active
	var in_front: bool=not e.is_empty() and Vector2(camera.global_position.x-float(e.center[0]),camera.global_position.z-float(e.center[2])).length()<float(FrontierPlanetWeather.config().front_radius)
	var display_state: Dictionary=state.duplicate(false)
	if e.get("kind","")=="acid" and float(state.get("personal",{}).get("acid_factor",1))<=.01:
		display_state.event=e.duplicate();display_state.event.kind="rain"
	badge.visible=active and in_front;badge.accept(display_state if active and in_front else {},strength)
	surface.atmosphere.weather_strength=strength
	surface.terrain.material.set_shader_parameter("weather_wet",wet)
	if active and int(e.get("serial",-1))!=notice_serial:
		notice_serial=int(e.get("serial",-1))
		if e.get("kind","") in ["acid","thunder"] and clock<float(e.get("start",0)):alert.play()
	var personal: Dictionary=state.get("personal",{})
	var sheltered:=bool(personal.get("sheltered",true));var acid_amount:=float(personal.get("acid_factor",0)) if e.get("kind","")=="acid" else 0.0
	rain_material.albedo_color=Color("96b7bd").lerp(Color("d8ce81"),acid_amount*.7)
	loop_volume(rain,strength*(.25 if sheltered else 1.0),-7,delta)
	loop_volume(acid,strength*acid_amount*(.35 if sheltered else .7),-13,delta)
	drops.multimesh.visible_instance_count=0;splashes.multimesh.visible_instance_count=0
	if strength>.02 and not columns.is_empty() and active:
		var count:=roundi(240*strength);drops.multimesh.visible_instance_count=count
		for i in count:
			var column: Dictionary=columns[i%columns.size()];var top: Vector3=column.top;var span:=maxf(0,top.y-float(column.floor))
			var phase:=fposmod(elapsed*(13.0+float(i%3))+float(i)*1.713,maxf(.01,span))
			var p:=Vector3(top.x,top.y-phase,top.z)
			var scale_y:=minf(1.0,maxf(0,p.y-float(column.floor))/.58) if span>.6 else 0.0
			drops.multimesh.set_instance_transform(i,Transform3D(Basis().scaled(Vector3(1,scale_y,1)),p))
		splashes.multimesh.visible_instance_count=columns.size()
		for i in columns.size():
			var column: Dictionary=columns[i];var phase:=fposmod(elapsed*2.4+float(i)*.731,1.0);var top: Vector3=column.top
			splashes.multimesh.set_instance_transform(i,Transform3D(Basis().scaled(Vector3.ONE*phase*strength),Vector3(top.x,float(column.floor)+.03,top.z)))
	update_bolts(e,clock,active)
func loop_volume(player: AudioStreamPlayer,amount: float,volume: float,delta: float) -> void:
	player.volume_db=move_toward(player.volume_db,volume+linear_to_db(maxf(.0001,amount)),delta*35)
	if amount>.005 and not player.playing:player.play()
	elif amount<=.005 and player.volume_db<-65:player.stop()
func update_bolts(e: Dictionary,clock: float,active: bool) -> void:
	var serial:=int(e.get("serial",-1))
	if serial!=last_event or not active:
		for node in bolts.values():node.queue_free()
		bolts.clear();last_event=serial
	if not active:return
	for row in e.get("strikes",[]):
		var id:=int(row.id);var p:=FrontierCrewWorld.vector(row.point);var age:=clock-float(row.at)
		if age>1.0:
			if bolts.has(id):bolts[id].queue_free();bolts.erase(id)
			continue
		if not bolts.has(id):
			var root:=Node3D.new();root.position=p;add_child(root);bolts[id]=root;root.set_meta("played",false)
			var marker:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.45 if row.grounded else 2.85;ring.outer_radius=.60 if row.grounded else 3.0;ring.rings=32;ring.ring_segments=4;marker.mesh=ring;marker.position.y=.05;marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(marker)
			var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("8be2c1") if row.grounded else Color("ffc176");marker.material_override=mat
			var beam:=MeshInstance3D.new();beam.name="Discharge";beam.mesh=lightning(id);beam.material_override=mat;beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(beam)
		var root: Node3D=bolts[id];root.get_child(0).visible=age<0;root.get_child(1).visible=age>=0 and age<.3
		if age>=0 and not root.get_meta("played"):
			root.set_meta("played",true)
			if age<.8:thunder.position=p;thunder.play()
func lightning(seed_value: int) -> ImmediateMesh:
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous:=Vector3.ZERO
	for i in range(1,10):
		var point:=Vector3(sin(float(seed_value+i)*4.7)*1.7,float(i)*5.0,cos(float(seed_value+i)*2.3)*1.7)
		var side:=Vector3(.08,0,.08)
		for vertex in [previous-side,previous+side,point+side,previous-side,point+side,point-side]:mesh.surface_add_vertex(vertex)
		previous=point
	mesh.surface_end();return mesh
