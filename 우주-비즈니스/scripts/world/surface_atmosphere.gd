extends RefCounted
## Presentation of authoritative regional environment, not a global atmosphere simulation.
static var rules: Dictionary={}
var environment: Environment
var sun: DirectionalLight3D
var material: ShaderMaterial
var body: Dictionary
var site: Dictionary={}
var current: Dictionary={}
var refresh_timer:=0.0
static func config() -> Dictionary:
	if rules.is_empty():rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_atmosphere.json"))
	return rules
static func appearance(planet: Dictionary,values: Dictionary) -> Dictionary:
	var cfg:=config()
	var native: Dictionary=planet.get("traits",FrontierCatalog.entry("planets",planet.kind))
	var pressure: float=maxf(0,float(values.get("pressure",native.pressure)))
	var depth: float=1.0-exp(-pressure/float(cfg.pressure_scale))
	var toxicity: float=clampf(float(values.get("toxicity",native.toxicity))/100.0,0,1)
	var temperature: float=float(values.get("temperature",native.temperature))
	var water: float=clampf(float(values.get("water",native.water))/65.0,0,1)
	var habitable: float=1.0-clampf(absf(temperature-18.0)/110.0,0,1)
	var dust:=Color(native.get("dust","b99977"))
	var clear: float=(1.0-toxicity)*habitable
	var tint:=dust.lerp(Color(cfg.clear_horizon),clear)
	var top:=dust.darkened(.55).lerp(Color(cfg.clear_zenith),clear)
	return {"zenith":Color(cfg.vacuum_zenith).lerp(top,depth),"horizon":Color(cfg.vacuum_horizon).lerp(tint,depth),"cloud_color":tint.lerp(Color("eef1e9"),clear*.85),"atmosphere":depth,"cloud_amount":depth*water*habitable*(1.0-toxicity*.7),"fog":depth*(float(cfg.clear_fog_density)+toxicity*float(cfg.pollution_fog_density)),"ambient":lerpf(cfg.surface_ambient[0],cfg.surface_ambient[1],depth),"light":Color("ffe1b5").lerp(Color("edf4ff"),clear*depth*.65)}
func configure(planet: Dictionary,target: Environment,light: DirectionalLight3D) -> void:
	body=planet;environment=target;sun=light
	material=ShaderMaterial.new();material.shader=load("res://assets/materials/space/surface_sky.gdshader")
	material.set_shader_parameter("seed_phase",float(int(body.get("seed",0))%10000)*.017)
	var sky:=Sky.new();sky.sky_material=material;sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL;environment.sky=sky
	current=appearance(body,{})
	environment.ambient_light_energy=current.ambient;environment.fog_density=current.fog
	paint()
func accept(ledger: Dictionary) -> void:
	var source: Dictionary=ledger.get("sites",{}).get(body.id,{})
	site={} if source.is_empty() else {"center":source.center.duplicate(),"environment":source.environment.duplicate()}
func target_at(position: Vector3) -> Dictionary:
	var native: Dictionary=body.get("traits",FrontierCatalog.entry("planets",body.kind)).duplicate(true)
	if not site.is_empty():
		var center:=FrontierExpeditionBusiness.point(site.center)
		var distance_from_site:=Vector2(position.x-center.x,position.z-center.z).length()
		var radius: float=FrontierExpeditionBusiness.config().build_radius
		var weight: float=1.0-smoothstep(radius,radius*float(config().influence_radius_multiplier),distance_from_site)
		for key in ["pressure","toxicity","temperature","water"]:native[key]=lerpf(float(native[key]),float(site.environment.get(key,native[key])),weight)
	return appearance(body,native)
func step(delta: float,position: Vector3,underground: float,fog_setting: float) -> void:
	var target:=target_at(position)
	var blend: float=1.0-exp(-delta/float(config().transition_seconds))
	for key in current:
		if current[key] is Color:current[key]=current[key].lerp(target[key],blend)
		else:current[key]=lerpf(current[key],target[key],blend)
	refresh_timer-=delta
	if refresh_timer<=0:refresh_timer=float(config().refresh_seconds);paint()
	environment.ambient_light_energy=lerpf(current.ambient,float(config().cave_ambient),underground)
	environment.fog_density=lerpf(current.fog,float(config().cave_fog_density),underground)*fog_setting
func paint() -> void:
	for key in ["zenith","horizon","cloud_color","atmosphere","cloud_amount"]:
		var value: Variant=current[key]
		if value is Color:value=Color(snappedf(value.r,.002),snappedf(value.g,.002),snappedf(value.b,.002),1)
		else:value=snappedf(value,.002)
		if material.get_shader_parameter(key)!=value:material.set_shader_parameter(key,value)
	environment.fog_light_color=current.horizon
	environment.ambient_light_color=current.horizon.lerp(Color("b5cbd4"),.65)
	sun.light_color=current.light
