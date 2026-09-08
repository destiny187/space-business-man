extends "res://scripts/showcase/ink_samples.gd"
## Focused, reproducible mixed-family art review using the production Forward+ pipeline.
func _ready() -> void:
	samples = [
		{"id":"scout_rover","title":"SCOUT / 2-seat rover","name":"Blender + production INK v1","model":"res://assets/models/vehicles/scout_rover.glb","view_direction":[1.22,.84,-1.70]},
		{"id":"storage","title":"LOCUS / storage","name":"Current game asset","model":"res://assets/models/storage.glb"},
		{"id":"miner","title":"MINER / current robot","name":"Legacy geometry: rebuild pending","model":"res://assets/models/miner.glb"},
		{"id":"ore_refinery","title":"LOCUS / approved refinery","name":"Approved shape reference","model":"res://assets/models/ink-study/ore_refinery.glb"}
	]
	super._ready()
	get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	capture_family.call_deferred()

func select_sample(which: int) -> void:
	var view: Array = samples[which].get("view_direction",[1.22,.84,1.70])
	direction = Vector3(view[0],view[1],view[2]).normalized()
	super.select_sample(which)

func capture_family() -> void:
	helper.hide()
	var dest := ProjectSettings.globalize_path("res://../docs/production/media/ink-family/")
	var suffix := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var board := Image.create(1440,1200,false,Image.FORMAT_RGBA8)
	for i in samples.size():
		select_sample(i)
		await get_tree().create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		if suffix=="after" and samples[i].id in ["storage","scout_rover"]:
			assert(shot.save_png("res://../docs/production/media/ink-catalog/"+samples[i].id+".png")==OK)
		shot.resize(720,600,Image.INTERPOLATE_LANCZOS)
		board.blit_rect(shot,Rect2i(0,0,720,600),Vector2i((i%2)*720,(i/2)*600))
		if suffix=="after" and samples[i].id=="storage":
			title.get_parent().hide()
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			var preview := get_viewport().get_texture().get_image()
			preview.resize(480,400,Image.INTERPOLATE_LANCZOS)
			assert(preview.save_png("res://assets/ui/previews/storage.png")==OK)
			title.get_parent().show()
	assert(board.save_png(dest+"family-"+suffix+".png")==OK)
	if suffix=="before": get_tree().quit(); return
	stage.remove_child(subject);subject.queue_free()
	studio_ground.position.y=-.025
	(studio_ground.mesh as PlaneMesh).size=Vector2(2000,2000)
	var roster := [
		["vehicles/scout_rover",Vector3(-2.5,0,0),PI],
		["storage",Vector3(2.2,0,-.5),0.0],
		["atmosphere",Vector3(2.7,0,-5.0),0.0],
		["miner",Vector3(-3.0,0,-4.0),0.0],
		["ink-study/mineral_deposit",Vector3(-6.0,0,-2.0),0.0],
		["ink-study/frontier_grass",Vector3(5.3,0,1.0),0.0]
	]
	for entry in roster:
		var model: Node3D = load("res://assets/models/"+entry[0]+".glb").instantiate()
		stage.add_child(model);model.position=entry[1];model.rotation.y=entry[2];FrontierInkStyle.apply(model,cache)
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=50
	camera.position=Vector3(11,11,14);camera.look_at(Vector3(0,1.1,-1));camera.far=200
	var light: DirectionalLight3D
	for child in get_children():
		if child is DirectionalLight3D: light=child; break
	var env: Environment
	for child in get_children():
		if child is WorldEnvironment: env=child.environment
	for setting in ["day","shade","backlight"]:
		light.rotation_degrees=Vector3(-48,-32,0) if setting!="backlight" else Vector3(-18,150,0)
		light.light_energy=.25 if setting=="shade" else 1.35
		env.ambient_light_energy=.36
		title.text="INK v1 / "+setting;subtitle.text="Shared light, materials and contour / mixed asset review"
		await get_tree().create_timer(.5).timeout;await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(dest+"mixed-"+setting+".png")==OK)
	print("INK_FAMILY_CAPTURE_COMPLETE ",RenderingServer.get_video_adapter_name())
	get_tree().quit()
