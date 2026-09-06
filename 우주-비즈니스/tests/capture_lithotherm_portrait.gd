extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var studio: Node3D=load("res://scenes/showcase/ink_catalog.tscn").instantiate()
	root.add_child(studio)
	var index: int=-1
	for i in range(studio.samples.size()):
		if studio.samples[i].id=="lithotherm": index=i
	assert(index>=0)
	studio.select_sample(index)
	studio.helper.hide()
	var font:=FontVariation.new()
	font.base_font=load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype={2003265652:600}
	studio.title.add_theme_font_override("font",font)
	studio.subtitle.add_theme_font_override("font",font)
	root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var dest:=ProjectSettings.globalize_path("res://../docs/production/media/ink-catalog/")
	var img:=root.get_texture().get_image()
	assert(img.save_png(dest+"lithotherm.png")==OK)
	studio.canvas.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var portrait:=root.get_texture().get_image()
	portrait.resize(480,400,Image.INTERPOLATE_LANCZOS)
	assert(portrait.save_png(ProjectSettings.globalize_path("res://assets/ui/previews/lithotherm.png"))==OK)
	# Update only this group board and this asset's metadata; preserve older captures.
	var rows: Array=[]
	for row in studio.samples:
		if row.group=="발견·환경": rows.append(row)
	var board:=Image.create(1440,int(ceil(rows.size()/2.))*600,false,Image.FORMAT_RGBA8)
	board.fill(Color("e5e2d6"))
	for i in range(rows.size()):
		var tile:=Image.load_from_file(dest+rows[i].id+".png")
		tile.convert(Image.FORMAT_RGBA8)
		tile.resize(720,600,Image.INTERPOLATE_LANCZOS)
		board.blit_rect(tile,Rect2i(0,0,720,600),Vector2i(i%2*720,int(i/2)*600))
	assert(board.save_png(dest+"board-environment.png")==OK)
	var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dest+"renders.json"))
	var keep: Array=[]
	for row in record.assets:
		if row.id!="lithotherm": keep.append(row)
	keep.append({"id":"lithotherm","model":studio.samples[index].model,"geometry":"visual-prototype","resolution":[img.get_width(),img.get_height()]})
	record.assets=keep
	record["incremental_capture"]={"id":"lithotherm","script":"tests/capture_lithotherm_portrait.gd","screen_space_aa":"FXAA","status":"visual-prototype"}
	FileAccess.open(dest+"renders.json",FileAccess.WRITE).store_string(JSON.stringify(record,"  ")+"\n")
	print("LITHOTHERM_PORTRAIT_COMPLETE")
	quit()
