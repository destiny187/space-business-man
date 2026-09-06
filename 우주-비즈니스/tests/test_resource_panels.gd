extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,description: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(description)
func run() -> void:
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	var layer:=Control.new();layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(layer)
	var theme:=Theme.new();theme.default_font=load("res://assets/fonts/NotoSansKR.ttf");layer.theme=theme
	var business:=FrontierBusinessPanel.new();layer.add_child(business);business.show()
	check(business.building_cost.text.contains("[img="),"Building selection displays resource costs")
	check(business.supply.get_item_icon(0)!=null,"Supply selection displays resource icon")
	check(business.research_prototype_button.get_child_count()>0,"Research costs display inline icons")
	var called:=[]
	business.command.connect(func(kind: String,_args: Dictionary):called.append(kind))
	business.research_prototype_button.pressed.emit()
	check(called==["business_research_prototype"],"Icon caption preserves button command")
	business.summary.value="공동 자금 1,200 Cr · 격납고 0/4"
	check(business.summary.text.contains("credits.svg[/img]") and business.summary.text.contains("1,200"),"Currency amount preserved")
	check(FrontierResourceIcons.markup("부품 4").contains("research_parts.svg"),"Refit parts map to research parts")
	business.queue_free();await process_frame
	# The refit feature is maintained in a separate, potentially uncommitted task.
	if FileAccess.file_exists("res://scripts/ui/shipyard_panel.gd"):
		var shipyard: PanelContainer=load("res://scripts/ui/shipyard_panel.gd").new();layer.add_child(shipyard);shipyard.show()
		shipyard.summary.value="공동 자금 1,200 Cr · 부품 4"
		check(shipyard.kind.get_item_icon(0)!=null,"Ship module selector has icon")
		check(shipyard.actions[0].get_child_count()>0,"Module build shows material and credit icons")
		await process_frame;await process_frame
		check(shipyard.get_global_rect().end.x<=960,"Refit panel fits viewport")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../docs/production/media/resource-icons/shipyard-ui.png")
	layer.queue_free();await process_frame
	print("RESOURCE_PANEL_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
