extends RefCounted
## Consolidate only immutable, opaque ore parts. Keep the authored triangles,
## normals, colours and materials; the containing body still owns collision.
static func apply(root: Node3D,cache: Dictionary,key: String) -> bool:
	var parts:=root.find_children("*","MeshInstance3D",true,false)
	if parts.size()<2:return false
	if not cache.has(key):cache[key]=_build(root,parts)
	var merged: ArrayMesh=cache[key]
	if merged==null:return false
	var first: MeshInstance3D=parts[0]
	var visual:=MeshInstance3D.new();visual.name="BatchedMineral"
	visual.mesh=merged;visual.layers=first.layers;visual.cast_shadow=first.cast_shadow
	for part in parts:
		part.mesh=null;part.hide()
	root.add_child(visual)
	return true

static func _build(root: Node3D,parts: Array[Node]) -> ArrayMesh:
	if not root.find_children("*","AnimationPlayer",true,false).is_empty():return null
	var groups: Dictionary={}
	var first: MeshInstance3D=parts[0]
	var count:=0
	for part: MeshInstance3D in parts:
		if not part.mesh is ArrayMesh or part.mesh.get_blend_shape_count()>0 or part.skin!=null:return null
		if part.layers!=first.layers or part.cast_shadow!=first.cast_shadow:return null
		if part.visibility_range_begin!=0 or part.visibility_range_end!=0 or part.material_overlay!=null:return null
		var relative:=Transform3D.IDENTITY
		var parent: Node=part
		while parent!=root:
			if not parent is Node3D or not parent.visible or str(parent.name).begins_with("Anim_"):return null
			relative=parent.transform*relative;parent=parent.get_parent()
		if relative.basis.determinant()<=0:return null
		for surface in part.mesh.get_surface_count():
			if part.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:return null
			var material: Material=part.get_active_material(surface)
			if not material is ShaderMaterial or material.shader!=FrontierInkStyle.CEL:return null
			for flag in ["presence_foliage","presence_grounded","space_lighting"]:
				if material.get_shader_parameter(flag):return null
			if not groups.has(material):groups[material]=[]
			groups[material].append({"mesh":part.mesh,"surface":surface,"transform":relative});count+=1
	if groups.size()>=count:return null
	var merged:=ArrayMesh.new()
	for material in groups:
		var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES);builder.set_material(material)
		for row in groups[material]:builder.append_from(row.mesh,row.surface,row.transform)
		builder.commit(merged)
	return merged
