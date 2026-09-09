class_name FrontierFieldVisibility
extends RefCounted
## Local presentation only. Never disable physics, authority, audio or replication.
const VIEWPORT_USERS := &"field_occlusion_users"
const VIEWPORT_PREVIOUS := &"field_occlusion_previous"

static func acquire(viewport: Viewport) -> bool:
	if DisplayServer.get_name()=="headless":return false
	if viewport is SubViewport and viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED:return false
	var users: int=viewport.get_meta(VIEWPORT_USERS,0)
	if users==0:viewport.set_meta(VIEWPORT_PREVIOUS,viewport.use_occlusion_culling)
	viewport.set_meta(VIEWPORT_USERS,users+1)
	viewport.use_occlusion_culling=true
	return true

static func release(viewport: Viewport) -> void:
	var users: int=maxi(0,int(viewport.get_meta(VIEWPORT_USERS,1))-1)
	viewport.set_meta(VIEWPORT_USERS,users)
	if users==0:viewport.use_occlusion_culling=viewport.get_meta(VIEWPORT_PREVIOUS,false)

static func watch(root: Node3D,margin: float=1.0) -> VisibleOnScreenNotifier3D:
	var notifier:=VisibleOnScreenNotifier3D.new()
	notifier.name="FieldVisibility"
	root.add_child(notifier)
	fit(root,notifier,margin)
	return notifier

static func fit(root: Node3D,notifier: VisibleOnScreenNotifier3D,margin: float=1.0) -> void:
	var bounds:=AABB()
	var first:=true
	for node in root.find_children("*","GeometryInstance3D",true,false):
		var box: AABB=(root.global_transform.affine_inverse()*node.global_transform)*node.get_aabb()
		bounds=box if first else bounds.merge(box)
		first=false
	# Include articulated movement and shader displacement; do not hide the model
	# itself when this notifier exits, which would prevent it from entering again.
	notifier.aabb=bounds.grow(margin)

static func active(notifier: VisibleOnScreenNotifier3D) -> bool:
	if not is_instance_valid(notifier):return true
	var viewport:=notifier.get_viewport()
	if viewport.disable_3d or not notifier.is_visible_in_tree():return false
	if viewport is SubViewport and viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED:return false
	return notifier.is_on_screen()

static func terrain_occluder(vertices: PackedVector3Array,indices: PackedInt32Array) -> OccluderInstance3D:
	var shape:=ArrayOccluder3D.new()
	shape.set_arrays(vertices,indices)
	var instance:=OccluderInstance3D.new()
	instance.name="TerrainOccluder"
	instance.occluder=shape
	return instance

static func static_model_shape(model: Node3D) -> ArrayOccluder3D:
	var arrays: Dictionary={"vertices":PackedVector3Array(),"indices":PackedInt32Array()}
	_collect_static(model,Transform3D.IDENTITY,arrays)
	if arrays.indices.is_empty():return null
	var shape:=ArrayOccluder3D.new()
	shape.set_arrays(arrays.vertices,arrays.indices)
	return shape

static func _collect_static(node: Node3D,parent_transform: Transform3D,arrays: Dictionary) -> void:
	# Doors, fans and other articulated branches must never seal an opening.
	if node.name.begins_with("Anim_") or node.name.begins_with("FX_") or not node.visible:return
	var transform_value:=parent_transform*node.transform
	if node is MeshInstance3D and node.mesh!=null and node.mesh.get_aabb().get_longest_axis_size()>=2.0:
		for surface in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(surface)
			var opaque: bool=material is ShaderMaterial and material.shader==FrontierInkStyle.CEL
			if material is StandardMaterial3D:opaque=material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED
			if not opaque or node.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:continue
			var source: Array=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=source[Mesh.ARRAY_VERTEX]
			var triangles: PackedInt32Array=source[Mesh.ARRAY_INDEX] if source[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var offset: int=arrays.vertices.size()
			for point in vertices:arrays.vertices.append(transform_value*point)
			if triangles.is_empty():
				for i in vertices.size():arrays.indices.append(offset+i)
			else:
				for i in triangles:arrays.indices.append(offset+i)
	for child in node.get_children():
		if child is Node3D:_collect_static(child,transform_value,arrays)
