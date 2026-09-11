extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func settle(view: FrontierDistantTerrain) -> bool:
	var deadline:=Time.get_ticks_msec()+15000
	while view.fallback_task!=-1 or not view.fallback_queue.is_empty() or view.task_id!=-1:
		if Time.get_ticks_msec()>deadline:return false
		await process_frame
	return true
func same(a: FrontierDistantTerrain,b: FrontierDistantTerrain) -> bool:
	var left: Mesh=a.get_node("StreamingFallback").mesh
	var right: Mesh=b.get_node("StreamingFallback").mesh
	if left==null or right==null:return left==right
	return left.surface_get_arrays(0)==right.surface_get_arrays(0)
func run() -> void:
	var field:=FrontierTerrainField.new();field.configure(71491)
	var live:=FrontierDistantTerrain.new();root.add_child(live)
	var reference:=FrontierDistantTerrain.new();root.add_child(reference)
	live.request_fallback(field,Vector3i.ZERO,2,{})
	reference.rebuild_fallback(field,Vector3i.ZERO,2,{})
	check(await settle(live) and same(live,reference),"worker coverage equals synchronous vertices normals and indices")
	var mesh: Mesh=live.get_node("StreamingFallback").mesh
	live.request_fallback(field,Vector3i.ZERO,2,{})
	check(await settle(live) and live.get_node("StreamingFallback").mesh==mesh,"unchanged coverage preserves the uploaded mesh")
	var loaded: Dictionary={}
	for x in range(-4,5):
		for y in range(-6,7):
			for z in range(-4,5):loaded[Vector3i(x,y,z)]=true
	live.request_fallback(field,Vector3i.ZERO,2,loaded)
	check(await settle(live) and live.get_node("StreamingFallback").mesh==null,"completed fine terrain removes temporary coverage")
	live.request_fallback(field,Vector3i.ZERO,2,{})
	field.add_edit({"center":[0,2,0],"radius":7})
	live.request_fallback(field,Vector3i.ZERO,2,{})
	reference.rebuild_fallback(field,Vector3i.ZERO,2,{})
	check(await settle(live) and same(live,reference),"new excavation wins over an in-flight stale coverage request")
	var material:=StandardMaterial3D.new()
	live.request_rebuild(field,Vector3i.ZERO,2,material,160)
	live.request_rebuild(field,Vector3i(3,0,-2),2,material,160)
	live.request_fallback(field,Vector3i(3,0,-2),2,{})
	check(await settle(live) and live.rendered_anchor==Vector3i(3,0,-2),"coalesced near ring commits with the latest coverage")
	live.queue_free();reference.queue_free();await process_frame
	quit(1 if failures else 0)
