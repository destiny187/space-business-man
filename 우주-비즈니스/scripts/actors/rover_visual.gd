class_name FrontierRoverVisual
extends Node3D
## Shared Blender mechanisms for world, workshop and transport previews.
var model: Node3D
var mechanisms: Dictionary={}
var origins: Dictionary={}
var roll:=0.0
func _ready() -> void:
	model=load("res://assets/models/vehicles/scout_rover.glb").instantiate();add_child(model)
	FrontierInkStyle.apply(model,{})
	for node in model.find_children("*","Node3D",true,false):
		if str(node.name).begins_with("Anim_") or str(node.name).begins_with("Socket_"):mechanisms[str(node.name)]=node;origins[str(node.name)]=node.transform
func socket(key: String) -> Vector3:
	return mechanisms[key].global_position if mechanisms.has(key) else global_position
func pose(distance: float,steer: float,compression: Array,doors: Vector2,cargo: float) -> void:
	roll=fposmod(roll+distance/.70,TAU)
	for i in 4:
		var key: String=["LF","RF","LB","RB"][i]
		var wheel: Node3D=mechanisms["Anim_Wheel_"+key];wheel.rotation.x=-roll
		var pivot: Node3D=mechanisms["Anim_Steer_"+key];pivot.rotation.y=steer if i<2 else 0.0
		var suspension: Node3D=mechanisms["Anim_Suspension_"+key];suspension.position=origins["Anim_Suspension_"+key].origin+Vector3.UP*float(compression[i])
	mechanisms.Anim_Door_L.rotation.y=-doors.x*1.15
	mechanisms.Anim_Door_R.rotation.y=doors.y*1.15
	mechanisms.Anim_CargoLid.rotation.x=cargo*1.1
	mechanisms.Anim_SteeringYoke.rotation.z=-steer
