extends Node3D
## Visual case only. State is supplied externally; no ecology/save ownership here.
const Ink = preload("res://scripts/actors/ink_style.gd")
var definition: Dictionary
var variants: Array[Node3D] = []
var parts: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var state := "walking"
var elapsed := 0.0
var paused := false
var far_lod := false
var lod_override := -1

func _ready() -> void:
	definition = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/lithotherm.json"))
	var cache: Dictionary = {}
	for path in [definition.near_model,definition.far_model]:
		var model: Node3D = load(path).instantiate()
		add_child(model)
		Ink.apply(model,cache)
		variants.append(model)
		var joints: Dictionary = {}
		for n in model.find_children("Anim_*","Node3D",true,false):
			joints[n.name] = {"node":n,"rest":n.transform}
		parts.append(joints)
	for material in cache.values():
		if material.resource_name.contains("thermal") or material.resource_name.contains("sensory"):
			materials.append(material)
	var collision := StaticBody3D.new()
	collision.name = "SpecimenCollision"
	collision.collision_layer = 0
	collision.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .8
	capsule.height = 3.6
	shape.shape = capsule
	shape.position.y = .9
	shape.rotation.x = PI/2
	collision.add_child(shape)
	add_child(collision)
	set_lod(false)
	pose()

func set_state(value: String) -> bool:
	if not definition.states.has(value): return false
	state = value
	elapsed = 0
	pose()
	return true

func set_lod(distant: bool) -> void:
	far_lod = distant
	variants[0].visible = not distant
	variants[1].visible = distant

func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
		pose()
	var camera := get_viewport().get_camera_3d()
	if lod_override >= 0:
		set_lod(lod_override == 1)
	elif camera:
		set_lod(camera.global_position.distance_to(global_position) > float(definition.lod_distance))

func pose() -> void:
	for joints in parts:
		for data in joints.values(): data.node.transform = data.rest
		var body: Node3D = joints.Anim_Body.node
		var head: Node3D = joints.Anim_Head.node
		var jaw: Node3D = joints.Anim_Jaw.node
		var tail: Node3D = joints.Anim_Tail.node
		if state == "dormant":
			body.scale.y = .85+.008*sin(elapsed*.8)
			head.position.z -= .16
			head.rotation.x = -.08
		elif state == "walking":
			body.position.y += .025*abs(sin(elapsed*3.2))
			head.rotation.y = sin(elapsed*.8)*.09
			tail.rotation.y = sin(elapsed*1.6)*.12
			for row in range(3):
				for side in ["L","R"]:
					var leg: Node3D = joints["Anim_Leg_%d_%s"%[row,side]].node
					var phase := elapsed*3.2+row*PI+(0.0 if side=="L" else PI)
					leg.rotation.y = sin(phase)*.18
					leg.position.y += maxf(0,sin(phase))*.13
		elif state == "feeding":
			head.rotation.x = -.17+.065*sin(elapsed*2.8)
			jaw.rotation.x = maxf(0,sin(elapsed*5.6))*.27
			tail.rotation.y = sin(elapsed*.7)*.045
		elif state == "stressed":
			body.scale.y = .93
			head.position.z -= .13
			head.rotation.y = .035*sin(elapsed*8)
			tail.rotation.y = .06*sin(elapsed*6)
	var heat := .22
	if state == "dormant": heat=.015
	elif state == "feeding": heat=.32+.1*sin(elapsed*2.8)
	elif state == "stressed": heat=.55+.3*sin(elapsed*5)
	for material in materials: material.set_shader_parameter("emission_strength",heat)
