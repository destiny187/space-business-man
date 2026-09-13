extends RefCounted
## Generic skin-weight bounds. No species list or assumed biped skeleton.
## Geometry is read once per loaded mesh; firing reads only bone transforms.
static var actors: Dictionary={}
static var geometry: Dictionary={}
static var jobs: Dictionary={}
static func register(id: String,actor: Node3D) -> void:
	_poll();actors[id]=weakref(actor)
static func unregister(id: String,actor: Node3D) -> void:
	if actors.has(id) and actors[id].get_ref()==actor:actors.erase(id)
	if actors.is_empty():
		for job in jobs.values():WorkerThreadPool.wait_for_task_completion(job.task)
		jobs.clear()
static func shapes(id: String) -> Array:
	_poll()
	if not actors.has(id):return []
	var actor: Node3D=actors[id].get_ref()
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():actors.erase(id);return []
	if actor.models.is_empty():return []
	var result: Array=[]
	# Near and far share the rig. Use one model to avoid double damage volumes.
	var model: Node3D=actor.models[0]
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:continue
		var skeleton: Skeleton3D=mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if skeleton==null or mesh.skin==null:
			result.append({"transform":mesh.global_transform,"bounds":mesh.mesh.get_aabb(),"zone":"body","weak":false});continue
		var key:=str(mesh.mesh.get_instance_id())+":"+str(mesh.skin.get_instance_id())
		if not geometry.has(key):
			if jobs.is_empty():
				var job:=_pack(mesh,skeleton);jobs[key]=job
				job.task=WorkerThreadPool.add_task(func():job.result=_build_packets(job.arrays,job.binds),false,"Firearm anatomy bounds")
			return []
		for part in geometry[key]:
			result.append({"transform":skeleton.global_transform*skeleton.get_bone_global_pose(part.bone),"bounds":part.bounds,"zone":part.zone,"weak":part.zone=="head"})
	return result
static func _poll() -> void:
	for key in jobs.keys():
		var job: Dictionary=jobs[key]
		if not WorkerThreadPool.is_task_completed(job.task):continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		if geometry.size()>=128:geometry.erase(geometry.keys()[0])
		geometry[key]=job.result;jobs.erase(key)
static func _pack(mesh: MeshInstance3D,skeleton: Skeleton3D) -> Dictionary:
	var arrays: Array=[];var binds: Array=[]
	# Access renderer resources and skeleton names on the main thread only.
	for surface in mesh.mesh.get_surface_count():arrays.append(mesh.mesh.surface_get_arrays(surface))
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if not mesh.skin.get_bind_name(bind).is_empty():bone=skeleton.find_bone(mesh.skin.get_bind_name(bind))
		binds.append({"bone":bone,"pose":mesh.skin.get_bind_pose(bind),"name":skeleton.get_bone_name(bone).to_lower() if bone>=0 else ""})
	return {"arrays":arrays,"binds":binds,"result":[]}
static func _build(mesh: MeshInstance3D,skeleton: Skeleton3D) -> Array:
	var packet:=_pack(mesh,skeleton)
	return _build_packets(packet.arrays,packet.binds)
static func _build_packets(surfaces: Array,binds: Array) -> Array:
	# Worker owns plain value arrays. No Nodes, meshes or shared-world writes.
	var boxes: Dictionary={};var names: Dictionary={}
	for arrays in surfaces:
		if arrays[Mesh.ARRAY_BONES]==null or arrays[Mesh.ARRAY_WEIGHTS]==null:continue
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var joints: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty():continue
		var stride:=joints.size()/vertices.size()
		for index in vertices.size():
			for slot in int(stride):
				var offset:=index*int(stride)+slot
				if weights[offset]<.20:continue
				var bind:=joints[offset]
				if bind>=binds.size() or int(binds[bind].bone)<0:continue
				var bone:=int(binds[bind].bone)
				var point: Vector3=binds[bind].pose*vertices[index]
				boxes[bone]=boxes[bone].expand(point) if boxes.has(bone) else AABB(point,Vector3.ZERO)
				names[bone]=binds[bind].name
	var result: Array=[]
	for bone in boxes:
		var name: String=names[bone];var zone:="body"
		for word in ["head","skull","jaw","cranium"]:
			if word in name:zone="head";break
		if zone=="body":
			for word in ["leg","arm","foot","hand","wing","claw","tentacle","tail"]:
				if word in name:zone="limb";break
		result.append({"bone":bone,"bounds":boxes[bone].grow(.008),"zone":zone})
	return result
