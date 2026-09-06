extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr(message)
func run() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_icons.json"))
	var seen: Dictionary={}
	for row in manifest.icons:
		check(not seen.has(row.id),"Duplicate ID: "+row.id);seen[row.id]=true
		check(FileAccess.file_exists("res://../"+row.source),"Missing PRD source: "+row.source)
		var texture:=FrontierResourceIcons.texture(row.id)
		check(texture!=null and texture.get_size()==Vector2(128,128),"Invalid SVG: "+row.id)
		for alias in row.aliases:check(FrontierResourceIcons.texture(alias)==texture,"Alias mismatch: "+alias)
	for id in FrontierCatalog.table("resources"):check(seen.has(id),"Runtime resource missing: "+id)
	for id in FrontierFieldEngineering.config().projects:check(seen.has(id),"Engineering asset missing: "+id)
	check(FrontierResourceIcons.specimen_id({"category":"animal"})=="animal_sample","Animal specimen mapping")
	check(FrontierResourceIcons.specimen_id({"category":"plant"})=="plant_sample","Plant specimen mapping")
	check(FrontierResourceIcons.specimen_id({"category":"microbe"})=="microbe_sample","Microbe specimen mapping")
	check(FrontierResourceIcons.texture("unregistered_item")==null,"Unknown item must not look like stone")
	check(FrontierResourceIcons.markup("생체 표본 +3").contains("bio_sample.svg"),"Planned resource readout")
	root.size=Vector2i(960,640)
	var viewport:=SubViewport.new();viewport.size=Vector2i(1600,2130);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var board:=ColorRect.new();board.color=Color("10232e");board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);viewport.add_child(board)
	var theme:=Theme.new();theme.default_font=load("res://assets/fonts/NotoSansKR.ttf");theme.default_font_size=16;board.theme=theme
	var title:=Label.new();title.position=Vector2(40,20);title.text="PRD 재화·표본·지식 자산  /  SVG %d종"%manifest.icons.size();title.add_theme_font_size_override("font_size",30);board.add_child(title)
	var subtitle:=Label.new();subtitle.position=Vector2(40,65);subtitle.text="실물 재화와 영구 지식은 별도 자산입니다. 기획 범주 아이콘은 해당 기능의 구현 완료를 뜻하지 않습니다.";subtitle.modulate=Color("a1b4bf");board.add_child(subtitle)
	for i in manifest.icons.size():
		var row: Dictionary=manifest.icons[i]
		var at:=Vector2(40+(i%7)*220,110+(i/7)*181)
		var panel:=Panel.new();panel.position=at;panel.size=Vector2(204,167);board.add_child(panel)
		var style:=StyleBoxFlat.new();style.bg_color=Color("1b3442");style.set_corner_radius_all(8);panel.add_theme_stylebox_override("panel",style)
		var icon:=FrontierResourceIcons.view(row.id,104);icon.position=Vector2(50,4);icon.size=Vector2(104,104);panel.add_child(icon)
		var label:=Label.new();label.position=Vector2(4,109);label.size.x=196;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.text=row.name;panel.add_child(label)
		var code:=Label.new();code.position=Vector2(4,137);code.size.x=196;code.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;code.text=row.id;code.add_theme_font_size_override("font_size",12);code.modulate=Color("a1b4bf");panel.add_child(code)
	await process_frame;await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var output: String="res://../docs/production/media/resource-icons/prd-board.png"
		check(viewport.get_texture().get_image().save_png(output)==OK,"Save contact sheet")
	viewport.queue_free();await process_frame
	print("PRD_ICON_CHECKS ",checks," FAILURES ",failures," ASSETS ",manifest.icons.size());quit(1 if failures else 0)
