class_name FrontierCrewStation
extends Node3D
## A03 physical access point; processing/result choreography follows in A04/A06.
var kind: String
var model: Node3D
var socket: Node3D
var elapsed:=0.0
var scan: Node3D
var tray: Node3D
var rotor: Node3D
var arm: Node3D
var origins: Dictionary={}
func configure(value: String,definition: Dictionary) -> void:
	kind=value;name="Station_"+kind
	model=load("res://assets/models/"+str(definition.model)+".glb").instantiate();add_child(model);FrontierInkStyle.apply(model,{})
	socket=model.find_child("Socket_Interaction",true,false)
	scan=model.find_child("Anim_ScanHead",true,false);tray=model.find_child("Anim_GemTray",true,false)
	rotor=model.find_child("Anim_SpecimenTurntable",true,false);arm=model.find_child("Anim_OpticalArm",true,false)
	for node in [scan,tray,rotor,arm]:
		if node!=null:origins[node]=node.transform
	if kind=="augmentation":
		collider(Vector3(0,.23,0),Vector3(1.65,.30,1.30))
		for x in [-.69,.69]:collider(Vector3(x,1.45,-.16),Vector3(.32,2.08,.60))
		collider(Vector3(.95,.84,-.14),Vector3(.44,1.22,.68))
		collider(Vector3(0,2.43,-.18),Vector3(1.65,.30,.56))
	else:
		collider(Vector3(0,.68,0),Vector3(1.86,1.24,1.15))
		collider(Vector3(-.50,1.60,-.16),Vector3(.58,.70,.65))
	set_process(false)
func collider(at: Vector3,size: Vector3) -> void:
	var body:=StaticBody3D.new();add_child(body)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;collision.position=at;body.add_child(collision)
func interaction_point() -> Vector3:return socket.global_position if is_instance_valid(socket) else global_position+Vector3.UP*1.3
func present(delta: float,active: bool) -> void:
	elapsed+=delta
	if scan!=null:scan.position=origins[scan].origin+Vector3(0,-(.16+.16*sin(elapsed*2)) if active else 0,0)
	if tray!=null:tray.position=origins[tray].origin+Vector3(0,0,.08 if active else 0)
	if rotor!=null:rotor.rotation.y=elapsed*.35 if active else 0
	if arm!=null:arm.rotation.x=.05*sin(elapsed*1.8) if active else 0
