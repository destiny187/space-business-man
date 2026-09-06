extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error(message)
func bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in model.find_children("*","MeshInstance3D",true,false):
		var box: AABB=model.global_transform*mi.get_aabb()
		result=box if first else result.merge(box)
		first=false
	return result
func surface_floor(model: Node3D) -> float:
	var floor_y:=INF
	for mi in model.find_children("*","MeshInstance3D",true,false):
		for surface in range(mi.mesh.get_surface_count()):
			var arrays: Array=mi.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				floor_y=minf(floor_y,(mi.global_transform*vertex).y)
	return floor_y
func press(code: Key) -> void:
	var e:=InputEventKey.new()
	e.keycode=code
	e.pressed=true
	Input.parse_input_event(e)
	await process_frame
	e=InputEventKey.new()
	e.keycode=code
	e.pressed=false
	Input.parse_input_event(e)
	await process_frame
func run() -> void:
	var scene: Node3D=load("res://scenes/showcase/lithotherm.tscn").instantiate()
	root.add_child(scene)
	await create_timer(.5).timeout
	var actor: Node3D=scene.specimen
	actor.paused=true
	actor.set_state("dormant")
	var def: Dictionary=actor.definition
	check(def.spawn_enabled==false,"Visual prototype must not enter world generation")
	check(FileAccess.file_exists("res://../art/blender/creatures/lithotherm/lithotherm.blend"),"Editable Blender source missing")
	check(actor.parts[0].size()==10 and actor.parts[1].size()==10,"Both LODs must preserve ten motion pivots")
	var near_box:=bounds(actor.variants[0])
	var far_box:=bounds(actor.variants[1])
	check(near_box.size.distance_to(far_box.size)<.12,"Far LOD changes specimen dimensions")
	var floor_y:=surface_floor(actor.variants[0])
	check(floor_y > -.015,"Resting surface penetrates ground: %f"%floor_y)
	for model in actor.variants:
		var uses_ink := true
		for mi in model.find_children("*","MeshInstance3D",true,false):
			for surface in range(mi.mesh.get_surface_count()):
				var mat: Material=mi.get_active_material(surface)
				uses_ink=uses_ink and mat is ShaderMaterial and mat.shader.resource_path.ends_with("ink/cel.gdshader")
		check(uses_ink,"LOD contains material outside common INK shader")
	for i in range(4):
		await press([KEY_1,KEY_2,KEY_3,KEY_4][i])
		check(actor.state==scene.STATES[i],"Number key did not switch state")
		actor.elapsed=.7
		actor.pose()
		var pose0: Transform3D=actor.parts[0].Anim_Head.node.transform
		var pose1: Transform3D=actor.parts[1].Anim_Head.node.transform
		check(pose0.is_equal_approx(pose1),"LOD changed current animation pose")
		actor.set_lod(true)
		check(not actor.variants[0].visible and actor.variants[1].visible,"Both LODs rendered together")
		actor.set_lod(false)
	var previous: String=actor.state
	check(not actor.set_state("unknown") and actor.state==previous,"Invalid state must retain previous state")
	actor.paused=false
	await press(KEY_SPACE)
	var frozen: float=actor.elapsed
	await create_timer(.15).timeout
	check(actor.paused and is_equal_approx(actor.elapsed,frozen),"Pause did not freeze animation")
	await press(KEY_SPACE)
	await create_timer(.15).timeout
	check(actor.elapsed>frozen,"Resume failed")
	actor.paused=true
	actor.set_state("feeding")
	actor.elapsed=.3
	actor.pose()
	var jaw: Transform3D=actor.parts[0].Anim_Jaw.node.transform
	actor.set_state("walking")
	check(not actor.parts[0].Anim_Jaw.node.transform.is_equal_approx(jaw),"Feeding jaw leaked into walking state")
	scene.buttons[0].pressed.emit()
	check(actor.state=="dormant","State button did not dispatch")
	scene.crowd_label.pressed.emit()
	check(scene.group.visible and scene.camera.size>10,"Group control did not reframe")
	scene.crowd_label.pressed.emit()
	check(not scene.group.visible,"Group control did not restore solo view")
	for i in range(3): scene.light_label.pressed.emit()
	check(scene.light_mode==0,"Lighting controls did not return to daylight")
	# Real rendered mixed scene timing; diagnostics only, not a game performance claim.
	scene.toggle_group()
	for creature in scene.group.get_children(): creature.paused=false
	actor.paused=false
	await create_timer(.5).timeout
	var timings: Array[float]=[]
	var last:=Time.get_ticks_usec()
	for i in range(120):
		await process_frame
		var now:=Time.get_ticks_usec()
		timings.append((now-last)/1000.)
		last=now
	timings.sort()
	var total:=0.0
	for value in timings: total+=value
	var report: Dictionary={"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"checks":checks,"failures":failures,"scope":"독립 생물 시연·실제 엔진 키 입력·LOD·공통 재질·상태 복원 검사. 게임 생태/저장/6인 성능 검증 아님.","studio_timing":{"creatures":9,"frames":120,"viewport":[1600,1000],"mean_ms":total/120.,"p95_ms":timings[113],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"limitation":"동일 호스트의 다른 작업 부하와 VSync를 통제하지 않은 참고 측정"}}
	var dest: String=ProjectSettings.globalize_path("res://../docs/production/media/lithotherm/verification.json")
	FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("LITHOTHERM_CHECKS ",JSON.stringify(report))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
