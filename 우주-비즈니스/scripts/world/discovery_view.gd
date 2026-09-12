class_name FrontierDiscoveryView
extends Node3D
## Scene presentation reads host state. The scanner and F command own all progress.
var surface: FrontierCrewSurfaceScene
var camera: Camera3D
var app: FrontierCrewExpedition
var rows: Dictionary={}
var models: Dictionary={}
var markers: Dictionary={}
var pending: Dictionary={}
var scenes: Dictionary={}
var cache: Dictionary={}
var audio: FrontierAudio
var ambience: AudioStreamPlayer3D
var hint: Label
var tick:=0.0
var elapsed:=0.0
var selected: Dictionary={}
var parts: Dictionary={}
var previous_stages: Dictionary={}
var current_sound:=""
var serial:=0
func configure(owner_surface: FrontierCrewSurfaceScene,eye: Camera3D) -> void:
	surface=owner_surface;camera=eye;app=surface.session.get_parent() as FrontierCrewExpedition
	if app==null:app=surface.get_tree().current_scene as FrontierCrewExpedition
	audio=FrontierAudio.new();add_child(audio)
	ambience=AudioStreamPlayer3D.new();ambience.bus="Ambience";ambience.max_distance=38;ambience.unit_size=7;ambience.volume_db=-25;add_child(ambience)
	var layer:=CanvasLayer.new();add_child(layer)
	hint=Label.new();hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.add_theme_color_override("font_shadow_color",Color.BLACK);hint.add_theme_constant_override("shadow_offset_x",2);hint.add_theme_constant_override("shadow_offset_y",2);hint.add_theme_font_size_override("font_size",16);layer.add_child(hint)
	surface.session.response_received.connect(_response)
func context() -> Dictionary:
	return {"manifest":surface.session.manifest,"location":surface.body.id,"crew":surface.session.latest.crew,"discoveries":surface.session.latest.get("discoveries",{}),"terrain_edits":{surface.body.id:surface.incoming}}
func refresh() -> void:
	var p: Vector3=surface.viewer.position
	var active: Dictionary={}
	for row in FrontierExplorationDiscoveries.nearby(surface.body,surface.terrain.field,p):
		if FrontierCrewWorld.vector(row.position).distance_to(p)>float(FrontierExplorationDiscoveries.config().view_distance):continue
		active[row.id]=row;rows[row.id]=row
		if models.has(row.id):continue
		var path: String="res://assets/models/"+str(FrontierExplorationDiscoveries.definition(row.template).model)+".glb"
		if not scenes.has(path):
			if not pending.has(path):ResourceLoader.load_threaded_request(path);pending[path]=true
			if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:continue
			scenes[path]=ResourceLoader.load_threaded_get(path)
		var scene: PackedScene=scenes[path]
		var model: Node3D=scene.instantiate();add_child(model);model.position=FrontierCrewWorld.vector(row.position);model.rotation.y=float(row.yaw);FrontierInkStyle.apply(model,cache)
		models[row.id]=model
		if FrontierExplorationDiscoveries.definition(row.template).mode=="archive":
			var blueprint:=FrontierFacilityBlueprints.archive_blueprint(context(),row)
			var def: Dictionary=FrontierFacilityBlueprints.definitions()[blueprint]
			var projection: Node3D=load("res://assets/models/"+str(def.model)+".glb").instantiate();projection.name="ArchiveProjection";model.add_child(projection);projection.position=Vector3(0,1.15,1.0);projection.scale=Vector3.ONE*(.18 if def.building=="factory" else .35)
			var hologram:=StandardMaterial3D.new();hologram.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;hologram.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;hologram.albedo_color=Color(.3,.95,.8,.45)
			for mesh in projection.find_children("*","MeshInstance3D",true,false):mesh.material_override=hologram;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parts[row.id]={"rotors":model.find_children("Anim_Rotor*","Node3D",true,false),"sails":model.find_children("Anim_Sail*","Node3D",true,false),"glows":model.find_children("Anim_Glow*","Node3D",true,false)}
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			if model.get_node_or_null("ArchiveProjection")!=null and model.get_node("ArchiveProjection").is_ancestor_of(mesh):continue
			var body:=StaticBody3D.new();mesh.add_child(body);var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();body.add_child(shape)
		var marker:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.23;torus.outer_radius=.30;torus.rings=16;torus.ring_segments=8;marker.mesh=torus
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("cbb5ff");marker.material_override=material;add_child(marker);markers[row.id]=marker
	for id in models.keys():
		if active.has(id):continue
		models[id].queue_free();markers[id].queue_free();models.erase(id);markers.erase(id);rows.erase(id);previous_stages.erase(id);parts.erase(id)
	_pending_states()
func _pending_states() -> void:
	var world:=context()
	for id in models:
		var row: Dictionary=rows[id];var d:=FrontierExplorationDiscoveries.definition(row.template);var index:=FrontierExplorationDiscoveries.stage(world,row)
		var model: Node3D=models[id]
		var marker: MeshInstance3D=markers[id];marker.position=FrontierExplorationDiscoveries.work_point(row,index)
		marker.visible=index<d.stages.size() and surface.viewer.position.distance_to(marker.position)<24
		if previous_stages.has(id) and previous_stages[id]!=index:
			serial+=1
			if not blocked():
				audio.play("sfx_discovery_excavate" if d.mode in ["dig","water"] else ("sfx_lotus_open" if d.mode in ["repair","salvage","archive"] and index<d.stages.size() else "ui_discovery"),marker.position)
				puff(marker.position)
		previous_stages[id]=index
		if d.mode=="archive":
			for cassette in model.find_children("Anim_Power*","Node3D",true,false):cassette.visible=index>=2
			var projection:=model.get_node_or_null("ArchiveProjection")
			if projection!=null:projection.visible=index>=2
		for cover in model.find_children("Anim_Cover*","Node3D",true,false):
			if not cover.has_meta("rest"):cover.set_meta("rest",cover.position)
			var opened: bool=index>=2
			if d.mode=="archive":opened=index>=1
			if d.mode in ["dig","water"]:
				cover.visible=not opened
				for shape in cover.find_children("*","CollisionShape3D",true,false):shape.set_deferred("disabled",opened)
			elif d.mode=="shade":
				cover.scale.z=9.0 if opened else 1.0;cover.position=cover.get_meta("rest")+Vector3.UP*(1.9 if opened else 0.0)
			else:cover.rotation.x=(-.95 if d.mode=="archive" else -1.6) if opened else 0.0
func blocked() -> bool:
	return app==null or app.feedback==null or app.feedback.blocked() or (not app.test_mode and not get_window().has_focus())
func _process(delta: float) -> void:
	if surface==null or surface.session.latest.is_empty():return
	elapsed+=delta;tick-=delta
	if tick<=0:tick=.35;refresh()
	var stopped:=blocked();hint.visible=not stopped;ambience.stream_paused=stopped
	if stopped:return
	var world:=context();selected={}
	var nearest:=10.0;var near_sound:=35.0;var sound_row: Dictionary={}
	for id in models:
		var row: Dictionary=rows[id];var d:=FrontierExplorationDiscoveries.definition(row.template);var index:=FrontierExplorationDiscoveries.stage(world,row)
		var target:=FrontierExplorationDiscoveries.work_point(row,index);var difference:=target-camera.global_position;var along:=difference.dot(-camera.global_basis.z)
		if along>0 and difference.length()<nearest and (difference+camera.global_basis.z*along).length()<1.15 and FrontierCrewSurface.visible_in_field(surface.terrain.field,camera.global_position,target):nearest=difference.length();selected=row
		var distance_value:=FrontierCrewWorld.vector(row.position).distance_to(surface.viewer.position)
		if distance_value<near_sound:near_sound=distance_value;sound_row=row
		for rotor in parts[id].rotors:
			if index>=2:
				if d.mode=="archive":rotor.rotation.y+=delta*(.25 if fmod(elapsed,2.8)<2.2 else .02)
				else:rotor.rotation.z+=delta*1.4
		for sail in parts[id].sails:sail.rotation.z=sin(elapsed+float(row.yaw))*.08
		for glow in parts[id].glows:
			glow.scale=Vector3.ONE*(1.0 if index>=2 or surface.atmosphere.daylight<.3 else .45)
			if d.mode=="archive":glow.visible=index>=2 and fmod(elapsed,4.7)>.12
		if d.mode=="pulse" and fmod(float(surface.session.latest.crew.navigation.orbit_time)+float(row.yaw)*3,8.0)<3.0 and fmod(elapsed,1.2)<delta:puff(FrontierCrewWorld.vector(row.position)+Vector3.UP*1.7)
	if not sound_row.is_empty():
		var d:=FrontierExplorationDiscoveries.definition(sound_row.template)
		var sound: String=FrontierExplorationDiscoveries.config().sounds[d.sound]
		if current_sound!=sound:current_sound=sound;ambience.stream=audio.stream(sound,true)
		ambience.position=FrontierCrewWorld.vector(sound_row.position)+Vector3.UP
		if not ambience.playing:ambience.play()
	else:ambience.stop()
	hint.size=Vector2(minf(540,get_viewport().get_visible_rect().size.x-40),74);hint.position=Vector2((get_viewport().get_visible_rect().size.x-hint.size.x)*.5,get_viewport().get_visible_rect().size.y*.67)
	if selected.is_empty():hint.text="";return
	var d:=FrontierExplorationDiscoveries.definition(selected.template);var index:=FrontierExplorationDiscoveries.stage(world,selected)
	if index>=d.stages.size():hint.text=d.name+"  조사 완료";return
	var step: Dictionary=d.stages[index]
	var known:=FrontierExplorationDiscoveries.known(world,selected)
	hint.text="%s  %d/%d\n%s  %s"%[d.name,index+1,d.stages.size(),"F" if known else "E 유지",step.label]
	if d.mode=="archive":hint.text+="\n"+str(FrontierFacilityBlueprints.definitions()[FrontierFacilityBlueprints.archive_blueprint(world,selected)].name)
	if not str(step.tool).is_empty():hint.text+="  ["+("지형 변환기" if step.tool=="terrain" else "채집기")+"]"
	for resource in step.cost:hint.text+="  %s %d"%[FrontierCatalog.entry("resources",resource).name,int(step.cost[resource])]
func interact() -> bool:
	if selected.is_empty() or blocked():return false
	var index:=FrontierExplorationDiscoveries.stage(context(),selected)
	surface.session.send_request("surface_discovery",{"id":selected.id,"stage":index,"aim":FrontierExpeditionBusiness.array(-camera.global_basis.z)})
	return true
func _response(_sequence: int,result: Dictionary) -> void:
	# Feedback's shared transaction path handles errors and material gains.
	if result.get("ok",false) and result.has("discovery") and app!=null:
		var id: String=result.discovery.id
		if not rows.has(id):return
		var d:=FrontierExplorationDiscoveries.definition(rows[id].template)
		app.feedback.show_cue(d.knowledge if int(result.discovery.stage)>=d.stages.size() else "다음 조사 지점을 확인하세요.")
func puff(at: Vector3) -> void:
	if get_child_count()>80:return
	var particles:=CPUParticles3D.new();particles.position=at;particles.one_shot=true;particles.amount=12;particles.lifetime=.8;particles.explosiveness=.7;particles.direction=Vector3.UP;particles.spread=50;particles.initial_velocity_min=.4;particles.initial_velocity_max=1.5;particles.gravity=Vector3(0,-.3,0);particles.scale_amount_min=.035;particles.scale_amount_max=.11
	var mesh:=SphereMesh.new();mesh.radial_segments=6;mesh.rings=3;mesh.radius=.5;mesh.height=1;particles.mesh=mesh
	var material:=StandardMaterial3D.new();material.albedo_color=Color("b9a5cd");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;particles.material_override=material;add_child(particles);particles.finished.connect(particles.queue_free);particles.emitting=true
