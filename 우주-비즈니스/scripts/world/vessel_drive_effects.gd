class_name FrontierVesselDriveEffects
extends Node3D
var jets: Array[GPUParticles3D]=[]
var lights: Array[OmniLight3D]=[]
func _ready() -> void:
	# Blender Kestrel emitter positions, converted from Z-up to Godot Y-up.
	for side in [-1,1]:
		var jet:=GPUParticles3D.new();jet.position=Vector3(side*5,.12,7.48);jet.amount=160;jet.lifetime=.20;jet.emitting=false;jet.local_coords=true
		jet.visibility_aabb=AABB(Vector3(-4,-4,-2),Vector3(8,8,35))
		var motion:=ParticleProcessMaterial.new();motion.direction=Vector3.BACK;motion.spread=1.5;motion.gravity=Vector3.ZERO;motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE;motion.emission_sphere_radius=.10;motion.initial_velocity_min=12;motion.initial_velocity_max=22;motion.scale_min=.45;motion.scale_max=.8;jet.process_material=motion
		var sprite:=QuadMesh.new();sprite.size=Vector2(.85,.85)
		var glow:=ShaderMaterial.new();glow.shader=load("res://assets/materials/space/exhaust.gdshader");glow.set_shader_parameter("tint",Color(.18,.65,1));glow.set_shader_parameter("strength",5.0);sprite.material=glow;jet.draw_pass_1=sprite;add_child(jet);jets.append(jet)
		var light:=OmniLight3D.new();light.position=jet.position;light.light_color=Color(.18,.7,1);light.omni_range=8;light.light_energy=0;add_child(light);lights.append(light)
func set_thrust(amount: float,boost: bool) -> void:
	for i in jets.size():
		jets[i].emitting=amount>.02
		var material: ParticleProcessMaterial=jets[i].process_material
		material.initial_velocity_min=lerpf(4,36 if boost else 18,amount)
		material.initial_velocity_max=material.initial_velocity_min*1.3
		lights[i].light_energy=amount*(4 if boost else 1.5)

func set_finch(enabled: bool) -> void:
	for i in jets.size():
		var side:=float(i*2-1)
		jets[i].position=Vector3(side*.79,1.49,2.7) if enabled else Vector3(side*5,.12,7.48)
		jets[i].scale=Vector3.ONE*(.3 if enabled else 1.0)
		lights[i].position=jets[i].position;lights[i].omni_range=3 if enabled else 8
