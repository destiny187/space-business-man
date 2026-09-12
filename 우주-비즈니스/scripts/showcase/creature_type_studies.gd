extends SceneTree
## Isolated Blender-clip review. Never loads or changes a campaign/save/catalog.
const Ink = preload("res://scripts/actors/ink_style.gd")
var folder := ""
var stage: Node3D
var actor: Node3D
var camera: Camera3D
var player: AnimationPlayer
var socket: Node3D
var effects: Node3D
var current: Dictionary
var clips: Dictionary = {}
var report: Array = []
var origin := Vector3.ZERO
var target := Vector3.ZERO
var cue := -1.0

func _initialize() -> void:
	call_deferred("run")

func descendants(node: Node, type: String) -> Array:
	var found: Array = []
	if node.is_class(type): found.append(node)
	for child in node.get_children(): found.append_array(descendants(child,type))
	return found

func make_stage() -> void:
	stage = Node3D.new(); root.add_child(stage)
	var world := WorldEnvironment.new(); var env := Environment.new(); world.environment=env
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("cad4cf")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("b6c7cc"); env.ambient_light_energy=.48
	stage.add_child(world)
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-48,-35,0); light.shadow_enabled=true; light.light_energy=1.05
	light.directional_shadow_max_distance=24; light.shadow_bias=.025; light.shadow_normal_bias=.30; stage.add_child(light)
	var ground:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(200,200); ground.mesh=plane; ground.position.y=-.015
	var mat:=StandardMaterial3D.new(); mat.albedo_color=Color("c0c6b8"); ground.material_override=Ink.material(mat,{}); stage.add_child(ground)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.current=true; stage.add_child(camera)
	effects=Node3D.new(); stage.add_child(effects); Ink.attach(stage,true)

func load_study(form: Dictionary) -> void:
	if is_instance_valid(actor): actor.queue_free(); await process_frame
	current=form; clips.clear(); cue=-1
	# Runtime GLTF load uses the exact exported bytes, without importing the whole project.
	var doc:=GLTFDocument.new(); var state:=GLTFState.new()
	var path: String="res://"+str(form.lods.near.path).trim_prefix("우주-비즈니스/")
	var err:=doc.append_from_file(path,state)
	assert(err==OK,"Study GLB could not be read: "+path)
	actor=doc.generate_scene(state); stage.add_child(actor); Ink.apply(actor,{})
	if form.kind!="glider": actor.position.y=-float(form.lods.near.min[1])
	var players:=descendants(actor,"AnimationPlayer"); assert(not players.is_empty(),"No exported clips")
	player=players[0]; player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key in form.clips:
		for animation in player.get_animation_list():
			if str(animation).contains(str(key)): clips[key]=animation
	assert(clips.size()==4,"Missing study clips: "+str(clips))
	socket=actor.find_child("Socket_Muzzle",true,false)
	assert(socket!=null,"Animated muzzle is missing")
	var skin: Skeleton3D=descendants(actor,"Skeleton3D")[0]
	report.append({"id":form.id,"clips":clips.duplicate(),"bones":skin.get_bone_count(),"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name()})
	frame_camera(false)

func frame_camera(wide: bool, detail: bool=false) -> void:
	var a: Array=current.lods.near.min; var b: Array=current.lods.near.max
	var lo:=Vector3(a[0],a[1],a[2]); var hi:=Vector3(b[0],b[1],b[2]); var center: Vector3=(lo+hi)*.5
	var span: float=maxf((hi-lo).x,(hi-lo).z)
	camera.size=maxf((hi-lo).y*1.38,span*1.04)
	if current.kind in ["glider","serpent","hexapod"]: camera.size*=.86
	if wide: camera.size*=1.20; center.z+=.70
	if wide and current.kind=="hopper": camera.size*=1.18; center.y+=.24
	if detail:
		var m: Array=current.muzzle; center=Vector3(m[0],m[1],m[2]-.20)
		camera.size=1.9 if current.kind!="tripod" else 2.3
	camera.position=center+(Vector3(3.5,4.6,5.0) if current.kind=="glider" else Vector3(4,2.55,5.4))*2; camera.look_at(center)

func pose(state: String, time: float) -> void:
	var clip: String=clips[state]
	if player.current_animation!=clip: player.play(clip)
	player.seek(minf(time,player.get_animation(clip).length),true); player.advance(0)
	# BoneAttachment3D follows the skeleton on the render update.

func blob(at: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new(); var shape:=SphereMesh.new(); shape.height=2; shape.radius=1; shape.radial_segments=16; shape.rings=8; mesh.mesh=shape
	var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=.52; mesh.material_override=Ink.material(mat,{})
	effects.add_child(mesh); mesh.position=at; mesh.scale=size
	return mesh

func attack_effects(t: float) -> void:
	for child in effects.get_children(): child.free()
	var release:=.88
	if t<release: cue=-1; return
	if cue<0:
		origin=socket.global_position; target=Vector3(origin.x,.09,origin.z+2.4); cue=t
	var elapsed:=t-release
	if current.attack in ["mortar","spit","dart"]:
		var duration:=.70 if current.attack=="mortar" else (.36 if current.attack=="spit" else .22)
		for i in range(1 if current.attack=="mortar" else 3):
			var u: float=(elapsed-i*.065)/duration
			if u<0 or u>1: continue
			var destination:=target+Vector3((i-1)*.20,0,0)
			var at:=origin.lerp(destination,u)
			if current.attack=="mortar": at.y+=sin(u*PI)*1.15
			elif current.attack=="spit": at.y+=sin(u*PI)*.14
			var radius:=.11 if current.attack=="mortar" else .065
			var projectile:=blob(at,Vector3(radius,radius,.19 if current.attack=="dart" else radius),Color("b5bd76") if current.attack=="spit" else Color("b98c57"))
			if current.attack=="dart": projectile.look_at(at+(destination-origin).normalized())
		var impact:=elapsed-duration
		if impact>0 and impact<.55:
			for i in range(7):
				var a: float=TAU*i/7; var r: float=impact*1.0+.04
				blob(target+Vector3(cos(a)*r,sin(impact/.55*PI)*.25,sin(a)*r),Vector3.ONE*(.09*(1-impact/.6)),Color("a9ac70") if current.attack=="spit" else Color("9f977f"))
	elif t>1.1 and t<1.6:
		var at:=Vector3(0,.08,2.0); var r: float=(t-1.1)*1.7
		for i in range(9):
			var a: float=TAU*i/9
			blob(at+Vector3(cos(a)*r,sin((t-1.1)*TAU)*.12,sin(a)*r),Vector3.ONE*.07,Color("a9a18c"))

func capture(path: String, small: bool=false) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image()
	if small: img.resize(640,500,Image.INTERPOLATE_LANCZOS)
	img.save_png(path)

func run() -> void:
	folder=ProjectSettings.globalize_path("res://../output/creature-studies/godot")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,1000); root.content_scale_size=root.size
	root.msaa_3d=Viewport.MSAA_4X; root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	make_stage()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_studies.json"))
	var wanted:=OS.get_cmdline_user_args()
	for form in data.forms:
		if not wanted.is_empty() and not str(form.id) in wanted: continue
		await load_study(form); pose("idle_loop",.35)
		for warmup in 4: await process_frame
		await capture(folder+"/"+form.id+"-hero.png")
		frame_camera(false,true); await capture(folder+"/"+form.id+"-detail.png"); frame_camera(true)
		var frames: String=folder+"/"+form.id; DirAccess.make_dir_recursive_absolute(frames)
		# 9.6s at 12.5fps: breathing -> travel -> feeding -> telegraph/release/recovery.
		for frame in range(120):
			var time: float=frame*.08
			var state: String="idle_loop" if time<1.6 else ("move_loop" if time<4.8 else ("feed" if time<7.2 else "attack"))
			var cliptime: float=fmod(time,2.) if state=="idle_loop" else (fmod(time-1.6,2.) if state=="move_loop" else (time-4.8 if state=="feed" else time-7.2))
			pose(state,cliptime)
			await process_frame
			if state=="attack": attack_effects(cliptime)
			await capture(frames+"/%03d.png"%frame,true)
		print("STUDY_RENDERED ",form.id," ",clips)
	var combined: Dictionary={}
	if not wanted.is_empty() and FileAccess.file_exists(folder+"/evidence.json"):
		for previous in JSON.parse_string(FileAccess.get_file_as_string(folder+"/evidence.json")): combined[previous.id]=previous
	for item in report: combined[item.id]=item
	var file:=FileAccess.open(folder+"/evidence.json",FileAccess.WRITE); file.store_string(JSON.stringify(combined.values(),"\t")); file.close()
	quit()
