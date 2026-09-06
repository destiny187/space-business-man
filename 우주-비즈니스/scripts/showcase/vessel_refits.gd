extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
	samples=[]
	for kind in FrontierVesselRefit.config().modules:
		var def:=FrontierVesselRefit.definition(kind)
		samples.append({"id":kind,"title":"KESTREL / 원정선 모듈","name":def.name,"model":"res://assets/models/"+def.model+".glb"})
	samples.append({"id":"mounted","title":"KESTREL / 장착 조합","name":"추진 보조기 + 이동 실험실","model":"res://assets/models/ships/kestrel.glb"})
	super._ready()
func select_sample(which: int) -> void:
	super.select_sample(which)
	if samples[which].id=="mounted":
		var refits:=FrontierVesselVisuals.new();subject.add_child(refits)
		var vessel:=FrontierVesselRefit.create(1)
		vessel.loadout.propulsion=FrontierVesselRefit.add_module(vessel,"drive","standard")
		vessel.loadout.utility=FrontierVesselRefit.add_module(vessel,"lab","standard")
		refits.update_loadout(vessel)
func capture_all() -> void:
	await get_tree().process_frame
	helper.hide()
	var dest:=ProjectSettings.globalize_path("res://../docs/production/media/vessel-refits/");DirAccess.make_dir_recursive_absolute(dest)
	for i in samples.size():
		select_sample(i)
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(dest+samples[i].id+".png")==OK)
		if samples[i].id!="mounted":
			title.get_parent().hide();await get_tree().process_frame;await RenderingServer.frame_post_draw
			var portrait:=get_viewport().get_texture().get_image();portrait.resize(480,400,Image.INTERPOLATE_LANCZOS)
			var model: String=samples[i].model.get_file().get_basename()
			assert(portrait.save_png(ProjectSettings.globalize_path("res://assets/ui/previews/vessel_"+model+".png"))==OK)
			title.get_parent().show()
		print("VESSEL_RENDER ",samples[i].id)
	get_tree().quit()
