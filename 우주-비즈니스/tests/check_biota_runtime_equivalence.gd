extends SceneTree
## Reuse an actual render ONLY after both actor revisions produce identical
## installed models, materials, joints and skeletal poses for the complete set.
var failures: Array[String]=[]
var checked:=0
var models: Dictionary={}
func _initialize():run.call_deferred()
func fail(label: String):
	if failures.size()<100:failures.append(label)
func compare(a: Node3D,b: Node3D,form: Dictionary,state: String):
	if a.models.size()!=2 or b.models.size()!=2:fail(form.id+" missing LOD "+state);return
	for lod in 2:
		if a.models[lod].scene_file_path!=b.models[lod].scene_file_path or not a.models[lod].transform.is_equal_approx(b.models[lod].transform):fail(form.id+" model transform/resource "+state)
		if a.models[lod].visible!=b.models[lod].visible:fail(form.id+" LOD visibility "+state)
		if a.joints[lod].keys()!=b.joints[lod].keys():fail(form.id+" hinge inventory "+state);continue
		for key in a.joints[lod]:
			if not a.joints[lod][key].node.transform.is_equal_approx(b.joints[lod][key].node.transform):fail(form.id+" hinge "+key+" "+state)
		var sa: Skeleton3D=a.anatomical_skeletons[lod];var sb: Skeleton3D=b.anatomical_skeletons[lod]
		if sa==null or sb==null or sa.get_bone_count()!=sb.get_bone_count():fail(form.id+" skeleton inventory "+state);continue
		for bone in sa.get_bone_count():
			if sa.get_bone_name(bone)!=sb.get_bone_name(bone) or not sa.get_bone_rest(bone).is_equal_approx(sb.get_bone_rest(bone)) or not sa.get_bone_pose(bone).is_equal_approx(sb.get_bone_pose(bone)):fail(form.id+" bone "+str(bone)+" "+state)
	if a.material_slots.keys()!=b.material_slots.keys():fail(form.id+" material slots "+state);return
	for slot in a.material_slots:
		if a.material_slots[slot].size()!=b.material_slots[slot].size():fail(form.id+" material count "+state);continue
		for i in a.material_slots[slot].size():
			var ma: ShaderMaterial=a.material_slots[slot][i];var mb: ShaderMaterial=b.material_slots[slot][i]
			if ma.shader.code!=mb.shader.code:fail(form.id+" shader "+state);continue
			for parameter in ma.shader.get_shader_uniform_list():
				var av=ma.get_shader_parameter(parameter.name);var bv=mb.get_shader_parameter(parameter.name)
				if av is Object or bv is Object:
					if av!=bv:fail(form.id+" resource uniform "+str(parameter.name))
				elif av!=bv:fail(form.id+" material uniform "+str(parameter.name))
func run():
	var source:="";var target:="";var limit:=7000;var excluded: Array=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):source=arg.trim_prefix("--source=")
		if arg.begins_with("--target="):target=arg.trim_prefix("--target=")
		if arg.begins_with("--limit="):limit=int(arg.trim_prefix("--limit="))
	if "--exclude-replacements" in OS.get_cmdline_user_args():
		var recipes: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/biota_recipes.json")).species
		for recipe in recipes:
			if recipe.has("replacement"):excluded.append(recipe.id)
	if source.is_empty() or target.is_empty():quit(2);return
	var source_hash:=FileAccess.get_sha256(source);var target_hash:=FileAccess.get_sha256(target)
	var before_script:=GDScript.new();before_script.source_code=FileAccess.get_file_as_string(source)
	var after_script:=GDScript.new();after_script.source_code=FileAccess.get_file_as_string(target)
	if before_script.reload()!=OK or after_script.reload()!=OK:quit(2);return
	var forms: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/biota_preview_forms.json")).forms
	if forms.size()!=7000:fail("not a complete asset catalogue")
	for form in forms.slice(0,mini(limit,forms.size())):
		if form.id in excluded:continue # Changed anatomy gets new renders, never recycled evidence.
		var a: Node3D=before_script.new();var b: Node3D=after_script.new();root.add_child(a);root.add_child(b)
		a.set_process(false);b.set_process(false);a.paused=true;b.paused=true
		a.configure(form);b.defer_far=true;b.configure(form)
		if b.models.size()!=1:fail(form.id+" far model was not deferred")
		b.set_lod(true);b.finish_lods();a.set_lod(true)
		compare(a,b,form,"deferred-far-install")
		for state in ["idle","move","feed","dormant","stressed"]:
			a.set_lod(false);b.set_lod(false);a.set_state(state);b.set_state(state);a.elapsed=.74;b.elapsed=.74;a.pose();b.pose()
			compare(a,b,form,state)
		# Shared material caches must also preserve a changed appearance.
		var look: Dictionary={"palette":["62868b","b3b490","ba825f"],"scale":1.12}
		a.apply_appearance(look);b.apply_appearance(look);compare(a,b,form,"appearance")
		a.free();b.free();checked+=1
		models[form.id]={"near":form.lods.near.sha256,"far":form.lods.far.sha256}
		if checked%100==0:print("BIOTA_RUNTIME_EQUIVALENCE ",checked,"/",limit," failures=",failures.size())
		if not failures.is_empty():break
		if checked%25==0:await process_frame
	var current_hash:=FileAccess.get_sha256("res://scripts/actors/creatures/bestiary_actor.gd")
	var output:="res://../docs/production/media/biota/runtime/equivalence.json" if limit==7000 else "res://../docs/production/media/biota/runtime/equivalence-probe.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"version":2,"source_sha256":source_hash,"target_sha256":target_hash,"current_at_finish":current_hash,"source_snapshot":source,"target_snapshot":target,"checked":checked,"excluded":excluded,"complete":checked+excluded.size()==7000 and failures.is_empty(),"failures":failures,"models":models,"scope":"명시적으로 제외한 교체종 외 전수: 두 LOD 설치·지연 설치·가시성·모델 리소스/변환·모든 관절/본 기본자세와 다섯 상태 포즈·재질/외형 일치. 교체종은 새 렌더 필수."},"  "))
	print("BIOTA_RUNTIME_EQUIVALENCE_FINAL ",checked," failures=",failures);quit(0 if failures.is_empty() else 1)
