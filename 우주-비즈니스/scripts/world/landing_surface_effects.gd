class_name FrontierLandingSurfaceEffects
extends Node3D
var surface: FrontierCrewSurfaceScene
var emitters: Array[GPUParticles3D]=[]
var finch:=false
var ground_kind: String="dust"
var lamp: SpotLight3D
static func profile(body: Dictionary) -> Dictionary:
	var traits: Dictionary=body.get("traits",{})
	var pressure:=float(traits.get("pressure",0.0))
	var cfg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_arrival.json"))
	return {"air":1.0-exp(-pressure/float(cfg.air_pressure_scale)),"tint":Color(traits.get("dust","a6afb8")),"cold":float(traits.get("temperature",20))<0,"water":float(traits.get("water",0)),"pressure":pressure}
func configure(owner_surface: FrontierCrewSurfaceScene,small: bool) -> void:
	surface=owner_surface;finch=small
	var p:=profile(surface.body)
	ground_kind="ice" if p.cold and p.water>5 else "dust"
	var terrain: Dictionary=surface.body.get("terrain_traits",{})
	var water_level: float=-4.0 if float(terrain.get("water",0))>15 else -100000.0
	var home:=surface.landing_ship.position
	if not p.cold and (surface.terrain.field.height(home.x,home.z)<water_level+.3 or p.water>55):ground_kind="water"
	for side in [-1,1]:
		var dust:=GPUParticles3D.new();dust.amount=72 if small else 130;dust.lifetime=1.5;dust.emitting=false;dust.local_coords=false;dust.visibility_aabb=AABB(Vector3(-25,-6,-25),Vector3(50,20,50));add_child(dust)
		var motion:=ParticleProcessMaterial.new();motion.direction=Vector3.UP;motion.spread=70;motion.gravity=Vector3(0,-2.0 if ground_kind!="dust" else -.25,0)
		motion.initial_velocity_min=.8;motion.initial_velocity_max=2.6;motion.radial_velocity_min=3;motion.radial_velocity_max=10
		motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_RING;motion.emission_ring_radius=.8 if small else 1.5;motion.emission_ring_inner_radius=.2;motion.emission_ring_height=.08
		motion.scale_min=.15 if ground_kind!="dust" else .5;motion.scale_max=.45 if ground_kind!="dust" else 1.8
		var fade:=Gradient.new();fade.set_color(0,Color(1,1,1,0));fade.set_color(1,Color(1,1,1,0));fade.add_point(.15,Color.WHITE);fade.add_point(.65,Color(1,1,1,.4));var ramp:=GradientTexture1D.new();ramp.gradient=fade;motion.color_ramp=ramp
		dust.process_material=motion;var quad:=QuadMesh.new();quad.size=Vector2.ONE
		var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/landing_dust.gdshader");mat.set_shader_parameter("tint",Color("b8d7de") if ground_kind!="dust" else p.tint);quad.material=mat;dust.draw_pass_1=quad;emitters.append(dust)
	lamp=SpotLight3D.new();lamp.name="AirlockGroundLight";lamp.light_color=Color("ffe7b2");lamp.spot_range=18;lamp.spot_angle=52;lamp.shadow_enabled=true;lamp.light_energy=0;surface.landing_ship.add_child(lamp)
	lamp.position=Vector3(-.7,1.8,-.4) if small else Vector3(0,.9,7.1)
	lamp.basis=Basis.looking_at(Vector3(-1,-1,0) if small else Vector3(0,-1,2),Vector3.UP)
func update(height: float,thrust: float,hatch: float,blocked: bool) -> void:
	var response: float=(1.0-smoothstep(1.0,14.0 if finch else 24.0,height))*thrust
	for i in emitters.size():
		var dust:=emitters[i];var p:=surface.landing_ship.to_global(Vector3((i*2-1)*(.79 if finch else 2.3),0,.3 if finch else 0))
		p.y=surface.terrain.field.height(p.x,p.z)+.12;dust.global_position=p
		dust.speed_scale=0 if blocked else 1;dust.emitting=response>.02;dust.amount_ratio=maxf(.05,response)
		var motion: ParticleProcessMaterial=dust.process_material;motion.radial_velocity_max=3+response*12
	lamp.light_energy=hatch*(1.5 if finch else 3.2)
func release() -> void:
	if is_instance_valid(lamp):lamp.queue_free()
	queue_free()
