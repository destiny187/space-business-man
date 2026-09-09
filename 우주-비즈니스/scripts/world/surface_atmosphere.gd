extends RefCounted
## Presentation of authoritative regional environment, not a global atmosphere simulation.
static var rules: Dictionary={}
var environment: Environment
var sun: DirectionalLight3D
var material: ShaderMaterial
var body: Dictionary
var site: Dictionary={}
var regional_ledger: Dictionary={}
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
	var fx: Dictionary=cfg.particles
	var cold: float=1.0-smoothstep(float(fx.frozen_temperature),float(fx.freeze_temperature),temperature)
	var dry: float=1.0-clampf(float(values.get("water",native.water))/float(fx.dry_water_max),0,1)
	var damp: float=smoothstep(float(fx.mist_water_min),float(fx.mist_water_full),float(values.get("water",native.water)))
	var hot: float=smoothstep(float(fx.hot_temperature),float(fx.hot_temperature_full),temperature)
	return {"dust":depth*dry*(1.0-cold)*(.3+.7*toxicity),"ice":depth*cold*water,"mist":depth*(1.0-cold)*maxf(toxicity*.75,damp*(.3+.7*hot)),"dust_color":dust,"zenith":Color(cfg.vacuum_zenith).lerp(top,depth),"horizon":Color(cfg.vacuum_horizon).lerp(tint,depth),"cloud_color":tint.lerp(Color("eef1e9"),clear*.85),"atmosphere":depth,"cloud_amount":depth*water*habitable*(1.0-toxicity*.7),"fog":depth*(float(cfg.clear_fog_density)+toxicity*float(cfg.pollution_fog_density)),"ambient":lerpf(cfg.surface_ambient[0],cfg.surface_ambient[1],depth),"light":Color("ffe1b5").lerp(Color("edf4ff"),clear*depth*.65)}
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
	regional_ledger=ledger
	site={} if source.is_empty() else {"center":source.center.duplicate(),"environment":source.environment.duplicate()}
func target_at(position: Vector3) -> Dictionary:
	var native: Dictionary=body.get("traits",FrontierCatalog.entry("planets",body.kind)).duplicate(true)
	if FrontierRegionalTerraform.enabled(regional_ledger.get("sites",{}).get(body.id,{})):
		return appearance(body,FrontierSurfaceRecovery.sample_at(body,regional_ledger,position))
	if not site.is_empty():
		var center:=FrontierExpeditionBusiness.point(site.center)
		var distance_from_site:=Vector2(position.x-center.x,position.z-center.z).length()
		var radius: float=FrontierExpeditionBusiness.config().build_radius
		var weight: float=1.0-smoothstep(radius,radius*float(config().influence_radius_multiplier),distance_from_site)
		for key in ["pressure","toxicity","temperature","water"]:native[key]=lerpf(float(native[key]),float(site.environment.get(key,native[key])),weight)
	return appearance(body,native)
func step(delta: float,position: Vector3,underground: float,fog_setting: float) -> void:
	if not cycles.is_empty():
		var limit: float=cycles.clock_extrapolation_limit
		clock_seconds+=minf(delta,maxf(0,limit-clock_age));clock_age+=delta
	var target:=target_at(position)
	var blend: float=1.0-exp(-delta/float(config().transition_seconds))
	for key in current:
		if current[key] is Color:current[key]=current[key].lerp(target[key],blend)
		else:current[key]=lerpf(current[key],target[key],blend)
	refresh_timer-=delta
	if refresh_timer<=0:
		refresh_timer=float(cycles.get("refresh_seconds",config().refresh_seconds));update_cycles();paint()
	environment.ambient_light_energy=lerpf(lerpf(minf(float(cycles.get("night_ambient",current.ambient)),current.ambient*.75) if not cycles.is_empty() else current.ambient,current.ambient,daylight),float(config().cave_ambient),underground)
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
	paint_cycles()

# New worlds share orbital time; old manifests retain their original static sky.
var cycles: Dictionary={}
var sky_state: Dictionary={}
var sky_region: Dictionary={}
var clock_seconds:=0.0
var last_host_seconds:=-1.0
var clock_age:=0.0
var daylight:=1.0
func configure_cycles(manifest: Dictionary,region: Dictionary,elapsed: float) -> void:
	if not FrontierPlanetaryCycles.enabled(manifest):return
	cycles=manifest.settings.planetary_cycles.presentation
	sky_region=region.duplicate(true);clock_seconds=elapsed;last_host_seconds=elapsed;clock_age=0.0
	update_cycles();paint()
func sync_clock(elapsed: float) -> void:
	if cycles.is_empty() or last_host_seconds==elapsed:return
	last_host_seconds=elapsed;clock_age=0.0
	clock_seconds=elapsed if absf(clock_seconds-elapsed)>2 else lerpf(clock_seconds,elapsed,.35)
func update_cycles() -> void:
	if cycles.is_empty():return
	sky_state=FrontierPlanetaryCycles.sky_state(body,clock_seconds,sky_region);daylight=float(sky_state.daylight)
	var direction: Vector3=sky_state.sun_direction
	sun.basis=Basis.looking_at(-direction,Vector3.RIGHT if absf(direction.y)>.99 else Vector3.UP)
	sun.light_energy=float(cycles.sun_energy)*smoothstep(-.02,.10,direction.y)
	material.set_shader_parameter("celestial_active",true)
	material.set_shader_parameter("sun_direction",direction)
	material.set_shader_parameter("stars_basis",sky_state.local_to_inertial)
	material.set_shader_parameter("night_mix",1.0-daylight)
	material.set_shader_parameter("cloud_offset",Vector2(1.0,.37)*fposmod(clock_seconds*float(cycles.cloud_speed),4096.0))
	var a: Dictionary=body.astro
	var angle:=FrontierPlanetaryCycles.anomaly(body,clock_seconds)
	var distance: float=a.a_au*(1.0-a.eccentricity*a.eccentricity)/(1.0+a.eccentricity*cos(angle))
	material.set_shader_parameter("sun_radius",clampf(float(cycles.sun_angular_radius)*float(a.star.radius_solar)/distance,.001,.12))
func paint_cycles() -> void:
	if cycles.is_empty():return
	var night_top:=Color(cycles.night_zenith);var night_rim:=Color(cycles.night_horizon)
	var dusk: float=(1.0-smoothstep(.03,.24,absf(sky_state.sun_height)))*current.atmosphere
	var rim: Color=night_rim.lerp(current.horizon,daylight).lerp(Color(cycles.twilight_color),dusk*.5)
	material.set_shader_parameter("zenith",night_top.lerp(current.zenith,daylight))
	material.set_shader_parameter("horizon",rim)
	material.set_shader_parameter("cloud_color",Color("192838").lerp(current.cloud_color,daylight).lerp(Color("986a66"),dusk*.35))
	environment.fog_light_color=rim
	environment.ambient_light_color=Color("8197bc").lerp(current.horizon.lerp(Color("b5cbd4"),.65),daylight)
	sun.light_color=current.light.lerp(Color("ffb77e"),dusk*.8)
func cycle_label() -> String:
	if cycles.is_empty():return "기존 세계 · 고정 하늘"
	if body.astro.spin_state=="synchronous":return "동주기 · "+("낮 면" if sky_state.sun_height>.1 else ("밤 면" if sky_state.sun_height<-.1 else "황혼대"))
	return "낮" if sky_state.sun_height>.15 else ("밤" if sky_state.sun_height<-.12 else "황혼")
