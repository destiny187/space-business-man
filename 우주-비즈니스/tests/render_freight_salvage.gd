extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
	samples=[]
	for entry in [["lost_freight_pod","CARRIER 유실 포드"],["freight_cradle","선박 회수 거치대"],["freight_receiver","Space Y 인계 설비"]]:
		samples.append({"id":entry[0],"title":entry[1],"name":entry[1],"model":"res://assets/models/ships/"+entry[0]+".glb"})
	super._ready()
func capture_all() -> void:
	await get_tree().process_frame;helper.hide()
	var folder:=ProjectSettings.globalize_path("res://../docs/production/media/freight-salvage/")
	for i in samples.size():
		direction=Vector3(1.2,.9,1.8).normalized();select_sample(i)
		await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder+samples[i].id+"-ink.png")
		if i==0:
			var layer:=CanvasLayer.new();add_child(layer)
			var preview:=FrontierEquipmentPreview.new();layer.add_child(preview);preview.size=Vector2(480,400)
			preview.show_model(FrontierFreightSalvage.MODEL);FrontierCorporateIdentity.frame_trace_preview(preview);await get_tree().create_timer(.4).timeout;await RenderingServer.frame_post_draw
			preview.viewport.get_texture().get_image().save_png(FrontierFreightSalvage.ICON)
			layer.queue_free();await get_tree().process_frame
	print("FREIGHT_SALVAGE_INK_RENDER_OK");get_tree().quit()
