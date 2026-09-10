extends SceneTree
var failures:=0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL "+label)
	else:print("PASS "+label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world:=FrontierUniverse.new_world(61739);var m: Dictionary=world.manifest
	var owner:=FrontierPlayerProfile.new_character("시드 기업 항로",2);var core:=FrontierCrewAuthority.new();core.start(world,owner,func(_w):return true);world=core.world
	var examples: Dictionary={};var different: bool=false
	for i in range(1,801):
		var index: int=(i*701)%124999+1
		var profile:=FrontierCorporateSites.profile(m,index)
		if not examples.has(profile.theme):examples[profile.theme]=index
		if examples.size()==6:break
	check(examples.size()==6,"seed contains six distinct activity regions");print("REGION_EXAMPLES ",JSON.stringify(examples))
	var endpoints:=true;var geology:=true;var clearance:=true;var phases: Dictionary={};var management:=false
	for theme in examples:
		var index: int=examples[theme];var profile:=FrontierCorporateSites.profile(m,index)
		var before: String=JSON.stringify(profile);FrontierCorporateSites.cache.clear()
		check(before==JSON.stringify(FrontierCorporateSites.profile(m,index)),theme+" exact lazy regeneration")
		for site in profile.sites:
			var raw:=FrontierUniverse.body(m,int(site.body),false);var body:=FrontierUniverse.body(m,int(site.body))
			if site.managed:management=true;check(not FrontierUniverse.landable(body) and FrontierUniverse.landable(raw),"managed rocky world limits landing, preserves raw body")
			for field in ["traits","streams","resources","astro","moons"]:
				if raw.get(field)!=body.get(field):geology=false
			if FrontierCorporateSites.definition(m,site.id,12).is_empty():endpoints=false
		for t in range(0,1681,35):
			for row in FrontierSpaceTraffic.all(m,index,float(t)):
				phases[row.stage]=true
				if not row.position.is_finite() or row.direction.length()<.9:clearance=false
				if row.position.length()<float(FrontierUniverse.star_settings(m,index).star_warning_radius):clearance=false
				for j in FrontierUniverse.body_count(m,index):
					var ordinal:=FrontierUniverse.first_ordinal(m,index)+j;var body:=FrontierUniverse.body(m,ordinal)
					if row.position.distance_to(FrontierUniverse.position(m,ordinal,t))<FrontierUniverse.navigation_radius(body)+120:clearance=false
					for moon in int(body.get("moons",0)):
						if row.position.distance_to(FrontierUniverse.position(m,ordinal,t)+FrontierUniverse.moon_offset(body,moon,t))<FrontierUniverse.moon_radius(body,moon)+120:clearance=false
		var legacy: Dictionary=m.duplicate(true);legacy.settings.corporate_space.erase("expansion")
		check(FrontierCorporateSites.profile(legacy,index).sites.is_empty() and FrontierSpaceTraffic.all(legacy,index,5).is_empty(),theme+" absent in SP06 saves")
	check(endpoints and geology and management,"real endpoint references, independent generation and managed body exist")
	check(clearance,"representative two-leg traffic clears star planets and moons")
	check(phases.size()>=9,"all freight stages and regional patrol run")
	var first:=FrontierUniverse.system_index(m,FrontierCrewNavigation.first_destination(m));check(FrontierCorporateSites.profile(m,first).sites.is_empty(),"first recommended expedition stays free")
	var index: int=examples.managed;var port: String=FrontierCorporateSites.guard_ports(m,index)[0];var pos:=FrontierCrewWorld.vector(FrontierSpaceTraffic.port(m,port,0).position)+Vector3(1000,600,0)
	world.crew.navigation.system=index;world.crew.navigation.target=FrontierUniverse.first_ordinal(m,index);world.crew.navigation.position=FrontierExpeditionBusiness.array(pos);world.flight_position=world.crew.navigation.position.duplicate()
	world.crew.navigation.traffic_observers=[{"id":"crew","system":0,"position":world.crew.navigation.position.duplicate()}];FrontierSpacePatrol.step(world)
	check(world.crew.navigation.traffic_patrols[port].started==-1,"same coordinates in another system do not trigger guard")
	world.crew.navigation.traffic_observers=FrontierSpaceTraffic.observers(world);FrontierSpacePatrol.step(world)
	check(world.crew.navigation.traffic_patrols[port].started==0,"host local observer triggers regional guard")
	var sampler:=FrontierTrafficSampler.new()
	for i in 120:sampler.sample(m,index,float(i)/60,Vector3.ONE*1e6,[],{})
	check(sampler.evaluations<=32,"far vessels sample at low frequency with stable interpolated objects")
	check(FrontierWorldStore.new("/tmp/corporations-sp07/world.json").write(world),"regional rule and patrol save accepted")
	var saved:=FrontierWorldStore.new("/tmp/corporations-sp07/world.json").read_state()
	if not saved.is_empty():
		var a:=FrontierSpaceTraffic.all(m,index,123,world.crew.navigation.traffic_observers,world.crew.navigation.traffic_patrols)
		var b:=FrontierSpaceTraffic.all(saved.manifest,index,123,saved.crew.navigation.traffic_observers,saved.crew.navigation.traffic_patrols)
		check(a==b,"saved IDs positions and phases reproduce exactly")
	var fixture:=FileAccess.open("/tmp/corporations-sp07/examples.json",FileAccess.WRITE);fixture.store_string(JSON.stringify(examples));fixture.close()
	print("CORPORATE_REGIONS_FAILURES ",failures);quit(1 if failures else 0)
