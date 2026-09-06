class_name FrontierDistantTerrain
extends MeshInstance3D
## Shared square rings keep the innermost edge on the fine grid; no far collision.
func rebuild(field: FrontierTerrainField,anchor: Vector3i,radius_chunks: int,terrain_material: Material,view_distance: float=1060.0) -> void:
	var center:=Vector3((anchor.x+.5)*field.span,0,(anchor.z+.5)*field.span)
	var inner: float=(radius_chunks+.5)*field.span
	var rings: Array[float]=[inner,inner+8,inner+30,inner+80,inner+160]
	var radius_cursor: float=inner+320
	while radius_cursor<view_distance:
		rings.append(radius_cursor);radius_cursor*=1.55
	rings.append(maxf(view_distance,rings[-1]+1))
	var per_side:=int(inner)
	var perimeter:=per_side*4
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var indices:=PackedInt32Array()
	for radius in rings:
		for side in 4:
			for i in per_side:
				var t: float=float(i)/per_side
				var p: Vector3=[Vector3(lerpf(-radius,radius,t),0,-radius),Vector3(radius,0,lerpf(-radius,radius,t)),Vector3(lerpf(radius,-radius,t),0,radius),Vector3(-radius,0,lerpf(radius,-radius,t))][side]+center
				p.y=field.height(p.x,p.z)
				vertices.append(p)
				var dx: float=field.height(p.x+.2,p.z)-field.height(p.x-.2,p.z)
				var dz: float=field.height(p.x,p.z+.2)-field.height(p.x,p.z-.2)
				normals.append(Vector3(-dx,.4,-dz).normalized())
	for ring in range(rings.size()-1):
		for i in perimeter:
			var a:=ring*perimeter+i
			var b:=ring*perimeter+(i+1)%perimeter
			var c:=b+perimeter
			var d:=a+perimeter
			for triangle in [[a,b,c],[a,c,d]]:
				var pa: Vector3=vertices[triangle[0]]
				var pb: Vector3=vertices[triangle[1]]
				var pc: Vector3=vertices[triangle[2]]
				# Test the actual surface, not a chord above a valley. Chord tests
				# incorrectly removed distant terrain on almost every rough slope.
				var probe: Vector3=(pa+pb+pc)/3.0
				probe.y=field.height(probe.x,probe.z)-.5
				if ring==0 and field.density(probe)<0:continue
				if (pb-pa).cross(pc-pa).y>0:triangle.reverse()
				indices.append_array(PackedInt32Array(triangle))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var result:=ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh=result
	material_override=terrain_material

## Temporary surface tiles cover not-yet-built fine chunks, then disappear.
## No collision and no edits: the authoritative streamer still owns both.
func rebuild_fallback(field: FrontierTerrainField,anchor: Vector3i,radius_chunks: int,chunks: Dictionary) -> void:
	var fallback:=get_node_or_null("StreamingFallback") as MeshInstance3D
	if fallback==null:
		fallback=MeshInstance3D.new();fallback.name="StreamingFallback";add_child(fallback)
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
	var low:=Vector2((anchor.x-radius_chunks)*field.span,(anchor.z-radius_chunks)*field.span)
	var cells:=int((radius_chunks*2+1)*field.span/4)
	for x in cells:
		for z in cells:
			var origin:=Vector3(low.x+x*4,0,low.y+z*4)
			var probe:=origin+Vector3(2,0,2);probe.y=field.height(probe.x,probe.z)
			if chunks.has(field.key_at(probe)) and chunks.has(field.key_at(probe-Vector3.UP*2)):continue
			if field.density(probe-Vector3.UP*.5)<0:continue
			var start:=vertices.size()
			for offset in [Vector3.ZERO,Vector3(4,0,0),Vector3(4,0,4),Vector3(0,0,4)]:
				var p: Vector3=origin+offset;p.y=field.height(p.x,p.z)-.15;vertices.append(p);normals.append(Vector3.UP)
			indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	if vertices.is_empty():fallback.mesh=null;return
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	fallback.mesh=result;fallback.material_override=material_override
