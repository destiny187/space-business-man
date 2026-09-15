extends "res://tests/test_solo_entry.gd"
func run() -> void:
	var field:=FrontierTerrainField.new();field.configure(71491)
	var height:=field.height(0,0)
	# A saved legacy world had no seeded cave object, so excavation could cut
	# straight through the promised lower limit.
	field.add_edit({"center":[0,height-200,0],"radius":6.0})
	check(field.density(Vector3(0,height-199,0))<0,"legacy world remains excavatable to 200m")
	check(field.is_bedrock(Vector3(0,height-200,0)) and field.density(Vector3(0,height-201,0))>0,"legacy edit clipped by unbreakable bedrock")
	var before:=field.density(Vector3(0,height-202,0))
	field.add_edit({"center":[1,height-202,0],"radius":8.0})
	check(field.density(Vector3(0,height-202,0))==before,"overlapping side excavation cannot cut bedrock")
	var settings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"));settings.minimum_depth=-72
	var terrain:=FrontierTerrainStreamer.new();terrain.configure(71491,[],null,settings)
	check(terrain.chunk_in_bounds(Vector3i(0,-9,0)),"old -72m streaming bounds include 200m bedrock")
	var at:=Vector3(0,height-197,0)
	var safe:=field.safe_motion(at,at-Vector3.UP*8)
	check(safe.y>=height-200-.13 and safe.y<at.y,"fast falling feet stop at density floor even without collider")
	var geometry:=FrontierTerrainMesher.new().build(field,field.key_at(Vector3(0,height-200,0)))
	check(not geometry.collision_faces.is_empty(),"excavated bedrock produces physical collision triangles")
	# Boundary and ordinary terrain: no edit changes outside the local footprint.
	var flat:=FrontierTerrainField.new();flat.configure(71491)
	check(flat.safe_motion(Vector3(0,5,0),Vector3(0,-5,0)).y>=1.8,"missing surface collision does not allow a fall through the map")
	check(flat.safe_motion(Vector3(0,5,0),Vector3(2,5,0)).is_equal_approx(Vector3(2,5,0)),"clear movement remains unchanged")
	var capsule:=CharacterBody3D.new();root.add_child(capsule)
	var shape:=CollisionShape3D.new();shape.shape=CapsuleShape3D.new();shape.position.y=1;capsule.add_child(shape)
	capsule.position=Vector3(1,height-196,1);capsule.velocity=Vector3(0,-50,0)
	var motion:=FrontierCrewLocomotion.create()
	for frame in 45:
		await physics_frame
		FrontierCrewLocomotion.step(capsule,motion,Vector2.ZERO,6,14,0,1.0/60.0,true,0,0,1,false,false,field)
	check(capsule.position.y>=height-200-.13 and motion.grounded,"actual falling character settles safely even with missing collision")
	capsule.queue_free()
	terrain.free()
	print("FIELD_SAFETY ",checks," FAILURES ",failures);quit(1 if failures else 0)
