class_name FrontierDistantTerrain
extends MeshInstance3D
## Shared square rings keep the innermost edge on the fine grid; no far collision.
func rebuild(field: FrontierTerrainField,anchor: Vector3i,radius_chunks: int,terrain_material: Material) -> void:
	var center:=Vector3((anchor.x+.5)*field.span,0,(anchor.z+.5)*field.span)
	var inner: float=(radius_chunks+.5)*field.span
	var rings: Array[float]=[inner,inner+30,inner+80,inner+160,inner+320,inner+580,inner+1000]
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
				# Keep large cave mouths open in the distant representation.
				if field.density((pa+pb+pc)/3.0-Vector3.UP*.5)<0:continue
				if (pb-pa).cross(pc-pa).y>0:triangle.reverse()
				indices.append_array(PackedInt32Array(triangle))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var result:=ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh=result
	material_override=terrain_material
