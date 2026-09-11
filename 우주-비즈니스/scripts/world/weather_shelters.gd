class_name FrontierWeatherShelters
extends RefCounted
static func box(root: Node3D,size: Vector3,point: Vector3) -> void:
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;collision.position=point;root.add_child(collision)
static func collision(root: Node3D,model: String) -> void:
	if model=="field_canopy":
		for x in [-2.65,2.65]:
			for z in [-1.95,1.95]:
				box(root,Vector3(.26,3.1,.26),Vector3(x,1.55,z));box(root,Vector3(.65,.20,.65),Vector3(x,.10,z))
		box(root,Vector3(5.75,.30,4.68),Vector3(0,3.23,0))
	elif model=="grounding_mast":
		box(root,Vector3(.45,5,.45),Vector3(0,2.5,0));box(root,Vector3(1.5,.3,1.5),Vector3(0,.15,0))
