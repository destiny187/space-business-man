extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: "+message)
func run() -> void:
	var field:=FrontierTerrainField.new()
	field.configure(71491)
	check(field.density(Vector3(0,12,0))<0 and field.density(Vector3(0,-10,0))>0,"surface separates air and rock")
	var connected:=true
	for i in 83:
		var t: float=float(i)/82
		var point:=Vector3(14+t*82,7.4-t*27.4,sin(t*PI)*5)
		connected=connected and field.density(point)<-4
	check(connected,"continuous inclined path links surface and chamber")
	var covered:=true
	for x in range(40,91,2):
		var t: float=float(x-14)/82
		covered=covered and field.density(Vector3(x,7.4-t*27.4+9,sin(t*PI)*5))>0
	check(covered,"buried passage retains overburden instead of becoming an exterior valley")
	var mesher:=FrontierTerrainMesher.new()
	var start:=Time.get_ticks_usec()
	var left: Dictionary=mesher.build(field,Vector3i(0,0,0))
	var right: Dictionary=FrontierTerrainMesher.new().build(field,Vector3i(1,0,0))
	check(not left.indices.is_empty(),"surface and entrance generate actual triangles")
	var valid:=true
	for normal in left.normals:valid=valid and normal.is_finite() and absf(normal.length()-1)<.01
	for i in range(0,left.indices.size(),3):
		var a: Vector3=left.vertices[left.indices[i]]
		var b: Vector3=left.vertices[left.indices[i+1]]
		var c: Vector3=left.vertices[left.indices[i+2]]
		var n: Vector3=left.normals[left.indices[i]]+left.normals[left.indices[i+1]]+left.normals[left.indices[i+2]]
		valid=valid and (b-a).cross(c-a).dot(n)<=.001
	check(valid,"finite outward normals and clockwise front faces")
	var boundary_left: Dictionary={}
	var boundary_right: Dictionary={}
	for point in left.vertices:
		if absf(point.x-24)<.0001:boundary_left["%.4f:%.4f" % [point.y,point.z]]=true
	for point in right.vertices:
		if absf(point.x)<.0001:boundary_right["%.4f:%.4f" % [point.y,point.z]]=true
	check(not boundary_left.is_empty() and boundary_left==boundary_right,"adjacent chunks agree on surface boundary")
	var edit: Dictionary={"center":[24,1,12],"radius":3.2}
	var before: float=field.density(Vector3(24,1,12))
	var affected:=field.add_edit(edit)
	check(affected.has(Vector3i(0,0,0)) and affected.has(Vector3i(1,0,0)),"border dig invalidates both neighbours")
	check(before>0 and field.density(Vector3(24,1,12))<0,"dig removes previously solid material")
	var restored:=FrontierTerrainField.new()
	restored.configure(71491,JSON.parse_string(JSON.stringify([edit])))
	check(is_equal_approx(restored.density(Vector3(24,1,12)),field.density(Vector3(24,1,12))),"carved volume survives serialized edit replay")
	var after: Dictionary=FrontierTerrainMesher.new().build(field,Vector3i(0,0,0))
	check(after.vertices!=left.vertices,"dig changes generated surface")
	var mesh:=FrontierTerrainMesher.mesh(after)
	check(mesh.get_surface_count()==1 and mesh.create_trimesh_shape()!=null,"render mesh creates matching collision shape")
	var world:=FrontierUniverse.new_world(71491)
	world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
	world.terrain_settings_hash=FrontierUniverse.fingerprint(world.terrain_settings)
	world.mode="surface";world.surface_positions={world.location:[0,4,0]}
	world.terrain_edits={world.location:[edit]}
	check(FrontierUniverse.validate_world(world).is_empty(),"valid surface save pins generator settings and edits")
	for invalid in [{"center":[0,0],"radius":3},{"center":[0,0,0],"radius":-1},{"center":[0,INF,0],"radius":3}]:
		var bad:=world.duplicate(true);bad.terrain_edits[bad.location]=[invalid]
		check(not FrontierUniverse.validate_world(bad).is_empty(),"malformed carve is rejected before restore")
	var outside:=world.duplicate(true);outside.surface_positions[outside.location]=[90000,4,0]
	check(not FrontierUniverse.validate_world(outside).is_empty(),"out-of-region saved player cannot strand streaming")
	var unsupported:=world.duplicate(true);unsupported.terrain_settings.generator_version="future"
	unsupported.terrain_settings_hash=FrontierUniverse.fingerprint(unsupported.terrain_settings)
	check(not FrontierUniverse.validate_world(unsupported).is_empty(),"unknown terrain version preserves original save")
	var missing:=world.duplicate(true);missing.erase("terrain_settings")
	check(not FrontierUniverse.validate_world(missing).is_empty(),"surface delta requires pinned generator")
	var stream:=FrontierTerrainStreamer.new()
	stream.configure(71491,[],StandardMaterial3D.new())
	stream.update_interests([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
	check(stream.wanted.size()==75,"overlapping six interest regions share chunks")
	stream.update_interests([Vector3.ZERO,Vector3(1000,0,0),Vector3(2000,0,0),Vector3(3000,0,0),Vector3(4000,0,0),Vector3(5000,0,0)])
	check(stream.wanted.size()==450 and stream.jobs.is_empty(),"six separated interests remain bounded and defer generation")
	stream.free()
	print("TERRAIN_BUILD_MS ",(Time.get_ticks_usec()-start)/1000.0," vertices=",left.vertices.size()," triangles=",left.indices.size()/3)
	print("TERRAIN_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
