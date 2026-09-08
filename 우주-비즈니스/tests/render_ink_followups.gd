extends "res://scripts/showcase/ink_catalog.gd"
## Render only the explicitly tracked legacy replacement batch.
const FOLLOWUPS := ["base","factory","charger","solar","reactor","surveyor","guardian","manual_tool","ruin","microbe","animal","civilization","tree","mesa_0","mesa_1","mesa_2"]
func _ready() -> void:
	super._ready()
	samples=samples.filter(func(row: Dictionary):return row.id in FOLLOWUPS)
	helper.hide()
	get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	capture_followups.call_deferred()

func capture_followups() -> void:
	var before := "--before" in OS.get_cmdline_user_args()
	var suffix := "before" if before else "after"
	var dest := "res://../docs/production/media/ink-followups/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest))
	var boards: Dictionary={}
	var counts: Dictionary={}
	for group in ["장비","시설","발견·환경"]:
		var amount:=samples.filter(func(row: Dictionary):return row.group==group).size()
		boards[group]=Image.create(1440,int(ceil(amount/2.0))*600,false,Image.FORMAT_RGBA8)
		boards[group].fill(Color("e5e2d6"));counts[group]=0
	var filenames := {"장비":"equipment","시설":"facilities","발견·환경":"environment"}
	for i in samples.size():
		select_sample(i)
		await get_tree().create_timer(.35).timeout;await RenderingServer.frame_post_draw
		var shot:=get_viewport().get_texture().get_image()
		assert(shot.save_png(dest+samples[i].id+"-"+suffix+".png")==OK)
		if not before:assert(shot.save_png("res://../docs/production/media/ink-catalog/"+samples[i].id+".png")==OK)
		shot.convert(Image.FORMAT_RGBA8);shot.resize(720,600,Image.INTERPOLATE_LANCZOS)
		var group: String=samples[i].group
		var n: int=counts[group]
		boards[group].blit_rect(shot,Rect2i(0,0,720,600),Vector2i((n%2)*720,(n/2)*600))
		counts[group]+=1
		if not before:
			canvas.hide();await get_tree().process_frame;await RenderingServer.frame_post_draw
			var preview:=get_viewport().get_texture().get_image()
			preview.resize(480,400,Image.INTERPOLATE_LANCZOS)
			assert(preview.save_png("res://assets/ui/previews/"+samples[i].id+".png")==OK)
			canvas.show()
		print("FOLLOWUP_RENDER ",samples[i].id," ",suffix)
	for group in boards:assert(boards[group].save_png(dest+filenames[group]+"-"+suffix+".png")==OK)
	if not before:await capture_mixed(dest)
	print("INK_FOLLOWUPS_CAPTURE_COMPLETE ",suffix)
	get_tree().quit()

func capture_mixed(dest: String,style_override: Dictionary={}) -> void:
	stage.remove_child(subject);subject.queue_free()
	studio_ground.position.y=-.025
	(studio_ground.mesh as PlaneMesh).size=Vector2(2000,2000)
	var roster := [
		["factory",Vector3(-5,0,-4),0.0],
		["base",Vector3(.5,0,-6),0.0],
		["reactor",Vector3(7,0,-4),0.0],
		["solar",Vector3(-8.8,0,.8),0.0],
		["charger",Vector3(2.5,0,2),0.0],
		["guardian",Vector3(-2,0,3),0.0],
		["surveyor",Vector3(6,0,3),0.0],
		["vehicles/scout_rover",Vector3(-6,0,7),PI],
		["ruin",Vector3(12,0,-9),0.0],
		["civilization",Vector3(-12,0,-10),0.0],
		["animal",Vector3(5,0,8),0.0],
		["microbe",Vector3(9,0,6),0.0],
		["tree",Vector3(9,0,0),0.0],
		["tree",Vector3(-11,0,-4),1.5],
		["mesa_0",Vector3(-40,0,-110),0.0],
		["mesa_1",Vector3(0,0,-125),0.0],
		["mesa_2",Vector3(35,0,-115),0.0]]
	for entry in roster:
		var model: Node3D=load("res://assets/models/"+entry[0]+".glb").instantiate()
		stage.add_child(model);model.position=entry[1];model.rotation.y=entry[2]
		FrontierInkStyle.apply(model,cache)
		if entry[0].begins_with("mesa_"):
			var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/strata.gdshader");mat.set_shader_parameter("rough",.96)
			for mi in model.find_children("*","MeshInstance3D",true,false):mi.material_override=mat
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=48
	camera.position=Vector3(19,15,28);camera.look_at(Vector3(0,1,-1));camera.far=300
	var style:Dictionary=FrontierInkStyle.config() if style_override.is_empty() else style_override
	contour.set_shader_parameter("outline_fade",Vector2(style.outline_fade[0],style.outline_fade[1]))
	contour.set_shader_parameter("crease_fade",Vector2(style.crease_fade[0],style.crease_fade[1]))
	var light: DirectionalLight3D
	for child in get_children():
		if child is DirectionalLight3D:light=child;break
	for setting in ["day","shade","backlight"]:
		light.rotation_degrees=Vector3(-48,-32,0) if setting!="backlight" else Vector3(-18,150,0)
		light.light_energy=.25 if setting=="shade" else 1.35
		title.text="INK v1 / "+setting
		subtitle.text="시설 · 탐광/경비 로봇 · SCOUT · 유적 · 생물 · 식생 · 암벽"
		await get_tree().create_timer(.4).timeout;await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(dest+"mixed-"+setting+".png")==OK)
