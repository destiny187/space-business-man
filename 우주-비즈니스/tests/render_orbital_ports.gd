extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
	samples=[
		{"id":"solar_mars_port","title":"Space Y / 화성 환경 운영과 물류","name":"MARS Y-01","model":"res://assets/models/ships/solar_mars_port.glb"},
		{"id":"solar_earth_logistics","title":"Space Y / 지구 화물 집결지","name":"EARTH Y-02","model":"res://assets/models/ships/solar_earth_logistics.glb"}]
	super._ready()
func capture_all() -> void:
	await get_tree().process_frame;helper.hide()
	var folder:=ProjectSettings.globalize_path("res://../docs/production/media/corporate-space/")
	for i in samples.size():
		direction=Vector3(1.2,.9,1.8).normalized();select_sample(i)
		await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder+samples[i].id+"-ink.png")
	print("ORBITAL_PORT_INK_RENDER_OK");get_tree().quit()
