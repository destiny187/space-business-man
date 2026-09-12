extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
	samples=[]
	for id in ["pirate_gunship","expedition_missile_mount","ship_missile"]:samples.append({"id":id,"title":"전투함과 유도 미사일 / INK v1","name":id,"model":"res://assets/models/ships/"+id+".glb"})
	super._ready()
func capture_all() -> void:
	await get_tree().process_frame;helper.hide();direction=Vector3(1.2,.9,-1.8).normalized()
	for i in samples.size():
		select_sample(i);await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/production/media/pirate-missiles/"+samples[i].id+"-ink.png"))
	get_tree().quit()
