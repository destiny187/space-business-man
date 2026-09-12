extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var folder:="res://../docs/production/media/native-combat"
	DirAccess.make_dir_recursive_absolute(folder)
	var scene: Node=load("res://scenes/showcase/bestiary.tscn").instantiate();root.add_child(scene);await process_frame
	for node in scene.get_children():
		if node is CanvasLayer:node.hide()
	scene.set_process(false);root.size=Vector2i(960,700);root.content_scale_size=root.size
	var chosen: Dictionary={}
	for form in FrontierEcologyCatalog.all_forms():
		var type: String=form.get("construction","")
		if FrontierWildlifeCombat.config().anatomical_attacks.has(type) and not chosen.has(type):chosen[type]=form
		elif form.get("attack","") in ["kick","slam"] and FrontierEcologyCatalog.ground_form(form) and not chosen.has(form.attack):chosen[form.attack]=form
	var results: Array=[]
	for type in chosen:
		var form: Dictionary=chosen[type];var look_id:=FrontierEcologyCatalog.look_for_seed(form.id,0);var appearance:=FrontierEcologyCatalog.look(form.id,look_id)
		scene.actor.configure(form,appearance);scene.actor.set_process(false);scene.actor.combat_override=false;scene.frame_subject()
		var info:=FrontierWildlifeCombat.profile({"form_id":form.id,"look_id":look_id})
		var record: Dictionary={"form_id":form.id,"look_id":look_id,"type":type,"pattern":info.pattern,"screens":[]}
		for phase in ["windup","strike"]:
			var clock: float=float(info.windup)*.8 if phase=="windup" else float(info.windup)+float(info.active)*.5
			scene.actor.apply_combat({"phase":"attack","time":clock},info,false);scene.actor.pose()
			await process_frame;await RenderingServer.frame_post_draw
			var filename: String=str(type)+"-"+str(phase)+".png";root.get_texture().get_image().save_png(folder+"/"+filename);record.screens.append(filename)
		results.append(record)
		print("NATIVE_RIG_RENDER ",type," ",info.pattern)
	FileAccess.open(folder+"/render-records.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	quit()
