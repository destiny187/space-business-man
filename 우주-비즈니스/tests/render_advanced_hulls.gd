extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
	samples=[]
	for id in FrontierSpaceStation.config().hulls:
		var row: Dictionary=FrontierSpaceStation.config().hulls[id]
		samples.append({"id":id,"title":"원정 선체 / INK v1","name":str(row.name)+"  /  "+str(row.role),"model":str(row.model)})
	for id in ["combat_skill_emitter","combat_decoy","combat_mine"]:samples.append({"id":id,"title":"전투 장치 / INK v1","name":id,"model":"res://assets/models/ships/"+id+".glb"})
	super._ready()
func capture_all() -> void:
	await get_tree().process_frame;helper.hide();direction=Vector3(1.2,.85,-1.7).normalized()
	var folder:=ProjectSettings.globalize_path("res://../output/advanced-hulls/ink/");DirAccess.make_dir_recursive_absolute(folder)
	for i in samples.size():
		select_sample(i);await get_tree().create_timer(.4 if i>0 else 1.5).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder+str(samples[i].id)+".png")
		if FrontierSpaceStation.config().hulls.has(samples[i].id):
			title.get_parent().hide();await get_tree().process_frame;await RenderingServer.frame_post_draw
			var portrait:=get_viewport().get_texture().get_image();portrait.resize(480,400,Image.INTERPOLATE_LANCZOS)
			portrait.save_png(ProjectSettings.globalize_path("res://assets/ui/previews/hull_"+str(samples[i].id)+".png"));title.get_parent().show()
		print("ADVANCED_INK_RENDER ",samples[i].id)
	get_tree().quit()
