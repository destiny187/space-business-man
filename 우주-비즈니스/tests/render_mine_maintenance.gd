extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
	samples=[]
	for entry in [["mine_service_pack","mine 교체 카트리지"],["mine_supply_rack","교체 부품 거치대"],["mine_repair_worksite","mine 작업장 정비"]]:
		samples.append({"id":entry[0],"title":entry[1],"name":entry[1],"model":"res://assets/models/ships/"+entry[0]+".glb"})
	super._ready()
func capture_all() -> void:
	await get_tree().process_frame;helper.hide()
	var folder:=ProjectSettings.globalize_path("res://../docs/production/media/mine-maintenance/")
	for i in samples.size():
		direction=Vector3(1.2,.9,1.8).normalized();select_sample(i)
		await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder+samples[i].id+"-ink.png")
		if i==0:
			var layer:=CanvasLayer.new();add_child(layer)
			var preview:=FrontierEquipmentPreview.new();layer.add_child(preview);preview.size=Vector2(480,400)
			preview.show_model("ships/mine_service_pack");FrontierCorporateIdentity.frame_trace_preview(preview);await get_tree().create_timer(.4).timeout;await RenderingServer.frame_post_draw
			preview.viewport.get_texture().get_image().save_png("res://assets/ui/corporations/mine_service_pack.png")
			layer.queue_free();await get_tree().process_frame
	print("MINE_MAINTENANCE_INK_RENDER_OK");get_tree().quit()
