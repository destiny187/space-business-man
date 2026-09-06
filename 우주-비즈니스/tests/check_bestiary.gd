extends SceneTree
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
var checks:=0
var failures: Array[String]=[]
var events: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func run() -> void:
	var forms: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/forms.json")).forms
	var looks: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/appearances.json")).appearances
	check(forms.size()==600,"Expected 600 base models")
	check(looks.size()==12000,"Expected 12,000 appearance profiles")
	var actor:=Actor.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.attack_cue.connect(func(phase: String):events.append(phase))
	var seen: Dictionary={}
	for i in range(forms.size()):
		var form: Dictionary=forms[i]
		check(not seen.has(form.id),"Duplicate base model ID "+form.id)
		seen[form.id]=true
		actor.configure(form,looks[i*20])
		check(actor.models.size()==2,"Both LODs load "+form.id)
		check(actor.joints[0].keys()==actor.joints[1].keys(),"LOD motion anchors match "+form.id)
		check(not form.spawn_enabled,"Unintegrated form cannot auto-spawn "+form.id)
		var ink_ok:=true
		for model in actor.models:
			for mi in model.find_children("*","MeshInstance3D",true,false):
				for surface in range(mi.mesh.get_surface_count()):
					var mat: Material=mi.get_active_material(surface)
					ink_ok=ink_ok and mat is ShaderMaterial and mat.shader.resource_path.ends_with("ink/cel.gdshader")
		check(ink_ok,"Common INK materials "+form.id)
		for mode in ["idle","move","feed","dormant","stressed"]:
			check(actor.set_state(mode),"Visual state supported "+form.id+" "+mode)
			actor.elapsed=.72
			actor.pose()
			var matching:=true
			for key in actor.joints[0]:
				matching=matching and actor.joints[0][key].node.transform.is_equal_approx(actor.joints[1][key].node.transform)
			check(matching,"LOD pose consistency "+form.id+" "+mode)
		if form.get("collection","")=="aberrant":
			check(form.has("eye_count") and form.has("sensory_type"),"Explicit sensory anatomy "+form.id)
			check(not actor.joints[0].has("Anim_Head"),"New anatomy does not reuse paired-eye head "+form.id)
		var node_count:=actor.get_child_count()
		if form.attack!="none":
			events.clear()
			check(actor.set_state("attack"),"Attack state "+form.id)
			for time in [.2,.67,1.05,1.75]:
				actor.elapsed=time
				actor.pose()
			check(events==["windup","active","recovery","complete"],"Attack phase order "+form.id)
			check(actor.state=="idle","Attack returns to idle "+form.id)
			var hidden:=true
			for fx in actor.effect_nodes:hidden=hidden and not fx.visible
			check(hidden,"Effects cleaned after recovery "+form.id)
			for n in range(5):
				actor.set_state("attack")
				actor.elapsed=.67
				actor.pose()
			if form.get("collection","")=="aberrant":
				var moving:=false
				var matching:=true
				for key in actor.joints[0]:
					var part: Dictionary=actor.joints[0][key]
					moving=moving or not part.node.transform.is_equal_approx(part.rest)
					matching=matching and part.node.transform.is_equal_approx(actor.joints[1][key].node.transform)
				var effects_visible:=false
				for fx in actor.effect_nodes:effects_visible=effects_visible or fx.visible
				check(effects_visible,"New active attack shows VFX "+form.id)
				check(moving and matching,"New attack moves geometry consistently in both LODs "+form.id)
			check(actor.get_child_count()==node_count and actor.effect_nodes.size()==20,"Repeated attack uses bounded pool "+form.id)
			actor.set_state("idle")
		else:check(not actor.set_state("attack"),"Nonattacking form rejects attack "+form.id)
		actor.apply_appearance(looks[i*20+19])
		check(is_equal_approx(actor.base_scale,1.12),"Maximum appearance scale "+form.id)
		check(actor.appearance.environment==form.environment,"Appearance habitat stable "+form.id)
		actor.set_lod(true)
		check(not actor.models[0].visible and actor.models[1].visible,"Only far LOD visible "+form.id)
		if i%25==0:
			print("BESTIARY_CHECK_PROGRESS ",i+1,"/",forms.size())
			await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"forms":forms.size(),"appearances":looks.size(),"scope":"Asset loading, INK, motion, attack phases, VFX cleanup, LOD and appearance contracts. Not ecological or gameplay combat validation."}
	var dest:=ProjectSettings.globalize_path("res://../docs/production/media/bestiary/verification.json")
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BESTIARY_CHECKS ",checks," FAILURES ",failures.size())
	actor.free()
	quit(0 if failures.is_empty() else 1)
