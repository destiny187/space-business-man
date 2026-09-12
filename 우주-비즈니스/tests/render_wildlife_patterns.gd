extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var folder:="res://../docs/production/media/native-patterns"
	DirAccess.make_dir_recursive_absolute(folder)
	var scene: Node=load("res://scenes/showcase/bestiary.tscn").instantiate();root.add_child(scene);await process_frame
	for node in scene.get_children():
		if node is CanvasLayer:node.hide()
	scene.set_process(false);root.size=Vector2i(1100,800);root.content_scale_size=root.size
	var chosen: Dictionary={}
	for form in FrontierEcologyCatalog.all_forms():
		var type: String=form.get("construction","")
		if type in ["bovid","felid","mantid"] and not chosen.has(type):chosen[type]=form
		elif form.get("attack","")=="slam" and FrontierEcologyCatalog.ground_form(form) and not chosen.has("slam"):chosen.slam=form
	var records: Array=[]
	for type in chosen:
		var form: Dictionary=chosen[type];var look_id:=FrontierEcologyCatalog.look_for_seed(form.id,0)
		scene.actor.position=Vector3.ZERO;scene.actor.configure(form,FrontierEcologyCatalog.look(form.id,look_id));scene.actor.set_process(false)
		var info:=FrontierWildlifeCombat.profile({"form_id":form.id,"look_id":look_id})
		var mode: String=info.behavior
		var target:=Vector3(0,.7,3) if mode in ["charge","leap"] else Vector3(0,.8,0)
		scene.camera.position=target+Vector3(10,10,14);scene.camera.look_at(target);scene.camera.size=13 if mode in ["charge","leap","shockwave"] else 7
		for stage in (["windup","motion","second","recovery"] if mode=="double_sweep" else ["windup","motion","recovery"]):
			var clock: float=float(info.windup)*.8 if stage=="windup" else (float(info.windup)+float(info.active)*.5 if stage=="motion" else float(info.windup)+float(info.active)+.12)
			if mode=="double_sweep" and stage in ["motion","second"]:clock=float(info.windup)+.10+(float(info.second_strike) if stage=="second" else 0.0)
			var live: Dictionary={"position":[0,0,0],"phase":"attack","time":clock,"air_height":0.0,"attack":{"mode":mode,"goal":[0,0,5],"blocked":false}}
			if mode=="leap" and stage=="motion":live.position=[0,0,2.5];live.air_height=info.leap_height
			elif mode=="leap" and stage=="recovery":live.position=[0,0,5]
			elif mode=="charge" and stage!="windup":live.position=[0,0,4.5]
			scene.actor.position=FrontierWildlifeCombat.body_position(live)
			scene.actor.apply_combat(live,info,false);scene.actor.pose()
			await process_frame;await RenderingServer.frame_post_draw
			var filename: String=type+"-"+stage+".png";root.get_texture().get_image().save_png(folder+"/"+filename)
			records.append({"form_id":form.id,"behavior":mode,"stage":stage,"file":filename})
		print("NATIVE_PATTERN_RENDER ",type," ",mode)
	FileAccess.open(folder+"/render-records.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"));quit()
