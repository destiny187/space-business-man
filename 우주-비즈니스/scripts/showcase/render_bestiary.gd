extends SceneTree
const Ink=preload("res://scripts/actors/ink_style.gd")
var forms: Array=[]
var appearances: Array=[]
var studio: Node3D
var destination: String
var start_index:=0
var end_index:=2147483647
var quick:=false
var eyes_only:=false
var stage_filter:="all"

func _initialize() -> void:call_deferred("run")

func run() -> void:
	forms=FrontierEcologyCatalog.all_forms()
	appearances=FrontierEcologyCatalog.all_appearances()
	destination=ProjectSettings.globalize_path("res://../docs/production/media/bestiary/")
	for folder in ["models","variants","lighting","lod","records","boards"]:DirAccess.make_dir_recursive_absolute(destination+folder)
	for arg in OS.get_cmdline_user_args():
		if arg=="--representatives":quick=true
		if arg=="--eye-revisions":eyes_only=true
		if arg.begins_with("--start="):start_index=int(arg.trim_prefix("--start="))
		if arg.begins_with("--end="):end_index=int(arg.trim_prefix("--end="))
		if arg.begins_with("--stage="):stage_filter=arg.trim_prefix("--stage=")
	var indices: Array[int]=[]
	var seen_families: Dictionary={}
	for i in range(start_index,mini(end_index,forms.size())):
		if eyes_only and not forms[i].has("eye_design"):continue
		if not quick or not seen_families.has(forms[i].family):indices.append(i)
		seen_families[forms[i].family]=true
	if indices.is_empty():
		push_error("No bestiary models selected")
		quit(1)
		return
	# An edited export invalidates its own previous captures, not the whole library.
	for i in indices:
		var form: Dictionary=forms[i]
		var record_path: String=destination+"records/"+form.id+".json"
		if not FileAccess.file_exists(record_path):continue
		var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(record_path))
		if old.get("model_sha256","")==form.lods.near.sha256:continue
		DirAccess.remove_absolute(record_path)
		DirAccess.remove_absolute(destination+"lod/"+form.id+".png")
		for k in range(20):DirAccess.remove_absolute(destination+"variants/"+appearances[i*20+k].id+".png")
	studio=load("res://scripts/showcase/ink_samples.gd").new()
	studio.samples=[sample(forms[indices[0]])]
	root.add_child(studio)
	root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	studio.helper.hide()
	var font:=FontVariation.new()
	font.base_font=load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype={2003265652:600}
	studio.title.add_theme_font_override("font",font)
	studio.subtitle.add_theme_font_override("font",font)
	var source_mat: StandardMaterial3D=studio.studio_ground.material_override
	studio.studio_ground.material_override=Ink.material(source_mat,{})
	studio.camera.far=160
	if stage_filter in ["all","models"]:
		root.content_scale_size=Vector2i(1440,1200)
		for i in indices:
			var form: Dictionary=forms[i]
			if FileAccess.file_exists(destination+"records/"+form.id+".json"):continue
			select(form)
			studio.title.get_parent().show()
			await draw()
			var image:=root.get_texture().get_image()
			assert(image.save_png(destination+"models/"+form.id+".png")==OK)
			studio.title.get_parent().hide()
			await draw()
			var portrait:=root.get_texture().get_image()
			portrait.resize(480,400,Image.INTERPOLATE_LANCZOS)
			assert(portrait.save_png(ProjectSettings.globalize_path("res://assets/ui/previews/"+form.id+".png"))==OK)
			var report: Dictionary={"id":form.id,"native":[1440,1200],"portrait":[480,400],"model_sha256":form.lods.near.sha256,"engine":Engine.get_version_info().string,"status":"rendered-unreviewed"}
			if form.has("eye_design"):
				var head: Node3D=studio.subject.find_child("Anim_Head",true,false)
				var point: Vector2=studio.camera.unproject_position(head.global_position)
				report["head_pixel"]=[point.x,point.y]
			FileAccess.open(destination+"records/"+form.id+".json",FileAccess.WRITE).store_string(JSON.stringify(report))
			print("BESTIARY_NATIVE ",i+1,"/",forms.size()," ",form.id)
			await process_frame
	if stage_filter in ["all","lighting"]:
		root.content_scale_size=Vector2i(480,400)
		studio.title.get_parent().hide()
		var key: DirectionalLight3D=studio.find_children("*","DirectionalLight3D",true,false)[0]
		for i in indices:
			var form: Dictionary=forms[i]
			if FileAccess.file_exists(destination+"lod/"+form.id+".png"):continue
			select(form)
			for mode in ["shade","backlight"]:
				key.rotation_degrees=Vector3(-65,-110,0) if mode=="shade" else Vector3(-25,145,0)
				key.light_energy=.42 if mode=="shade" else 1.1
				await draw()
				assert(root.get_texture().get_image().save_png(destination+"lighting/"+form.id+"-"+mode+".png")==OK)
			key.rotation_degrees=Vector3(-48,-32,0)
			key.light_energy=1.35
			var far_form: Dictionary=form.duplicate(true)
			far_form.lods.near=far_form.lods.far
			if far_form.has("geometry"):far_form.geometry.near=far_form.geometry.far
			select(far_form)
			await draw()
			assert(root.get_texture().get_image().save_png(destination+"lod/"+form.id+".png")==OK)
			print("BESTIARY_LIGHT_LOD ",i+1,"/",forms.size())
	if stage_filter in ["all","variants"]:
		root.content_scale_size=Vector2i(240,200)
		studio.title.get_parent().hide()
		for i in indices:
			var form: Dictionary=forms[i]
			select(form)
			var slots: Dictionary={}
			for mi in studio.subject.find_children("*","MeshInstance3D",true,false):
				for surface in range(mi.mesh.get_surface_count()):
					var mat: ShaderMaterial=mi.get_active_material(surface)
					var slot: String=mat.resource_name.trim_prefix("Bio_")
					if not slots.has(slot):slots[slot]=[]
					if not slots[slot].has(mat):slots[slot].append(mat)
			for k in range(20):
				var look: Dictionary=appearances[i*20+k]
				var path: String=destination+"variants/"+look.id+".png"
				if FileAccess.file_exists(path):continue
				for c in range(3):
					for mat in slots.get(["main","secondary","accent"][c],[]):mat.set_shader_parameter("base_color",Color(look.palette[c]).linear_to_srgb())
				studio.subject.scale=Vector3.ONE*float(look.scale)
				studio.subject.position.y=-float(form.get("geometry",{}).get("near",{}).get("floor_y",0))*float(look.scale)
				await draw()
				assert(root.get_texture().get_image().save_png(path)==OK)
			print("BESTIARY_VARIANTS ",(i+1)*20,"/",appearances.size())
			await process_frame
	print("BESTIARY_RENDER_COMPLETE stage=",stage_filter," forms=",indices.size())
	quit()

func sample(form: Dictionary) -> Dictionary:
	return {"id":form.id,"title":"LIFE ATLAS / "+str(form.family_name),"name":str(form.name)+" · "+str(form.environment_label),"model":"res://"+str(form.lods.near.path).trim_prefix("우주-비즈니스/"),"foliage":form.category!="animal"}

func select(form: Dictionary) -> void:
	studio.cache.clear()
	studio.samples=[sample(form)]
	studio.select_sample(0)
	studio.subject.position.y=-float(form.get("geometry",{}).get("near",{}).get("floor_y",0))
	studio.studio_ground.position.y=-.025
	# Keep a long enough orthographic camera distance to avoid a near-plane floor cut.
	var direction: Vector3=(studio.camera.position-studio.target).normalized()
	studio.camera.position=studio.target+direction*maxf(32,studio.camera.size*4)
	studio.camera.far=maxf(160,studio.camera.size*10)
	studio.camera.look_at(studio.target)

func draw() -> void:
	await process_frame
	# Explicit capture also works while another game's QA window occludes this one.
	RenderingServer.force_draw(false)
