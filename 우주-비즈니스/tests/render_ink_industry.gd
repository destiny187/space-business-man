extends "res://scripts/showcase/ink_samples.gd"
## Focused art deliverable: priority replacement geometry in the production renderer.
func _ready() -> void:
	samples=[]
	var names := {"miner":"자율 채광 로봇", "atmosphere":"대기 조절기", "thermal":"온도 조절기", "water":"물 추출기", "biolab":"생태 연구소"}
	for id in names:
		samples.append({"id":id,"title":"INK v1 / "+names[id],"name":"LOCUS · 공통 산업 제작 규격","model":"res://assets/models/"+id+".glb"})
	super._ready()
	get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	capture_industry.call_deferred()

func capture_industry() -> void:
	helper.hide()
	var dest := "res://../docs/production/media/ink-industry/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest))
	var before := "--before" in OS.get_cmdline_user_args()
	var suffix := "before" if before else "after"
	var board := Image.create(2160,1200,false,Image.FORMAT_RGBA8)
	board.fill(Color("e5e2d6"))
	for i in samples.size():
		select_sample(i)
		await get_tree().create_timer(.4).timeout
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		assert(shot.save_png(dest+samples[i].id+"-"+suffix+".png")==OK)
		if not before:assert(shot.save_png("res://../docs/production/media/ink-catalog/"+samples[i].id+".png")==OK)
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(720,600,Image.INTERPOLATE_LANCZOS)
		board.blit_rect(shot,Rect2i(0,0,720,600),Vector2i((i%3)*720,(i/3)*600))
		if not before:
			title.get_parent().hide()
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			var preview := get_viewport().get_texture().get_image()
			preview.resize(480,400,Image.INTERPOLATE_LANCZOS)
			assert(preview.save_png("res://assets/ui/previews/"+samples[i].id+".png")==OK)
			title.get_parent().show()
	assert(board.save_png(dest+"industry-"+suffix+".png")==OK)
	if not before:await capture_mixed(dest)
	print("INK_INDUSTRY_CAPTURE_COMPLETE ",suffix," ",RenderingServer.get_video_adapter_name())
	get_tree().quit()

func capture_mixed(dest: String) -> void:
	stage.remove_child(subject);subject.queue_free()
	studio_ground.position.y=-.025
	(studio_ground.mesh as PlaneMesh).size=Vector2(2000,2000)
	var roster := [
		["miner",Vector3(-1.8,0,2.5),0.0],
		["atmosphere",Vector3(-5,0,-3),0.0],
		["thermal",Vector3(-.7,0,-4.5),0.0],
		["water",Vector3(3.6,0,-4),0.0],
		["biolab",Vector3(6,0,.3),0.0],
		["vehicles/scout_rover",Vector3(-6.3,0,3.7),PI],
		["storage",Vector3(2.8,0,4.8),0.0],
		["ink-study/mineral_deposit",Vector3(-1,0,7),0.0],
		["ink-study/frontier_grass",Vector3(6.4,0,5.4),0.0]
	]
	for entry in roster:
		var model: Node3D=load("res://assets/models/"+entry[0]+".glb").instantiate()
		stage.add_child(model);model.position=entry[1];model.rotation.y=entry[2]
		FrontierInkStyle.apply(model,cache)
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=48
	camera.position=Vector3(17,17,23);camera.look_at(Vector3(0,1,1));camera.far=200
	var light: DirectionalLight3D
	for child in get_children():
		if child is DirectionalLight3D:light=child;break
	for setting in ["day","shade","backlight"]:
		light.rotation_degrees=Vector3(-48,-32,0) if setting!="backlight" else Vector3(-18,150,0)
		light.light_energy=.25 if setting=="shade" else 1.35
		title.text="INK v1 / "+setting
		subtitle.text="채광 로봇 · 환경 시설 · SCOUT · 창고 · 광물 · 풀"
		await get_tree().create_timer(.4).timeout;await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(dest+"mixed-"+setting+".png")==OK)
