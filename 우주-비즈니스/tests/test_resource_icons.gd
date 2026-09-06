extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok: failures += 1; printerr(description)
func run() -> void:
	root.size = Vector2i(960,640)
	for id in FrontierCatalog.table("resources"):
		check(FrontierResourceIcons.texture(id) != null,"Missing icon: "+id)
	check(FrontierResourceIcons.markup("광물 +3").contains("stone.svg[/img]\u00a0+3"),"Signed pickup survives")
	check(FrontierResourceIcons.markup("철 0 / 20 · 구리 99999").contains("0\u00a0/\u00a020"),"Inventory cost survives")
	check(FrontierResourceIcons.markup("광물을 연구합니다.") == "광물을 연구합니다.","Prose remains readable")
	var board := ColorRect.new();board.color=Color("10232e");board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(board)
	var column := VBoxContainer.new();column.position=Vector2(40,35);column.size.x=880;column.add_theme_constant_override("separation",22);board.add_child(column)
	var font: Font=load("res://assets/fonts/NotoSansKR.ttf")
	var theme:=Theme.new();theme.default_font=font;column.theme=theme
	var title:=Label.new();title.text="원정 재화  /  INK SVG";title.add_theme_font_size_override("font_size",28);column.add_child(title)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",22);column.add_child(row)
	for id in ["iron","copper","stone","ice","crystal","credits"]:
		var cell:=VBoxContainer.new();row.add_child(cell);cell.add_child(FrontierResourceIcons.view(id,112))
		var label:=Label.new();label.text=FrontierResourceIcons.names()[id];label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cell.add_child(label)
	for source in ["채집   광물 +3", "창고   철 120 · 구리 64 · 암석 320 · 얼음 28 · 희귀 결정 3", "배낭   철 0 · 구리 3 · 암석 12 · 얼음 0 · 희귀 결정 1"]:
		var readout:=FrontierResourceReadout.new();readout.value=source;column.add_child(readout)
		check(readout.value==source and readout.tooltip_text==source,"Readable source retained")
	await process_frame;await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../test-results/resource-icons"))
		root.get_texture().get_image().save_png("res://../test-results/resource-icons/board.png")
	board.queue_free();await process_frame
	var app: Node=load("res://scenes/app/main.tscn").instantiate();root.add_child(app);await process_frame
	app.smoke_mode=true;app._smoke_setup();await create_timer(.5).timeout
	app.hud.feedback("stone",3)
	check(app.hud.pickup_text=="+3" and app.hud.pickup_resource=="stone","HUD pickup uses resource ID and amount")
	if DisplayServer.get_name() != "headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../test-results/resource-icons/game.png")
	app._show_menu("build")
	await process_frame;await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../test-results/resource-icons/costs.png")
	app.queue_free();await process_frame
	print("RESOURCE_ICONS failures=",failures);quit(1 if failures else 0)
