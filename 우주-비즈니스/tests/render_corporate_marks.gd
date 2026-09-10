extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
	samples=[
		{"id":"heron","title":"LOTUS / 운영사 도장","name":"HERON · 현장 보급선","model":"res://assets/models/lotus/heron.glb"},
		{"id":"supply_crate","title":"LOTUS / 운영사 표식","name":"투하 보급 상자 · 화물·뚜껑 유지","model":"res://assets/models/lotus/supply_crate.glb"},
		{"id":"miner","title":"mine / 제조사 명판","name":"자동 채광로봇 · 운영은 원정대","model":"res://assets/models/miner.glb"},
		{"id":"robot","title":"CooperTech / 제조사 명판","name":"폐기 전투로봇 · 운영 주체 미확인","model":"res://assets/models/incidents/robot.glb"}]
	super._ready()
func capture_all() -> void:
	await get_tree().process_frame;helper.hide()
	var folder:=ProjectSettings.globalize_path("res://../docs/production/media/corporate-presence/")
	DirAccess.make_dir_recursive_absolute(folder)
	for i in samples.size():
		if "--heron-only" in OS.get_cmdline_user_args() and i!=0:continue
		direction=Vector3(1.2,.75,-1.8 if i<2 else 1.8).normalized();select_sample(i)
		var weak:=subject.find_child("Anim_Weak",true,false)
		if weak!=null:weak.hide()
		await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder+samples[i].id+"-godot.png")
	if "--heron-only" in OS.get_cmdline_user_args():print("CORPORATE_HERON_RENDER_OK");get_tree().quit();return
	title.get_parent().hide();studio_ground.hide();get_viewport().transparent_bg=true
	contour.set_shader_parameter("transparent_background",true)
	get_window().size=Vector2i(512,512);get_window().content_scale_size=Vector2i(512,512)
	for row in [[2,"res://assets/ui/previews/miner.png"],[3,"res://assets/ui/discoveries/illuti_dormant_combat_robot.png"]]:
		direction=Vector3(1.2,.65,1.8).normalized();select_sample(row[0])
		var weak:=subject.find_child("Anim_Weak",true,false)
		if weak!=null:weak.hide()
		await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(row[1]))
	print("CORPORATE_INK_RENDER_OK");get_tree().quit()
