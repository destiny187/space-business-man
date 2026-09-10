extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
	samples=[]
	for entry in [["lotus","Lotus 개척 비콘"],["mine","mine 집하·정비대"],["coopertech","CooperTech 감시·봉인 화물"]]:
		samples.append({"id":"trace_"+entry[0],"title":entry[1],"name":entry[1],"model":"res://assets/models/ships/trace_"+entry[0]+".glb"})
	super._ready()
func capture_all() -> void:
	await get_tree().process_frame;helper.hide()
	var folder:=ProjectSettings.globalize_path("res://../docs/production/media/corporate-traces/")
	for i in samples.size():
		direction=Vector3(1.2,.9,1.8).normalized();select_sample(i)
		await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder+samples[i].id+"-ink.png")
		# Same actual GLB in the transparent INK menu renderer, used as static J tile.
		var layer:=CanvasLayer.new();add_child(layer)
		var preview:=FrontierEquipmentPreview.new();layer.add_child(preview);preview.size=Vector2(480,400)
		preview.show_model("ships/"+str(samples[i].id));FrontierCorporateIdentity.frame_trace_preview(preview);await get_tree().create_timer(.4).timeout;await RenderingServer.frame_post_draw
		preview.viewport.get_texture().get_image().save_png("res://assets/ui/corporations/"+str(samples[i].id)+".png")
		layer.queue_free();await get_tree().process_frame
	print("CORPORATE_TRACE_INK_RENDER_OK");get_tree().quit()
