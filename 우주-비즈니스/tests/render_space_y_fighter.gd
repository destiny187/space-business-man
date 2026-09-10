extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
	samples=[{"id":"space_y_fighter","title":"Space Y / 궤도 경비 편대","name":"WARDEN Y","model":"res://assets/models/ships/space_y_fighter.glb"}]
	super._ready()
func capture_all() -> void:
	await get_tree().process_frame;helper.hide();direction=Vector3(1.2,.9,-1.8).normalized();select_sample(0)
	await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/production/media/corporate-space/space_y_fighter-ink.png"))
	get_tree().quit()
