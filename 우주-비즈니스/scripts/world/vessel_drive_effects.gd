class_name FrontierVesselDriveEffects
extends Node3D
var jets: Array[GPUParticles3D]=[]
var lights: Array[OmniLight3D]=[]
var nozzles: Array[Node3D]=[]
var attitude_jets: Array[GPUParticles3D]=[]
var nozzle_directions: Array[Vector3]=[]
var target_thrust:=0.0
var target_boost:=false
var thrust:=0.0
var heat:=0.0
var finch:=false
var steering:=Vector2.ZERO
var braking:=0.0
var blocked:=false
var cache: Dictionary={}
func _ready() -> void:
	for side in [-1,1]:
		var jet:=_jet(120,.20,.85);jet.position=Vector3(side*5,.12,7.48);add_child(jet);jets.append(jet)
		var light:=OmniLight3D.new();light.position=jet.position;light.light_color=Color(.18,.7,1);light.omni_range=8;light.light_energy=0;add_child(light);lights.append(light)
	var model: PackedScene=load(FrontierOrbitalPresentation.config().drive.nozzle_model)
	# Outlets point away from the torque they create; forward outlets handle braking.
	for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.FORWARD]:
		var nozzle: Node3D=model.instantiate();FrontierInkStyle.apply(nozzle,cache);add_child(nozzle);nozzles.append(nozzle);nozzle_directions.append(direction)
		var jet:=_jet(28,.12,.22);jet.position=Vector3(0,0,.25);nozzle.add_child(jet);attitude_jets.append(jet)
	_layout()
func _jet(amount: int,lifetime: float,size: float) -> GPUParticles3D:
	var jet:=GPUParticles3D.new();jet.amount=amount;jet.lifetime=lifetime;jet.emitting=false;jet.local_coords=true
	jet.visibility_aabb=AABB(Vector3(-10,-10,-12),Vector3(20,20,55))
	var motion:=ParticleProcessMaterial.new();motion.direction=Vector3.BACK;motion.spread=3;motion.gravity=Vector3.ZERO;motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE;motion.emission_sphere_radius=.08;motion.initial_velocity_min=10;motion.initial_velocity_max=16;motion.scale_min=.35;motion.scale_max=.75;jet.process_material=motion
	var sprite:=QuadMesh.new();sprite.size=Vector2.ONE*size
	var glow:=ShaderMaterial.new();glow.shader=load("res://assets/materials/space/exhaust.gdshader");glow.set_shader_parameter("strength",3.0);sprite.material=glow;jet.draw_pass_1=sprite
	return jet
func set_thrust(amount: float,boost: bool) -> void:
	target_thrust=clampf(amount,0,1);target_boost=boost
func set_motion(turn: Vector2,brake: float,paused: bool) -> void:
	steering=turn;braking=clampf(brake,0,1);blocked=paused
func _process(delta: float) -> void:
	for jet in jets+attitude_jets:jet.speed_scale=0.0 if blocked else 1.0
	if blocked:return
	thrust=lerpf(thrust,target_thrust,minf(1.0,delta*float(FrontierOrbitalPresentation.config().drive.response)))
	heat=move_toward(heat,thrust,delta/(.3 if thrust>heat else float(FrontierOrbitalPresentation.config().drive.cooldown_seconds)))
	for i in jets.size():
		jets[i].emitting=thrust>.025
		var material: ParticleProcessMaterial=jets[i].process_material
		material.initial_velocity_min=lerpf(4,36 if target_boost else 18,thrust);material.initial_velocity_max=material.initial_velocity_min*1.3
		var glow: ShaderMaterial=jets[i].draw_pass_1.material
		glow.set_shader_parameter("strength",lerpf(1.5,4.0,thrust));glow.set_shader_parameter("tint",Color("78dbff") if target_boost else Color("3ca7f4"))
		lights[i].light_energy=thrust*(3.0 if target_boost else 1.2)+heat*.18
		lights[i].light_color=Color("e17236").lerp(Color("4eb9ff"),minf(thrust*4,1))
	for i in nozzles.size():
		var demand:=0.0
		if i==0:demand=maxf(0,-steering.x)
		elif i==1:demand=maxf(0,steering.x)
		elif i==2:demand=maxf(0,-steering.y)
		elif i==3:demand=maxf(0,steering.y)
		else:demand=braking
		attitude_jets[i].emitting=demand>.055
		var material: ParticleProcessMaterial=attitude_jets[i].process_material
		material.initial_velocity_min=3+demand*15;material.initial_velocity_max=5+demand*20
func set_finch(enabled: bool) -> void:
	finch=enabled;_layout()
func _layout() -> void:
	for i in jets.size():
		var side:=float(i*2-1)
		jets[i].position=Vector3(side*.79,1.49,2.7) if finch else Vector3(side*5,.12,7.48)
		jets[i].scale=Vector3.ONE*(.3 if finch else 1.0)
		lights[i].position=jets[i].position;lights[i].omni_range=3 if finch else 8
	var points: Array[Vector3]=[Vector3(3.3,.7,-4.0),Vector3(-3.3,.7,-4.0),Vector3(0,2.6,-3.0),Vector3(0,-.55,-3.0),Vector3(2.3,.1,-5.9),Vector3(-2.3,.1,-5.9)]
	if finch:points=[Vector3(1.25,1.25,-.7),Vector3(-1.25,1.25,-.7),Vector3(0,2.0,-.45),Vector3(0,.5,-.45),Vector3(.7,1.1,-1.6),Vector3(-.7,1.1,-1.6)]
	for i in nozzles.size():
		nozzles[i].position=points[i];nozzles[i].basis=Basis.looking_at(nozzle_directions[i],Vector3.FORWARD if absf(nozzle_directions[i].y)>.9 else Vector3.UP,true)
		nozzles[i].scale=Vector3.ONE*(.6 if finch else 1.45)
