class_name FrontierPlanetaryCycles
extends RefCounted
## Seeded two-body orbital/spin model. Industry seconds are never scaled here.
static var cache: Dictionary={}
static func config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/planetary_cycles.json"))
static func enabled(manifest: Dictionary) -> bool:
	return manifest.get("settings",{}).get("planetary_cycles",{}).get("enabled",false)
static func valid(value: Variant) -> bool:
	# Presets are snapshotted in the manifest; reject unsupported rules without migrating saves.
	if not value is Dictionary or value.get("version")!=1 or not value.get("enabled") is bool:return false
	if not value.get("presentation") is Dictionary:return false
	var expected:=config();expected.enabled=value.enabled
	if not value.presentation.has("night_wind_db"):expected.presentation.erase("night_wind_db")
	return FrontierUniverse.fingerprint(value)==FrontierUniverse.fingerprint(expected)
static func fraction(seed_value: int,key: String) -> float:
	return float(FrontierUniverse.derive(seed_value,key)%1000000)/1000000.0
static func star(manifest: Dictionary,system: Dictionary) -> Dictionary:
	var cfg: Dictionary=manifest.settings.planetary_cycles
	var profile: Array=cfg.star_profiles[system.star.spectral_type]
	return {"mass_solar":profile[0],"radius_solar":profile[1],"luminosity_solar":profile[2],"origin":"observed" if int(system.ordinal)==0 else "generated","version":1}
static func metadata(manifest: Dictionary,body: Dictionary) -> Dictionary:
	var cfg: Dictionary=manifest.settings.planetary_cycles
	var key: String=body.id+":"+str(cfg.hash())
	if cache.has(key):return cache[key]
	var system:=FrontierUniverse.system(manifest,int(body.system_ordinal))
	var primary:=star(manifest,system)
	var seed_value:=FrontierUniverse.derive(int(manifest.seed),system.id+":astro:v1")
	var spin_seed:=FrontierUniverse.derive(int(system.seed),body.id+":spin:v1")
	var slot: int=int(body.ordinal)-FrontierUniverse.first_ordinal(manifest,int(system.ordinal))
	# Geometric spacing and bounded eccentricity keep adjacent physical orbits disjoint.
	var a:=sqrt(float(primary.luminosity_solar))*lerpf(cfg.inner_habitable_fraction[0],cfg.inner_habitable_fraction[1],fraction(seed_value,"inner"))*pow(float(cfg.orbit_spacing),slot)
	var e:=fraction(spin_seed,"eccentricity")*float(cfg.eccentricity_max)
	var tilt:=lerpf(cfg.tilt_degrees[0],cfg.tilt_degrees[1],fraction(spin_seed,"tilt"))
	var spin:=exp(lerpf(log(float(cfg.spin_hours[0])),log(float(cfg.spin_hours[1])),fraction(spin_seed,"period")))*3600.0
	var state:="prograde"
	if int(system.ordinal)==0:
		a=float(cfg.solar.semimajor_au[slot]);e=float(cfg.solar.eccentricity[slot]);tilt=float(cfg.solar.tilt_degrees[slot]);spin=float(cfg.solar.spin_hours[slot])*3600.0
		state="reference_retrograde" if tilt>90 else "reference_prograde"
	var period:=float(cfg.year_seconds)*sqrt(pow(a,3)/float(primary.mass_solar))
	if int(system.ordinal)>0:
		var days:=period/86400.0
		var weight: float=cfg.locked_weights[0] if days<cfg.locked_days[0] else (cfg.locked_weights[1] if days<cfg.locked_days[1] else 0.0)
		if fraction(spin_seed,"locking")<weight:state="synchronous";spin=period;e=0.0;tilt=0.0
	var result:={"version":1,"enabled":cfg.enabled,"origin":"estimated" if int(system.ordinal)==0 else "generated","reference_source":cfg.solar.source if int(system.ordinal)==0 else "", "star":primary,"a_au":a,"eccentricity":e,"orbit_seconds":period,"spin_seconds":spin,"spin_state":state,"tilt":deg_to_rad(tilt),"spin_phase":fraction(spin_seed,"phase")*TAU,"latitude":deg_to_rad(lerpf(cfg.latitude_degrees[0],cfg.latitude_degrees[1],fraction(spin_seed,"latitude"))),"longitude":fraction(spin_seed,"longitude")*TAU,"time_scale":cfg.time_scale,"epoch_offset":cfg.epoch_offset,"intro_eligible":false}
	var solar_day:=TAU/absf(TAU/spin+(TAU/period if tilt>90 else -TAU/period)) if state!="synchronous" else 0.0
	# Extreme irradiation/climate disagreements remain fictional; not tutorial recommendations.
	var flux: float=primary.luminosity_solar/(a*a)
	result.intro_eligible=state=="prograde" and solar_day/3600>=cfg.intro_day_hours[0] and solar_day/3600<=cfg.intro_day_hours[1] and tilt<=float(cfg.intro_max_tilt) and flux>=.45 and flux<=2.5
	var visual_e:=e
	for neighbour in [slot-1,slot+1]:
		if neighbour<0 or neighbour>=FrontierUniverse.body_count(manifest,int(system.ordinal)):continue
		var other:=FrontierUniverse.orbit_radius(manifest,int(system.ordinal),neighbour)
		visual_e=minf(visual_e,absf(other-float(body.orbit.radius))/(other+float(body.orbit.radius))*.4)
	result.display_eccentricity=visual_e
	result.irradiation_earth=flux
	result.mean_solar_seconds=solar_day
	if cache.size()>1024:cache.clear()
	cache[key]=result
	return result
static func seconds(astro: Dictionary,active_sim_seconds: float) -> float:
	return active_sim_seconds*float(astro.time_scale)+float(astro.epoch_offset)
static func anomaly(body: Dictionary,elapsed: float) -> float:
	var a: Dictionary=body.astro
	var mean:=fposmod(float(body.orbit.phase)+seconds(a,elapsed)/float(a.orbit_seconds)*TAU,TAU)
	var eccentric:=mean
	for i in 7:eccentric-=(eccentric-float(a.eccentricity)*sin(eccentric)-mean)/(1.0-float(a.eccentricity)*cos(eccentric))
	return 2.0*atan2(sqrt(1.0+float(a.eccentricity))*sin(eccentric*.5),sqrt(1.0-float(a.eccentricity))*cos(eccentric*.5))
static func orbit_basis(body: Dictionary) -> Basis:
	var tilt: float=deg_to_rad(float(FrontierUniverse.presentation().inclination_min_degrees)+float(FrontierUniverse.derive(int(body.seed),"inclination")%10000)/10000.0*float(FrontierUniverse.presentation().inclination_range_degrees))
	var node: float=float(FrontierUniverse.derive(int(body.seed),"ascending-node")%10000)/10000.0*TAU
	return Basis(Vector3.UP,node)*Basis(Vector3.RIGHT,tilt)
static func orbit_position(body: Dictionary,elapsed: float) -> Vector3:
	var angle:=anomaly(body,elapsed)
	var e: float=body.astro.display_eccentricity
	var radius: float=body.orbit.radius*(1-e*e)/(1+e*cos(angle))
	return orbit_basis(body)*Vector3(cos(angle),0,-sin(angle))*radius
static func orientation(body: Dictionary,elapsed: float) -> Basis:
	var a: Dictionary=body.astro
	# Orbit and spin both advance about +Y; +longitude points towards -Z.
	var angle:=fposmod(float(a.spin_phase)+seconds(a,elapsed)/float(a.spin_seconds)*TAU,TAU)
	return orbit_basis(body)*Basis(Vector3.RIGHT,float(a.tilt))*Basis(Vector3.UP,angle)
static func local_basis(latitude: float,longitude: float) -> Basis:
	var up:=Vector3(cos(latitude)*cos(longitude),sin(latitude),-cos(latitude)*sin(longitude))
	var east:=Vector3(-sin(longitude),0,-cos(longitude))
	var north:=Vector3(-sin(latitude)*cos(longitude),cos(latitude),sin(latitude)*sin(longitude))
	# Ground +X east, -Z north, +Y zenith. Right handed.
	return Basis(east,up,-north)
static func sky_state(body: Dictionary,elapsed: float,region: Dictionary={}) -> Dictionary:
	var a: Dictionary=body.astro
	var local_to_world:=orientation(body,elapsed)*local_basis(float(region.get("latitude",a.latitude)),float(region.get("longitude",a.longitude)))
	var toward_star: Vector3=-orbit_position(body,elapsed).normalized()
	var sun:=local_to_world.transposed()*toward_star
	return {"sun_direction":sun,"local_to_inertial":local_to_world,"sun_height":sun.y,"daylight":smoothstep(-.12,.18,sun.y),"elapsed":elapsed,"spin_state":a.spin_state}
static func landing_region(body: Dictionary,elapsed: float) -> Dictionary:
	var a: Dictionary=body.astro
	# Choose a daylight longitude once, without resetting the global shared clock.
	var toward:=orientation(body,elapsed).transposed()*(-orbit_position(body,elapsed).normalized())
	return {"latitude":a.latitude,"longitude":atan2(-toward.z,toward.x),"north":"-Z"}

static func ensure_region(world: Dictionary,body: Dictionary) -> Dictionary:
	if not enabled(world.manifest):return {}
	if not world.has("celestial_regions"):world.celestial_regions={}
	if not world.celestial_regions.has(body.id):
		var a: Dictionary=body.astro
		var region:={"latitude":a.latitude,"longitude":a.longitude,"north":"-Z"}
		if world.celestial_regions.is_empty() and a.intro_eligible:region=landing_region(body,float(world.crew.navigation.orbit_time))
		world.celestial_regions[body.id]=region
	return world.celestial_regions[body.id]
static func valid_region(value: Variant) -> bool:
	return value is Dictionary and FrontierUniverse._finite(value.get("latitude"),-PI/2,PI/2) and FrontierUniverse._finite(value.get("longitude"),-TAU,TAU) and value.get("north")=="-Z"
static func validate_regions(world: Dictionary) -> String:
	if not world.has("celestial_regions"):return ""
	if not world.celestial_regions is Dictionary or not enabled(world.manifest):return "천체 지역 기록 오류"
	for id in world.celestial_regions:
		if not id is String or FrontierUniverse.ordinal_of(world.manifest,id)<0 or not valid_region(world.celestial_regions[id]):return "천체 지역 위도·경도 오류"
	return ""
