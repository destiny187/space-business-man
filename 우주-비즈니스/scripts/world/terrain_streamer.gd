class_name FrontierTerrainStreamer
extends Node3D
## Worker jobs produce CPU arrays. Main-thread swaps keep mesh and collision paired.
signal geometry_changed
var config: Dictionary
var field := FrontierTerrainField.new()
var chunks: Dictionary = {}
var wanted: Dictionary = {}
var jobs: Dictionary = {}
var revisions: Dictionary = {}
var batch: Dictionary = {}
var staged: Dictionary = {}
var prepared: Dictionary = {}
var ordered_candidates: Array=[]
var candidates_dirty:=true
const INSTALL_BUDGET_USEC:=3000
var material: Material
var seed_number := 0
var span := 24.0
var interest_signature := ""
var completed_jobs := 0
var max_build_ms := 0.0
var last_install_ms := 0.0
var closed := false

func configure(seed_value: int,edits: Array,terrain_material: Material,settings: Dictionary={},traits: Dictionary={}) -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json")) if settings.is_empty() else settings.duplicate(true)
	seed_number=seed_value
	span=float(config.cell_size)*int(config.chunk_cells)
	material=terrain_material
	field.configure(seed_number,edits,span,traits)

func update_interests(points: Array[Vector3]) -> void:
	var anchors: Array[Vector3i]=[]
	for point in points:
		var key:=field.key_at(point)
		if key not in anchors:anchors.append(key)
	var signature:=str(anchors)
	if signature==interest_signature:return
	interest_signature=signature
	candidates_dirty=true
	wanted.clear()
	var radius:=int(config.active_radius)
	for anchor in anchors:
		for x in range(anchor.x-radius,anchor.x+radius+1):
			for z in range(anchor.z-radius,anchor.z+radius+1):
				for y in range(anchor.y-int(config.vertical_radius),anchor.y+int(config.vertical_radius)+1):
					if y*span<float(config.minimum_depth) or y*span>float(config.maximum_height):continue
					var key:=Vector3i(x,y,z)
					var priority: float=Vector3(key-anchor).length_squared()
					wanted[key]=minf(priority,float(wanted.get(key,INF)))
	for key in chunks.keys():
		if not wanted.has(key):
			remove_child(chunks[key].node)
			chunks[key].node.queue_free()
			chunks.erase(key)

func dig(center: Vector3,radius: float) -> Dictionary:
	if not batch.is_empty():return {}
	var edit: Dictionary={"center":[center.x,center.y,center.z],"radius":radius}
	candidates_dirty=true
	var affected: Array[Vector3i]=field.add_edit(edit)
	for key in affected:
		revisions[key]=int(revisions.get(key,0))+1
		if wanted.has(key):batch[key]=true
	return edit

func ready_at(point: Vector3) -> bool:
	var key:=field.key_at(point)
	# Player capsule and its floor can occupy opposite sides of a chunk boundary.
	return chunks.has(key) and chunks.has(field.key_at(point-Vector3.UP*2))

func ready_for(points: Array[Vector3]) -> bool:
	if config.is_empty():return false
	var radius:=int(config.active_radius)
	for point in points:
		var anchor:=field.key_at(point)
		for x in range(anchor.x-radius,anchor.x+radius+1):
			for z in range(anchor.z-radius,anchor.z+radius+1):
				for y in range(anchor.y-int(config.vertical_radius),anchor.y+int(config.vertical_radius)+1):
					if y*span<float(config.minimum_depth) or y*span>float(config.maximum_height):continue
					var key:=Vector3i(x,y,z)
					if not chunks.has(key) or int(chunks[key].revision)!=int(revisions.get(key,0)):return false
	return batch.is_empty()

func _process(_delta: float) -> void:
	if closed or config.is_empty():return
	if jobs.is_empty() and batch.is_empty() and not candidates_dirty and chunks.size()==wanted.size():return
	var deadline:=Time.get_ticks_usec()+INSTALL_BUDGET_USEC
	for key in jobs.keys():
		if Time.get_ticks_usec()>=deadline:break
		var job: Dictionary=jobs[key]
		if not WorkerThreadPool.is_task_completed(job.task):continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		jobs.erase(key)
		if not wanted.has(key) or int(job.revision)!=int(revisions.get(key,0)):continue
		completed_jobs+=1
		var data: Dictionary=job.packet.data
		max_build_ms=maxf(max_build_ms,float(data.build_ms))
		if batch.has(key):staged[key]=data
		else:_install(key,data)
	if not batch.is_empty():
		var complete:=true
		for key in batch:
			if wanted.has(key) and not staged.has(key):complete=false
		if complete:
			# Prepare expensive meshes and collision shapes over several frames.
			# Keep the old batch visible/solid until every replacement is ready.
			for key in staged:
				if wanted.has(key) and not prepared.has(key):
					if Time.get_ticks_usec()>=deadline:complete=false;break
					prepared[key]=_prepare(key,staged[key])
			if complete:
				for key in prepared:
					if wanted.has(key):_commit(key,staged[key],prepared[key])
					else:prepared[key].free()
				batch.clear();staged.clear();prepared.clear();candidates_dirty=true
				geometry_changed.emit()
	if candidates_dirty:
		ordered_candidates=wanted.keys()
		ordered_candidates.sort_custom(func(a: Vector3i,b: Vector3i) -> bool:
			if batch.has(a)!=batch.has(b):return batch.has(a)
			return wanted[a]<wanted[b])
		candidates_dirty=false
	for key in ordered_candidates:
		if jobs.size()>=int(config.worker_limit):break
		if jobs.has(key) or staged.has(key):continue
		if chunks.has(key) and chunks[key].revision==int(revisions.get(key,0)):continue
		var packet: Dictionary={"data":{}}
		var local_edits: Array=field.edits_by_chunk.get(key,[]).duplicate(true)
		var task_id:=WorkerThreadPool.add_task(_build_job.bind(packet,key,local_edits),false,"terrain %s" % key)
		jobs[key]={"task":task_id,"packet":packet,"revision":int(revisions.get(key,0))}

func _build_job(packet: Dictionary,key: Vector3i,edits: Array) -> void:
	var worker_field:=FrontierTerrainField.new()
	worker_field.configure(seed_number,edits,span,field.traits)
	var mesher:=FrontierTerrainMesher.new()
	packet.data=mesher.build(worker_field,key,int(config.chunk_cells),float(config.cell_size))

func _install(key: Vector3i,data: Dictionary) -> void:
	var start:=Time.get_ticks_usec()
	var node:=_prepare(key,data)
	_commit(key,data,node)
	last_install_ms=(Time.get_ticks_usec()-start)/1000.0

func _prepare(key: Vector3i,data: Dictionary) -> Node3D:
	var node:=Node3D.new()
	var mesh:=FrontierTerrainMesher.mesh(data)
	if mesh.get_surface_count()>0:
		var visual:=MeshInstance3D.new()
		visual.mesh=mesh
		visual.material_override=material
		node.add_child(visual)
		var body:=StaticBody3D.new()
		body.set_meta("terrain_chunk",key)
		var collision:=CollisionShape3D.new()
		collision.shape=mesh.create_trimesh_shape()
		body.add_child(collision)
		node.add_child(body)
	return node

func _commit(key: Vector3i,data: Dictionary,node: Node3D) -> void:
	node.position=Vector3(key)*span
	node.name="Chunk_%d_%d_%d" % [key.x,key.y,key.z]
	if chunks.has(key):
		remove_child(chunks[key].node)
		chunks[key].node.queue_free()
	add_child(node)
	chunks[key]={"node":node,"revision":int(revisions.get(key,0)),"triangles":data.indices.size()/3}

func _exit_tree() -> void:
	closed=true
	for job in jobs.values():WorkerThreadPool.wait_for_task_completion(job.task)
	jobs.clear()
	for node in prepared.values():node.free()
	prepared.clear()
