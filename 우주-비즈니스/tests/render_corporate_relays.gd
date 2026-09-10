extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
	samples=[]
	for entry in [["lotus","LOTUS 개척 보급"],["mine","mine 산업 집하"],["coopertech","CooperTech 봉인 장비"],["retired","운항이 중단된 물류항"]]:
		samples.append({"id":"relay_"+entry[0],"title":entry[1],"name":entry[1],"model":"res://assets/models/ships/relay_"+entry[0]+".glb"})
	super._ready()
func capture_all() -> void:
	await get_tree().process_frame;helper.hide()
	var folder:=ProjectSettings.globalize_path("res://../docs/production/media/corporate-space/")
	for i in samples.size():
		direction=Vector3(1.2,.9,1.8).normalized();select_sample(i)
		await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder+samples[i].id+"-ink.png")
	print("CORPORATE_RELAY_INK_RENDER_OK");get_tree().quit()
