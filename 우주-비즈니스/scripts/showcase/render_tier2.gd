extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(480,480)
	var preview:=FrontierEquipmentPreview.new();root.add_child(preview);preview.size=Vector2(480,480)
	var board:=Image.create(480*4,480*2,false,Image.FORMAT_RGBA8)
	var models: Array=[]
	for id in FrontierProductionTier2.config().products:models.append("products/"+id)
	models.append("products/retrofit_pack")
	for kind in ["miner","pulse","terrain"]:models.append("equipment/"+kind+"_mk2")
	for i in models.size():
		var model: String=models[i];preview.show_model(model)
		await create_timer(.25).timeout;await RenderingServer.frame_post_draw
		var image:=preview.viewport.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
		var destination: String="res://assets/ui/"+("resources/" if model.begins_with("products/") else "equipment/")+model.get_file()+".png"
		assert(image.save_png(ProjectSettings.globalize_path(destination))==OK)
		if i<8:board.blit_rect(image,Rect2i(0,0,480,480),Vector2i(i%4*480,i/4*480))
		print("TIER2_RENDER ",model)
	board.save_png(ProjectSettings.globalize_path("res://../docs/production/media/tier2/products-ink.png"))
	quit()
