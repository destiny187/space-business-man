extends "res://scripts/showcase/ink_samples.gd"
## Every currently required GLB, rendered by the production ink pipeline.
var canvas: CanvasLayer

func _ready() -> void:
	samples = JSON.parse_string(FileAccess.get_file_as_string("res://data/render_assets.json"))
	super._ready()
	DisplayServer.window_set_title("우주 비즈니스맨 — 필수 자산 / INK v1")
	helper.text = "← → 자산 선택    드래그 회전    휠 확대    Space 자동 회전    Esc 종료"
	canvas = title.get_parent()

func select_sample(which: int) -> void:
	var view: Array = samples[posmod(which,samples.size())].get("view_direction",[1.22,.84,1.70])
	direction = Vector3(view[0],view[1],view[2]).normalized()
	super.select_sample(posmod(which,samples.size()))
	if samples[index].get("surface","") == "strata":
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/materials/strata.gdshader")
		mat.set_shader_parameter("rough",.96)
		for mi in subject.find_children("*","MeshInstance3D",true,false): mi.material_override = mat

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_RIGHT: select_sample(index+1)
		if event.keycode == KEY_LEFT: select_sample(index-1)
	super._unhandled_input(event)

func capture_all() -> void:
	# Deferred so the subclass finishes constructing its UI first.
	await get_tree().process_frame
	helper.hide()
	var dest := ProjectSettings.globalize_path("res://../docs/production/media/ink-catalog/")
	var preview_dest := ProjectSettings.globalize_path("res://assets/ui/previews/")
	DirAccess.make_dir_recursive_absolute(dest)
	var boards: Dictionary = {}
	var counts: Dictionary = {}
	var records: Array = []
	for sample in samples: counts[sample.group] = counts.get(sample.group,0)+1
	for group in counts:
		boards[group] = Image.create(1440,int(ceil(counts[group]/2.))*600,false,Image.FORMAT_RGBA8)
		boards[group].fill(Color("e5e2d6"))
		counts[group] = 0
	for i in range(samples.size()):
		select_sample(i)
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		assert(shot.save_png(dest+samples[i].id+".png") == OK)
		var tile := shot.duplicate() as Image
		tile.resize(720,600,Image.INTERPOLATE_LANCZOS)
		var group: String = samples[i].group
		var n: int = counts[group]
		boards[group].blit_rect(tile,Rect2i(0,0,720,600),Vector2i((n%2)*720,(n/2)*600))
		counts[group] += 1
		canvas.hide()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var portrait := get_viewport().get_texture().get_image()
		portrait.resize(480,400,Image.INTERPOLATE_LANCZOS)
		assert(portrait.save_png(preview_dest+samples[i].id+".png") == OK)
		canvas.show()
		records.append({"id":samples[i].id,"model":samples[i].model,"geometry":samples[i].geometry,"resolution":[shot.get_width(),shot.get_height()]})
		print("INK_CATALOG_RENDER ",samples[i].id," ",i+1,"/",samples.size())
	var board_ids := {"장비":"equipment","시설":"buildings","자원":"resources","발견·환경":"environment","승인 기준작":"references"}
	for group in boards:
		assert(boards[group].save_png(dest+"board-"+board_ids[group]+".png") == OK)
	FileAccess.open(dest+"renders.json",FileAccess.WRITE).store_string(JSON.stringify({"style":FrontierInkStyle.config(),"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"render_scale_3d":1.5,"msaa":4,"board_tile":[720,600],"preview":[480,400],"assets":records},"  "))
	print("INK_CATALOG_COMPLETE ",records.size())
	get_tree().quit()
