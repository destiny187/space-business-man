class_name FrontierPlanetWeather
extends RefCounted
## Host-owned, saved regional fronts. Weather never mutates industry or climate.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_weather.json"))
	return _config
static func create() -> Dictionary:return {"version":1,"clock":0.0,"planets":{},"observations":{}}
static func roll(body: Dictionary,key: String) -> float:return float(FrontierUniverse.derive(int(body.seed),"weather-v1:"+key)%1000000)/1000000.0
static func between(body: Dictionary,key: String,span: Array) -> float:return lerpf(float(span[0]),float(span[1]),roll(body,key))
static func profile(body: Dictionary) -> Dictionary:
	var traits: Dictionary=body.get("traits",{})
	var rain: bool=body.get("landable",true) and body.get("origin","")=="fictional" and float(traits.get("pressure",0))>=.3 and float(traits.get("water",0))>=10 and float(traits.get("temperature",-100))>0 and float(traits.get("temperature",100))<90
	# An explicit seeded atmospheric chemistry profile; ore colours are irrelevant.
	var acid: bool=rain and str(traits.get("id","")) in config().acid_profiles and roll(body,"chemistry")<.5
	var storm: bool=rain and not acid and roll(body,"convection")<.4
	return {"rain":rain,"chemistry":"acid_aerosol" if acid else "water","hazard":("acid" if acid else ("thunder" if storm else "")) if int(body.get("planet_tier",1))>=2 else "","name":"산성 에어로졸 대기" if acid else ("대류성 강우" if storm else ("물 순환 대기" if rain else "강우 없음"))}
static func ensure_planet(world: Dictionary,body: Dictionary) -> Dictionary:
	var state: Dictionary=world.weather
	if not state.planets.has(body.id):
		state.planets[body.id]={"serial":0,"attempt":0,"next_rain":float(state.clock)+between(body,"first-rain",[120,300]),"next_hazard":float(state.clock)+between(body,"first-hazard",config().quiet_seconds),"event":{}}
	return state.planets[body.id]
static func intensity(event: Dictionary,clock: float,p: Vector3) -> float:
	if event.is_empty() or clock<float(event.start) or clock>=float(event.end):return 0.0
	var distance:=Vector2(p.x-float(event.center[0]),p.z-float(event.center[2])).length()
	return (1.0-smoothstep(float(config().front_radius)*.8,float(config().front_radius),distance))*minf(1.0,minf((clock-float(event.start))/4.0,(float(event.end)-clock)/5.0))
static func buildings(local: Dictionary) -> Dictionary:return FrontierExpeditionBusiness.site(local).get("buildings",{})
static func canopy(local: Dictionary,p: Vector3) -> bool:
	for row in buildings(local).values():
		if row.type!="field_canopy":continue
		var d:=p-FrontierCrewWorld.vector(row.position)
		if absf(d.x)<2.82 and absf(d.z)<2.28 and d.y>-.3 and d.y<3.0:return true
	return false
static func mast(local: Dictionary,p: Vector3) -> Dictionary:
	var selected: Dictionary={};var nearest:=float(config().mast_radius)
	for row in buildings(local).values():
		if row.type!="grounding_mast":continue
		var d:=p-FrontierCrewWorld.vector(row.position)
		if absf(d.y)<12 and Vector2(d.x,d.z).length()<nearest:selected=row;nearest=Vector2(d.x,d.z).length()
	return selected
static func incident_safe(world: Dictionary,body_id: String,p: Vector3) -> bool:
	for row in world.get("incidents",{}).get("records",{}).values():
		if row.body_id==body_id and row.get("phase","") not in ["idle","complete","done"] and p.distance_to(FrontierCrewWorld.vector(row.position))<65:return true
	return false
static func sheltered(local: Dictionary,actor: String,obstacle: Callable) -> bool:
	var member: Dictionary=local.crew.members[actor]
	if member.area!="surface" or member.get("aboard",false):return true
	var p:=FrontierCrewWorld.vector(member.position)
	if canopy(local,p):return true
	if obstacle.is_valid() and float(obstacle.call(actor,p+Vector3.UP*1.75,Vector3.UP,90.0))<89.9:return true
	var field:=FrontierCrewSurface.field(local)
	# Server terrain density covers unloaded overhead cave rock as well as live meshes.
	if p.y<field.height(p.x,p.z)-2:
		for height in [2.0,4.0,8.0,16.0,32.0,64.0,90.0]:
			if field.density(p+Vector3.UP*height)>0:return true
	return false
static func acid_factor(body: Dictionary,ledger: Dictionary,p: Vector3) -> float:
	var environment:=FrontierSurfaceRecovery.sample_at(body,ledger,p)
	return smoothstep(float(config().acid_clean_toxicity),float(config().acid_full_toxicity),float(environment.get("toxicity",0)))
static func lightning_sheltered(local: Dictionary,actor: String) -> bool:
	var member: Dictionary=local.crew.members[actor]
	if member.area!="surface" or member.get("aboard",false):return true
	var p:=FrontierCrewWorld.vector(member.position);var field:=FrontierCrewSurface.field(local)
	if p.y>=field.height(p.x,p.z)-2:return false
	for height in [2.0,4.0,8.0,16.0,32.0,64.0,90.0]:
		if field.density(p+Vector3.UP*height)>0:return true
	return false
static func hurt(world: Dictionary,actor: String,amount: float,acid: bool) -> void:
	var member: Dictionary=world.crew.members[actor]
	if FrontierCrewVitals.weather_damage(member,amount,acid):
		member.position=FrontierCrewSurface.config().landing_spawn_positions[0].duplicate();member.incident_rescue=int(member.get("incident_rescue",0))+1
static func tick(world: Dictionary,delta: float,actors: Array,obstacle: Callable,ready: Callable,presence: Dictionary) -> bool:
	if not world.has("weather"):return false
	var state: Dictionary=world.weather;state.clock+=delta
	var clock: float=state.clock;var groups: Dictionary={}
	for actor in presence.keys():
		if actor not in actors:presence.erase(actor)
	for actor in actors:
		var local:=FrontierShuttles.context(world,actor)
		if not FrontierCrewSurface.landed(local):presence.erase(actor);continue
		var body:=FrontierUniverse.body_from_id(world.manifest,local.location)
		if not profile(body).rain:presence.erase(actor);continue
		if not groups.has(body.id):groups[body.id]={"body":body,"actors":[]}
		groups[body.id].actors.append(actor)
		if not presence.has(actor) or presence[actor].body_id!=body.id:presence[actor]={"body_id":body.id,"grace":float(config().entry_grace),"exposure":0.0,"sheltered":true,"grounded":false,"acid_factor":0.0}
		var view: Dictionary=presence[actor]
		if not ready.is_valid() or not bool(ready.call(actor)):view.grace=float(config().entry_grace)
		else:view.grace=maxf(0,view.grace-delta)
		view.sheltered=sheltered(local,actor,obstacle)
		view.lightning_sheltered=lightning_sheltered(local,actor)
		var p:=FrontierCrewWorld.vector(world.crew.members[actor].position)
		view.grounded=not mast(local,p).is_empty()
		view.acid_factor=acid_factor(body,world.get("business",{}),p)
		view.incident_safe=incident_safe(world,body.id,p)
	var changed:=false
	for body_id in groups:
		var body: Dictionary=groups[body_id].body;var climate:=profile(body);var row:=ensure_planet(world,body)
		var event: Dictionary=row.event
		if not event.is_empty() and clock>=float(event.end):
			if event.kind!="rain":row.next_hazard=clock+between(body,"quiet:"+str(int(row.serial)),config().quiet_seconds)
			row.event={};event={};row.next_rain=clock+between(body,"rain-gap:"+str(int(row.serial)),config().rain_interval);changed=true
		if event.is_empty():
			var kind:=""
			if clock>=float(row.next_hazard):
				row.attempt+=1;row.next_hazard=clock+between(body,"attempt-gap:"+str(int(row.attempt)),config().quiet_seconds)
				if not str(climate.hazard).is_empty() and roll(body,"attempt:"+str(int(row.attempt)))<float(config().hazard_chance):kind=climate.hazard
			if kind.is_empty() and clock>=float(row.next_rain):kind="rain"
			if not kind.is_empty():
				row.serial+=1
				var actor: String=groups[body_id].actors[0];var center:=FrontierCrewWorld.vector(world.crew.members[actor].position)
				var start:=clock+(float(config().warning_seconds) if kind!="rain" else 6.0)
				row.event={"kind":kind,"serial":row.serial,"center":[center.x,center.y,center.z],"announced":clock,"start":start,"end":start+between(body,"duration:"+str(int(row.serial)),config().rain_seconds if kind=="rain" else config().hazard_seconds),"next_strike":start+4,"strike_serial":0,"strikes":[]};event=row.event;changed=true
		if event.is_empty():
			for actor in groups[body_id].actors:presence[actor].exposure=0.0
			continue
		if event.kind=="thunder" and clock>=float(event.start) and clock<float(event.end):
			if clock>=float(event.next_strike) and clock+float(config().strike_warning)<float(event.end):
				event.strike_serial+=1
				var key:="bolt:%d:%d"%[int(row.serial),int(event.strike_serial)]
				var actor: String=groups[body_id].actors[int(event.strike_serial)%groups[body_id].actors.size()]
				var local:=FrontierShuttles.context(world,actor);var p:=FrontierCrewWorld.vector(world.crew.members[actor].position)
				# Chosen once at warning time; the marker never follows a moving player.
				var angle:=roll(body,key)*TAU;var radius:=between(body,key+":range",[2,22]);p+=Vector3(cos(angle),0,sin(angle))*radius
				p.y=FrontierCrewSurface.field(local).height(p.x,p.z)
				if intensity(event,clock,p)>0:
					var pole:=mast(local,p);var ground:=not pole.is_empty()
					if ground:p=FrontierCrewWorld.vector(pole.position)+Vector3.UP*5
					event.strikes.append({"id":int(event.strike_serial),"point":[p.x,p.y,p.z],"at":clock+float(config().strike_warning),"done":false,"grounded":ground})
				event.next_strike=clock+between(body,key+":gap",config().strike_interval);changed=true
			for bolt in event.strikes:
				if bolt.done or clock<float(bolt.at):continue
				bolt.done=true;changed=true
				if bolt.grounded or clock-float(bolt.at)>1:continue
				for actor in groups[body_id].actors:
					var view: Dictionary=presence[actor];var p:=FrontierCrewWorld.vector(world.crew.members[actor].position)
					if view.grace>0 or view.lightning_sheltered or view.grounded or view.incident_safe:continue
					if p.distance_to(FrontierCrewWorld.vector(bolt.point))<float(config().strike_radius):hurt(world,actor,float(config().strike_damage),false)
		for actor in groups[body_id].actors:
			var view: Dictionary=presence[actor];var p:=FrontierCrewWorld.vector(world.crew.members[actor].position)
			if event.kind!="acid" or view.grace>0 or view.sheltered or view.incident_safe or view.acid_factor<=0 or intensity(event,clock,p)<.2:view.exposure=0.0;continue
			var previous: float=view.exposure;view.exposure+=delta
			if view.exposure>float(config().acid_grace):hurt(world,actor,minf(delta,view.exposure-maxf(previous,float(config().acid_grace)))*float(config().acid_damage)*float(view.acid_factor),true);changed=true
	return changed
static func snapshot(world: Dictionary,actor: String,presence: Dictionary={}) -> Dictionary:
	if not world.has("weather") or not world.get("crew",{}).get("members",{}).has(actor):return {}
	var local:=FrontierShuttles.context(world,actor);var body:=FrontierUniverse.body_from_id(world.manifest,local.location)
	var forecast_id:=FrontierUniverse.body_id(world.manifest,int(local.crew.navigation.target))
	return {"body_id":body.id,"clock":world.weather.clock,"profile":profile(body),"forecast":profile(FrontierUniverse.body_from_id(world.manifest,forecast_id)),"event":world.weather.planets.get(body.id,{}).get("event",{}).duplicate(true),"personal":presence.get(actor,{}).duplicate(true),"observed":world.weather.observations.size()}
static func target(world: Dictionary,actor: String,aim: Vector3) -> Dictionary:
	if not world.has("weather") or aim.y<.4:return {}
	var e: Dictionary=world.weather.planets.get(world.location,{}).get("event",{})
	var p:=FrontierCrewWorld.vector(world.crew.members[actor].position)
	if intensity(e,float(world.weather.clock),p)<.2:return {}
	if canopy(world,p) or not FrontierCrewSurface.visible_in_field(FrontierCrewSurface.field(world),p+Vector3.UP*1.75,p+aim*14):return {}
	return {"kind":"weather","id":str(world.location)+"/weather/"+str(e.kind),"body_id":world.location,"weather_kind":e.kind,"point":p+aim*14}
static func observe(world: Dictionary,row: Dictionary) -> void:
	world.weather.observations[row.id]={"body_id":row.body_id,"weather_kind":row.weather_kind}
static func info(row: Dictionary) -> Dictionary:
	var kind: String=row.weather_kind
	return {"kind":"weather","name":{"rain":"비","acid":"산성비","thunder":"뇌우"}.get(kind,"기상"),"icon":"scan","subtitle":"행성 기상 관측","notes":[{"icon":"scan","text":"대기 성분과 지면 환경에 따른 현장 기상"},{"icon":"build","text":{"rain":"차양 아래에서 빗소리의 변화를 들을 수 있습니다.","acid":"차양·동굴로 피하거나 환경 정화로 부식성을 줄입니다.","thunder":"낙뢰 예고 지점을 벗어나거나 접지봉 18m 안으로 이동합니다."}.get(kind,"")}],"condition":"행성·기상별 한 번 기록 · 채집·생산 손실 없음","action":"J  발견 기록"}
static func valid(state: Variant) -> bool:
	if not state is Dictionary or state.get("version")!=1 or not FrontierUniverse._finite(state.get("clock"),0,9007199254740000):return false
	if not state.get("planets") is Dictionary or not state.get("observations") is Dictionary:return false
	for id in state.planets:
		var row: Variant=state.planets[id]
		if not id is String or not row is Dictionary:return false
		for key in ["serial","attempt","next_rain","next_hazard"]:
			if not FrontierUniverse._finite(row.get(key),0,9007199254740000):return false
		if not row.get("event") is Dictionary:return false
		var e: Dictionary=row.event
		if e.is_empty():continue
		if e.get("kind") not in ["rain","acid","thunder"]:return false
		if not e.get("center") is Array or e.center.size()!=3:return false
		for axis in e.center:
			if not FrontierUniverse._finite(axis,-1000000,1000000):return false
		for key in ["serial","announced","start","end","next_strike","strike_serial"]:
			if not FrontierUniverse._finite(e.get(key),0,9007199254740000):return false
		if e.end<=e.start or e.start<e.announced or not e.get("strikes") is Array or e.strikes.size()>12:return false
		for bolt in e.strikes:
			if not bolt is Dictionary or not bolt.get("done") is bool or not bolt.get("grounded") is bool:return false
			if not FrontierUniverse._finite(bolt.get("at"),0,9007199254740000) or not FrontierUniverse._finite(bolt.get("id"),1,1000):return false
			if not bolt.get("point") is Array or bolt.point.size()!=3:return false
			for axis in bolt.point:
				if not FrontierUniverse._finite(axis,-1000000,1000000):return false
	for id in state.observations:
		var row: Variant=state.observations[id]
		if not row is Dictionary or not row.get("body_id") is String or row.get("weather_kind") not in ["rain","acid","thunder"]:return false
		if id!=row.body_id+"/weather/"+row.weather_kind:return false
	return true
