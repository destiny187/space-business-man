extends RefCounted
## One compound triangle surface per installed landed hull. Empty space under
## wings stays walkable; no large bounding box seals the whole vessel footprint.
static func install(ship: Node3D) -> StaticBody3D:
	var previous:=ship.get_node_or_null("GroundHullCollision")
	if previous!=null:
		ship.remove_child(previous);previous.queue_free()
	var faces:=PackedVector3Array()
	for mesh in ship.find_children("*","MeshInstance3D",true,false):
		if not mesh.visible or mesh.mesh==null:continue
		# Drive particles, transparent plume meshes and helper models are not hull.
		var parent: Node=mesh
		var excluded:=false
		while parent!=ship:
			if parent is FrontierVesselDriveEffects or parent is GPUParticles3D:excluded=true;break
			parent=parent.get_parent()
		if excluded:continue
		var transform: Transform3D=ship.global_transform.affine_inverse()*mesh.global_transform
		var triangles: PackedVector3Array=mesh.mesh.get_faces()
		for i in range(0,triangles.size(),3):
			var a: Vector3=transform*triangles[i]
			var b: Vector3=transform*triangles[i+1]
			var c: Vector3=transform*triangles[i+2]
			if (b-a).cross(c-a).length_squared()>.00000001:faces.append_array(PackedVector3Array([a,b,c]))
	var body:=StaticBody3D.new();body.name="GroundHullCollision";body.set_meta("vessel_attachment",true)
	body.set_meta("landed_vessel",true)
	var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces);collision.shape=shape
	body.add_child(collision);ship.add_child(body)
	return body
