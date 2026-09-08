extends SceneTree
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
var studio:Node3D
var failures:Array[String]=[]
var root_dir:="res://../docs/production/media/ink-life/"
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	if not ok:failures.append(label);push_error(label)
func draw() -> void:
	await process_frame;RenderingServer.force_draw(false)
func run() -> void:
	var forms:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/forms.json")).forms
	var first:=0;var last:=forms.size();var representatives:="--representatives" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start="):first=int(arg.trim_prefix("--start="))
		if arg.begins_with("--end="):last=int(arg.trim_prefix("--end="))
	for directory in ["game","lod","motion","lighting","render-records"]:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_dir+directory))
	var style_hash:=FileAccess.get_sha256("res://data/render_style.json")
	studio=load("res://scripts/showcase/ink_samples.gd").new();root.add_child(studio);studio.helper.hide()
	root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	var families:Dictionary={};var count:=0
	for i in range(first,mini(last,forms.size())):
		var form:Dictionary=forms[i]
		if representatives and families.has(form.family):continue
		var representative:bool=not families.has(form.family);families[form.family]=true
		var record_path:String=root_dir+"render-records/"+form.id+".json"
		if FileAccess.file_exists(record_path):
			var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(record_path))
			if old.model_sha256==form.lods.near.sha256 and old.style_sha256==style_hash and old.failures.is_empty():continue
		var before_failures:=failures.size()
		studio.cache.clear();studio.samples=[{"id":form.id,"title":"LIFE ATLAS / "+form.family_name,"name":form.name+" · "+form.environment_label,"model":"res://"+str(form.lods.near.path).trim_prefix("우주-비즈니스/"),"foliage":form.category!="animal"}]
		root.content_scale_size=Vector2i(1440,1200);studio.select_sample(0)
		var original:Node3D=studio.subject;studio.stage.remove_child(original);original.free()
		var actor:=Actor.new();studio.stage.add_child(actor);studio.subject=actor;actor.configure(form);actor.paused=true
		check(actor.models.size()==2,form.id+" both LODs")
		check(actor.joints[0].keys()==actor.joints[1].keys(),form.id+" LOD joints")
		actor.set_lod(false);actor.set_process(false);actor.set_state("idle");actor.elapsed=.4;actor.pose()
		studio.title.get_parent().show();await draw()
		var picture:=root.get_texture().get_image()
		check(picture.save_png(root_dir+"game/"+form.id+".png")==OK,form.id+" native capture")
		picture.save_png("res://../docs/production/media/bestiary/models/"+form.id+".png")
		picture.save_png("res://../docs/production/media/ink-catalog/"+form.id+".png")
		studio.title.get_parent().hide();await draw()
		var preview:=root.get_texture().get_image();preview.resize(480,400,Image.INTERPOLATE_LANCZOS)
		preview.save_png("res://assets/ui/previews/"+form.id+".png")
		root.content_scale_size=Vector2i(720,600)
		for state in ["idle","move","feed","dormant","stressed"]:
			check(actor.set_state(state),form.id+" "+state)
			actor.elapsed=.72;actor.pose()
			for key in actor.joints[0]:check(actor.joints[0][key].node.transform.is_equal_approx(actor.joints[1][key].node.transform),form.id+" joint "+key)
			if representative:
				await draw();root.get_texture().get_image().save_png(root_dir+"motion/"+form.family+"-"+state+".png")
		if form.attack!="none":
			check(actor.set_state("attack"),form.id+" attack")
			for moment in [.2,.67,1.05,1.75]:
				actor.elapsed=moment;actor.pose()
				if representative:
					await draw();root.get_texture().get_image().save_png(root_dir+"motion/"+form.family+"-attack-"+str(moment)+".png")
			check(actor.state=="idle",form.id+" attack recovery")
		actor.set_state("idle");actor.set_lod(true);await draw()
		root.get_texture().get_image().save_png(root_dir+"lod/"+form.id+".png")
		actor.set_lod(false)
		if representative:
			var key:DirectionalLight3D=studio.find_children("*","DirectionalLight3D",true,false)[0]
			for mode in ["shade","backlight"]:
				key.light_energy=.35 if mode=="shade" else 1.35;key.rotation_degrees=Vector3(-48,-32,0) if mode=="shade" else Vector3(-20,150,0)
				await draw();root.get_texture().get_image().save_png(root_dir+"lighting/"+form.family+"-"+mode+".png")
			key.light_energy=1.35;key.rotation_degrees=Vector3(-48,-32,0)
		var result:Dictionary={"id":form.id,"family":form.family,"model_sha256":form.lods.near.sha256,"style_sha256":style_hash,"motion_states":5,"attack":form.attack,"lods":2,"representative":representative,"failures":failures.slice(before_failures)}
		FileAccess.open(record_path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
		count+=1;print("INK_LIFE_RENDERED ",i+1,"/",forms.size()," ",form.id)
	print("INK_LIFE_RENDER_COMPLETE count=",count," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
