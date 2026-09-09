extends SceneTree
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
var checks:=0
var failures:=0
var folder:="/tmp/space-field-visibility"
var events: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
	else:print("PASS ",label)
func frames(count: int=12) -> void:
	for i in count:await process_frame
	await RenderingServer.frame_post_draw
func fixture(form: Dictionary,reverse: bool=false) -> Dictionary:
	var viewport:=SubViewport.new();viewport.size=Vector2i(640,480);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var image:=TextureRect.new();image.texture=viewport.get_texture();image.position.x=640 if reverse else 0;root.add_child(image)
	var stage:=Node3D.new();viewport.add_child(stage)
	var light:=DirectionalLight3D.new();stage.add_child(light);light.rotation_degrees=Vector3(-35,-25,0)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,4,-30 if reverse else 22);camera.look_at(Vector3(0,3,-5));camera.current=true
	var stream:=FrontierTerrainStreamer.new();stream.configure(71491,[],StandardMaterial3D.new());stage.add_child(stream);stream.set_process(false)
	var vertices:=PackedVector3Array([Vector3(-40,-20,0),Vector3(40,-20,0),Vector3(-40,40,0),Vector3(40,40,0)])
	var data: Dictionary={"vertices":vertices,"indices":PackedInt32Array([0,2,1,1,2,3]),"normals":PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK]),"revision":0}
	data.collision_faces=FrontierTerrainMesher.collision_faces(data.vertices,data.indices)
	var wall:=stream._prepare_visual(data);stream._prepare_collision(Vector3i.ZERO,data,wall);stream._commit(Vector3i.ZERO,data,wall)
	var actor:=Actor.new();actor.configure(form);actor.lod_override=0;stage.add_child(actor);actor.position=Vector3(-5,0,-14);actor.enable_field_culling()
	var business:=FrontierBusinessSiteView.new();stage.add_child(business);business.configure(stream,{"id":"fixture","seed":1})
	business.prepared_models.thermal=load("res://assets/models/thermal.glb")
	var facility:=business._entity("facility","thermal",Vector3(4,0,-8),2,"building");facility.set_meta("working",true)
	business.prepared_models.miner=load("res://assets/models/miner.glb")
	var robot:=business._entity("robot","miner",Vector3(0,0,-8),.7,"robot");robot.set_meta("destination",Vector3(1,0,-8));robot.set_meta("working",true)
	return {"viewport":viewport,"stage":stage,"camera":camera,"terrain":stream,"actor":actor,"business":business,"facility":facility,"robot":robot,"data":data}
func draw_calls(viewport: Viewport) -> int:
	return viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,480);Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var form: Dictionary={}
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/forms.json")).forms:
		if row.attack!="none" and row.family=="walker":form=row;break
	if form.is_empty():form=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/forms.json")).forms[0]
	var a:=fixture(form);var b:=fixture(form,true)
	await frames(50)
	check(a.terrain.occlusion_enabled and b.terrain.occlusion_enabled,"occlusion enabled per rendered field viewport")
	check(not FrontierFieldVisibility.active(a.actor.visibility_notifier),"terrain hides actor from first camera")
	check(FrontierFieldVisibility.active(b.actor.visibility_notifier),"second independent camera still sees its actor")
	check(not FrontierFieldVisibility.active(a.facility.get_meta("visibility_notifier")),"terrain hides facility motion")
	var hidden_pose: Transform3D=a.actor.joints[0].Anim_Head.node.transform
	var hidden_part: Node3D=a.facility.get_meta("parts")[0]
	var hidden_transform:=hidden_part.transform
	var hidden_clock: float=a.actor.elapsed
	await frames(20)
	check(a.actor.elapsed>hidden_clock and a.actor.joints[0].Anim_Head.node.transform==hidden_pose,"hidden actor advances clock without joint writes")
	check(hidden_part.transform==hidden_transform and a.facility.get_meta("visual_motion")>0,"hidden facility advances phase without part writes")
	check(a.robot.position.x>.5,"hidden robot collision body still follows authoritative destination")
	var query:=PhysicsRayQueryParameters3D.create(Vector3(4,1,-3),Vector3(4,1,-12))
	var hit: Dictionary=a.stage.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit.collider==a.facility,"hidden facility remains collidable and targetable")
	a.actor.attack_cue.connect(func(phase: String):events.append(phase))
	a.actor.set_state("attack");a.actor._process(.6);a.actor._process(.3);a.actor._process(.8)
	check(events==["windup","active","recovery","complete"] and a.actor.state=="idle","hidden attack presentation phases complete in order")
	var culled:=draw_calls(a.viewport)
	await capture("occluded-and-visible")
	a.viewport.use_occlusion_culling=false;await frames(20)
	var unculled:=draw_calls(a.viewport)
	check(unculled>culled,"native occlusion reduces actual model draw calls")
	a.viewport.use_occlusion_culling=true;await frames()
	# Same atomic replacement used by excavated chunks, now with an open passage.
	var empty: Dictionary={"vertices":PackedVector3Array(),"indices":PackedInt32Array(),"normals":PackedVector3Array(),"collision_faces":PackedVector3Array(),"revision":1}
	var replacement: Node3D=a.terrain._prepare_visual(empty);a.terrain._prepare_collision(Vector3i.ZERO,empty,replacement);a.terrain._commit(Vector3i.ZERO,empty,replacement)
	await frames(25)
	check(FrontierFieldVisibility.active(a.actor.visibility_notifier),"opening terrain restores actor visibility")
	check(a.actor.joints[0].Anim_Head.node.transform!=hidden_pose,"returning actor immediately uses current pose")
	check(hidden_part.transform!=hidden_transform,"returning facility resumes current motion")
	await capture("opened")
	a.camera.rotation.y+=PI;await frames()
	check(not FrontierFieldVisibility.active(a.actor.visibility_notifier),"camera turn skips offscreen actor motion")
	a.camera.look_at(Vector3(0,3,-5));await frames()
	check(FrontierFieldVisibility.active(a.actor.visibility_notifier),"camera return reactivates actor without unhiding hacks")
	var far_rest: Transform3D=a.actor.joints[1].Anim_Head.node.transform
	await frames()
	check(a.actor.joints[1].Anim_Head.node.transform==far_rest,"inactive LOD receives no per-frame pose writes")
	print("FIELD DRAW CALLS disabled=",unculled," enabled=",culled)
	FileAccess.open(folder+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"draw_calls_without_occlusion":unculled,"draw_calls_with_occlusion":culled},"  "))
	a.terrain.queue_free();await frames()
	check(not a.viewport.use_occlusion_culling and b.viewport.use_occlusion_culling,"leaving one field restores only its own viewport")
	print("FIELD VISIBILITY checks ",checks," failures ",failures)
	quit(1 if failures else 0)
