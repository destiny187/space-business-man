extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(480,480)
	var preview:=FrontierEquipmentPreview.new();root.add_child(preview);preview.size=Vector2(480,480)
	var models: Array=["manual_tool","equipment/pulse_carbine","equipment/terrain_shaper"]
	for arg in OS.get_cmdline_user_args():
		if arg=="--all-equipment":
			models.clear()
			for definition in FrontierEquipment.config().items.values():
				if definition.model not in models:models.append(definition.model)
		if arg.begins_with("--model="):models=[arg.trim_prefix("--model=")]
	var jobs: Array[Dictionary]=[]
	if "--resources-only" not in OS.get_cmdline_user_args():
		for model in models:jobs.append({"model":model,"output":"res://assets/ui/equipment/"+model.get_file()+".png"})
	if "--resources-only" in OS.get_cmdline_user_args():
		for file in DirAccess.get_files_at("res://assets/ui/resources"):
			if not file.ends_with(".png"):continue
			var id:=file.get_basename()
			var definition:=FrontierProductionTier2.product(id)
			var model: String=str(definition.get("model",FrontierMinerals.entry(id).get("model","")))
			if model.is_empty() and ResourceLoader.exists("res://assets/models/products/"+id+".glb"):model="products/"+id
			if model.is_empty():push_error("Missing icon model: "+id);quit(1);return
			jobs.append({"model":model.trim_prefix("res://assets/models/").trim_suffix(".glb"),"output":"res://assets/ui/resources/"+file})
	if "--facilities-only" in OS.get_cmdline_user_args():
		jobs.clear()
		for id in FrontierExpeditionBusiness.config().buildings:
			var model: String=FrontierCatalog.entry("buildings",id).model
			jobs.append({"model":model,"output":"res://assets/ui/previews/"+model+".png"})
	for job in jobs:
		var destination:=ProjectSettings.globalize_path(job.output)
		if FileAccess.file_exists(destination):preview.size=Image.load_from_file(destination).get_size()
		preview.show_model(job.model);preview.camera.size*=.75
		await create_timer(.35).timeout;await RenderingServer.frame_post_draw
		var image:=preview.viewport.get_texture().get_image()
		assert(image.get_pixel(0,0).a<.01,"inventory icon background must remain transparent")
		assert(image.save_png(destination)==OK)
		print("INVENTORY_ICON ",job.model," ",image.get_size())
	quit()
