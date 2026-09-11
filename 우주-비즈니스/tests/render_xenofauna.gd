extends SceneTree
## Only the 300 new assets: INK portraits, LODs, states and structural representatives.
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
var studio: Node3D
var failures: Array[String]=[]
var destination="res://../docs/production/media/xenofauna/"
var catalogue="res://data/bestiary/xenofauna_forms.json"
var collection_title="XENOFAUNA"
func _initialize() -> void:run.call_deferred()
func draw() -> void:
	await process_frame;RenderingServer.force_draw(false)
func verify_actor(_actor: Node3D,_form: Dictionary) -> void:pass
func verify_pose(_actor: Node3D,_form: Dictionary,_state: String) -> void:pass
func import_error(form: Dictionary) -> String:
	for lod in ["near","far"]:
		var source: String="res://"+str(form.lods[lod].path).trim_prefix("우주-비즈니스/")
		if FileAccess.get_sha256(source)!=form.lods[lod].sha256:return "source changed: "+lod
		var descriptor:=ConfigFile.new()
		if descriptor.load(source+".import")!=OK:return "missing import: "+lod
		var imported: String=descriptor.get_value("remap","path","")
		var stamp: String=imported.get_basename()+".md5"
		if imported.is_empty() or not FileAccess.file_exists(stamp):return "missing import stamp: "+lod
		var pattern:=RegEx.new();pattern.compile('source_md5="([^"]+)"')
		var result:=pattern.search(FileAccess.get_file_as_string(stamp))
		if result==null or result.get_string(1)!=FileAccess.get_md5(source):return "stale imported model: "+lod
	return ""
func run() -> void:
	var forms: Array=JSON.parse_string(FileAccess.get_file_as_string(catalogue)).forms
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ids="):
			var selected:=arg.trim_prefix("--ids=").split(",")
			forms=forms.filter(func(form):return form.id in selected)
	var first:=0;var last:=forms.size()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start="):first=int(arg.trim_prefix("--start="))
		if arg.begins_with("--end="):last=int(arg.trim_prefix("--end="))
	for folder in ["game","lod","motion","lighting","faces-game","render-records"]:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination+folder))
	studio=load("res://scripts/showcase/ink_samples.gd").new();root.add_child(studio);studio.helper.hide()
	root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	var style_hash:=FileAccess.get_sha256("res://data/render_style.json")
	var motion_hash:=FileAccess.get_sha256("res://scripts/actors/creatures/bestiary_actor.gd")
	for i in range(first,mini(last,forms.size())):
		var form: Dictionary=forms[i];var file: String=destination+"render-records/"+form.id+".json"
		var motion_representative: bool=int(form.anatomy)==0 or (form.has("replacement") and form.get("organ_system","")=="armor")
		var motion_key: String=form.id if form.has("replacement") else form.family
		var imported_error:=import_error(form)
		if not imported_error.is_empty():
			failures.append(form.id+" "+imported_error);print("RENDER_BLOCKED ",form.id," ",imported_error);continue
		if FileAccess.file_exists(file):
			var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
			if old.model_sha256==form.lods.near.sha256 and old.style_sha256==style_hash and old.get("motion_sha256","")==motion_hash and old.failures.is_empty():continue
		var before:=failures.size()
		studio.cache.clear();studio.samples=[{"id":form.id,"title":collection_title+" / "+form.family_name,"name":form.name+" · "+form.environment_label,"foliage":form.category=="plant","model":"res://"+str(form.lods.near.path).trim_prefix("우주-비즈니스/")}]
		# Keep full INK reference resolution for the four anatomy review samples.
		# Other catalogue portraits are delivered at 480×400; a 720×600 render
		# preserves their source detail without producing 7,000 poster captures.
		var reference: bool=collection_title!="BIOTA" or int(form.anatomy) in [0,8,24,49]
		root.content_scale_size=Vector2i(1440,1200) if reference else Vector2i(720,600)
		studio.select_sample(0)
		var original: Node3D=studio.subject;studio.stage.remove_child(original);original.free()
		var actor:=Actor.new();studio.stage.add_child(actor);studio.subject=actor;actor.configure(form);actor.paused=true;actor.set_process(false)
		if form.get("review_front","")=="+Y":actor.rotation.y=PI
		verify_actor(actor,form)
		if actor.joints[0].keys()!=actor.joints[1].keys():failures.append(form.id+" LOD pivot mismatch")
		actor.set_lod(false);actor.set_state("idle");actor.elapsed=.4;actor.pose()
		studio.title.get_parent().show();await draw()
		root.get_texture().get_image().save_png(destination+"game/"+form.id+".png")
		studio.title.get_parent().hide();studio.studio_ground.hide();root.transparent_bg=true
		var environment: Environment=studio.find_children("*","WorldEnvironment",true,false)[0].environment
		var background:=environment.background_color;environment.background_color=Color(0,0,0,0)
		studio.contour.set_shader_parameter("transparent_background",true);await draw()
		var portrait:=root.get_texture().get_image();portrait.resize(480,400,Image.INTERPOLATE_LANCZOS)
		portrait.save_png("res://assets/ui/previews/"+form.id+".png")
		root.transparent_bg=false;environment.background_color=background;studio.studio_ground.show();studio.contour.set_shader_parameter("transparent_background",false)
		root.content_scale_size=Vector2i(720,600)
		for state in ["idle","move","feed","dormant","stressed"]:
			actor.set_state(state);actor.elapsed=.74;actor.pose()
			verify_pose(actor,form,state)
			for key in actor.joints[0]:
				if not actor.joints[0][key].node.transform.is_equal_approx(actor.joints[1][key].node.transform):failures.append(form.id+" "+state+" "+key)
			if motion_representative:
				await draw();root.get_texture().get_image().save_png(destination+"motion/"+motion_key+"-"+state+".png")
		actor.set_state("idle");actor.elapsed=.4;actor.pose();actor.set_lod(true);await draw()
		root.get_texture().get_image().save_png(destination+"lod/"+form.id+".png");actor.set_lod(false)
		if motion_representative:
			var light: DirectionalLight3D=studio.find_children("*","DirectionalLight3D",true,false)[0]
			for mode in ["shade","backlight"]:
				light.light_energy=.35 if mode=="shade" else 1.35;light.rotation_degrees=Vector3(-48,-32,0) if mode=="shade" else Vector3(-20,150,0)
				await draw();root.get_texture().get_image().save_png(destination+"lighting/"+motion_key+"-"+mode+".png")
			light.light_energy=1.35;light.rotation_degrees=Vector3(-48,-32,0)
		if form.has("replacement") and actor.joints[0].has("Anim_Head"):
			var view_transform: Transform3D=studio.camera.transform;var view_size: float=studio.camera.size
			var target: Vector3=actor.joints[0].Anim_Head.node.global_position+Vector3(0,0,.07)
			studio.camera.position=target+Vector3(.95,.38,1.5)*3;studio.camera.look_at(target)
			studio.camera.size={"proboscid":1.65,"rhinocerid":1.4,"owl":1.15,"crab":1.2,"hermit":1.2}.get(form.get("anatomical_type",""),1.05)
			root.content_scale_size=Vector2i(900,750);await draw();root.get_texture().get_image().save_png(destination+"faces-game/"+form.id+".png")
			studio.camera.transform=view_transform;studio.camera.size=view_size
		FileAccess.open(file,FileAccess.WRITE).store_string(JSON.stringify({"id":form.id,"model_sha256":form.lods.near.sha256,"imported_model_sha256":{"near":form.lods.near.sha256,"far":form.lods.far.sha256},"style_sha256":style_hash,"motion_sha256":motion_hash,"states":5,"lods":2,"representative":motion_representative,"motion_key":motion_key,"failures":failures.slice(before)},"  "))
		print(collection_title,"_RENDERED ",i+1,"/",forms.size()," ",form.id)
	print("XENO_RENDER_COMPLETE failures=",failures.size());quit(0 if failures.is_empty() else 1)
