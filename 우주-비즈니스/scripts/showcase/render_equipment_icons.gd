extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(480,480)
	var preview:=FrontierEquipmentPreview.new();root.add_child(preview);preview.size=Vector2(480,480)
	for model in ["manual_tool","equipment/pulse_carbine","equipment/terrain_shaper"]:
		preview.show_model(model);preview.camera.size*=.75
		await create_timer(.35).timeout;await RenderingServer.frame_post_draw
		var image:=preview.viewport.get_texture().get_image()
		var destination:=ProjectSettings.globalize_path("res://assets/ui/equipment/"+model.get_file()+".png")
		assert(image.save_png(destination)==OK)
		print("EQUIPMENT_ICON ",model)
	quit()
