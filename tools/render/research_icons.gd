extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(320,320)
	var preview:=FrontierEquipmentPreview.new();root.add_child(preview);preview.size=Vector2(256,256)
	var folder:=ProjectSettings.globalize_path("res://assets/ui/research")
	DirAccess.make_dir_recursive_absolute(folder)
	var models: Dictionary=load("res://scripts/ui/research_panel.gd").MODELS
	for key in FrontierExpeditionBusiness.config().technologies:
		preview.show_model(models[key])
		for i in 4:await process_frame
		await RenderingServer.frame_post_draw
		preview.viewport.get_texture().get_image().save_png(folder+"/"+key+".png")
	print("RESEARCH ICONS RENDERED")
	quit()
