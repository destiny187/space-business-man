extends SceneTree
## Capture one registry asset through the unchanged production studio.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var requested := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="):requested=arg.trim_prefix("--asset=")
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/render_assets.json"))
	var selected := -1
	for i in rows.size():
		if rows[i].id==requested:selected=i
	if selected<0:printerr("Unknown render asset: "+requested);quit(1);return
	var studio: Node=load("res://scenes/showcase/ink_catalog.tscn").instantiate()
	root.add_child(studio)
	studio.select_sample(selected)
	studio.helper.hide()
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var shot:=root.get_texture().get_image()
	var dest:=ProjectSettings.globalize_path("res://../docs/production/media/ink-catalog/")
	assert(shot.save_png(dest+requested+".png")==OK)
	studio.canvas.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var portrait:=root.get_texture().get_image()
	portrait.resize(480,400,Image.INTERPOLATE_LANCZOS)
	assert(portrait.save_png(ProjectSettings.globalize_path("res://assets/ui/previews/"+requested+".png"))==OK)
	var groups: Dictionary={"장비":"equipment","시설":"buildings","자원":"resources","발견·환경":"environment","승인 기준작":"references"}
	var group: String=rows[selected].group
	var count:=0
	for i in selected:
		if rows[i].group==group:count+=1
	var board_path: String=dest+"board-"+groups[group]+".png"
	if FileAccess.file_exists(board_path):
		var board:=Image.load_from_file(board_path)
		if board.get_height()>=(count/2+1)*600:
			shot.resize(720,600,Image.INTERPOLATE_LANCZOS)
			shot.convert(board.get_format())
			board.blit_rect(shot,Rect2i(0,0,720,600),Vector2i((count%2)*720,(count/2)*600))
			assert(board.save_png(board_path)==OK)
	print("INK_ASSET_CAPTURE ",requested)
	quit()
