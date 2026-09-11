extends "res://tests/check_lotus_play.gd"
## Focused, isolated weather acceptance scene; never edits the player's saves.
var weather_actor: String
var canopy_point:=Vector3.ZERO
var mast_point:=Vector3.ZERO
func run() -> void:
	folder="/tmp/space-weather-play"
	if "--crew-folder=/tmp/space-weather-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("기상 현장 검수",2);weather_actor=owner.character_id
	var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,func(_w):return true),"isolated weather world")
	var world: Dictionary=core.world;var body: Dictionary={}
	for ordinal in range(8,5000):
		var candidate:=FrontierUniverse.body(world.manifest,ordinal)
		if int(candidate.planet_tier)==2 and FrontierPlanetWeather.profile(candidate).hazard=="acid":body=candidate;break
	check(not body.is_empty(),"seeded acid chemistry on a natural T2 planet")
	if body.is_empty():quit(1);return
	print("WEATHER_BODY ",body.id," ",body.traits.id)
	var t1:=body.duplicate(true);t1.planet_tier=1
	check(FrontierPlanetWeather.profile(t1).hazard.is_empty(),"T1 has no weather hazard")
	var vacuum:=body.duplicate(true);vacuum.traits.pressure=0
	check(not FrontierPlanetWeather.profile(vacuum).rain,"vacuum has no precipitation")
	world.location=body.id;world.navigation_target=body.id;world.crew.navigation.system=body.system_ordinal;world.crew.navigation.target=body.ordinal
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(int(body.ordinal),world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))
	world.crew.members[weather_actor].ready=true
	check(FrontierCrewSurface.apply(world,weather_actor,"land",{},{1:weather_actor}).is_empty(),"T2 landing")
	world.business.bags[weather_actor]=FrontierExpeditionBusiness.inventory();world.business.bags[weather_actor].merge({"iron":16,"copper":8,"stone":10},true)
	var field:=FrontierCrewSurface.field(world)
	for kind in ["field_canopy","grounding_mast"]:
		var built:=false
		for i in 640:
			var p:=Vector3(float(i%32)*3-46,0,float(i/32)*3-29);p.y=field.height(p.x,p.z)
			var player:=p+Vector3(8,0,0);player.y=field.height(player.x,player.z)+.15;world.crew.members[weather_actor].position=FrontierExpeditionBusiness.array(player)
			if not FrontierExpeditionBusiness.build_reason(world,weather_actor,kind,p,{1:weather_actor}).is_empty():continue
			var result:=FrontierExpeditionBusiness.apply(world,weather_actor,"business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(p)},{1:weather_actor})
			check(result.is_empty(),"actual build request "+kind+" "+result)
			if kind=="field_canopy":canopy_point=p
			else:mast_point=p
			built=result.is_empty();break
		check(built,"placement and resource cost "+kind)
		if not built:quit(1);return
	var schedule:=FrontierPlanetWeather.ensure_planet(world,body)
	check(float(schedule.next_hazard)>=1500,"first hazard at least 25 minutes away")
	check(FrontierPlanetWeather.canopy(world,canopy_point+Vector3.UP*.1) and not FrontierPlanetWeather.canopy(world,canopy_point+Vector3.UP*4),"roof covers underneath, not rooftop")
	check(not FrontierPlanetWeather.mast(world,mast_point+Vector3.RIGHT*17).is_empty() and FrontierPlanetWeather.mast(world,mast_point+Vector3.RIGHT*19).is_empty(),"mast protection radius")
	var saved_weather: Variant=JSON.parse_string(JSON.stringify(world.weather))
	check(FrontierPlanetWeather.valid(saved_weather),"weather round trip")
	var before: Dictionary=world.weather.duplicate(true);var legacy:=world.duplicate(false);legacy.erase("weather")
	check(not FrontierPlanetWeather.tick(legacy,.25,[weather_actor],Callable(),Callable(),{}) and world.weather==before,"old worlds not migrated by ticking")
	var member: Dictionary=world.crew.members[weather_actor].duplicate(true);var v:=FrontierCrewVitals.ensure(member);v.protection=0;v.health=100;v.shield=20
	FrontierCrewVitals.weather_damage(member,12,false);check(v.health==100 and v.shield==8,"lightning consumes shield first")
	FrontierCrewVitals.weather_damage(member,2,true);check(v.health==98 and v.shield==8,"acid bypasses shield")
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(world),"fixture save "+store.last_error)
	if not store.last_error.is_empty():quit(1);return
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ landing ready",100):quit(1);return
	app.close_menus();app.onboarding.letter.hide();app.outside=false;app.exterior_view.hide();app.if_flight_view()
	var actor: CharacterBody3D=app.actors[weather_actor]
	look(actor,canopy_point+Vector3(8,0,8),canopy_point+Vector3.UP*1.6)
	set_weather("rain",-8)
	await create_timer(3).timeout
	check(app.surface_world.weather_view.drops.multimesh.visible_instance_count>0 and app.surface_world.weather_view.rain.playing,"rain geometry and ElevenLabs loop run")
	check(is_equal_approx(app.surface_world.weather_view.rain.stream.get_length(),7.92),"correct loop duration despite WAV compression")
	await capture("rain-and-canopy")
	set_weather("acid",8);await capture("acid-warning")
	app.open_menu(app.planet_map);app.planet_map.layers.select(3);app.planet_map.update_detail();app.planet_map.canvas.queue_redraw();root.size=Vector2i(960,640);root.content_scale_size=root.size
	await capture("weather-map-960");check(not app.surface_world.weather_view.badge.warning.text.is_empty(),"weather warning remains visible over menu")
	app.close_menus();root.size=Vector2i(1280,800);root.content_scale_size=root.size
	set_weather("acid",-8)
	look(actor,canopy_point+Vector3(0,0,.1),canopy_point+Vector3(0,1.5,-6))
	await create_timer(1).timeout
	check(app.session.authority.weather_presence[weather_actor].sheltered,"actual canopy interior blocks exposure")
	check(not app.session.authority.weather_presence[weather_actor].lightning_sheltered,"open canopy does not provide lightning immunity")
	await capture("under-canopy")
	look(actor,canopy_point+Vector3(8,0,8),canopy_point+Vector3.UP*1.6)
	await create_timer(1).timeout
	await until(func():return app.session.authority.weather_presence[weather_actor].grace<=0 and not app.session.authority.weather_presence[weather_actor].sheltered,"loaded surface finishes its weather grace",25)
	var live:=app.session.authority.world;var presence: Dictionary=app.session.authority.weather_presence[weather_actor]
	presence.grace=0;presence.exposure=12.0
	var health:=float(live.crew.members[weather_actor].vitals.health)
	await create_timer(1.5).timeout
	check(app.session.authority.world.crew.members[weather_actor].vitals.health<health,"host acid exposure reduces health")
	if app.session.authority.world.crew.members[weather_actor].vitals.health>=health:print("ACID_CONTEXT ",app.session.authority.weather_presence[weather_actor]," vitals ",app.session.authority.world.crew.members[weather_actor].vitals," input ",app.session.authority.inputs[1])
	if "--weather-acid-only" in OS.get_cmdline_user_args():
		await app.session.close_session();app.queue_free();await process_frame;print("WEATHER_ACID_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0);return
	var site: Dictionary=FrontierExpeditionBusiness.site(app.session.authority.world)
	var original_air: Array=site.free_terraform.air.duplicate(true)
	for air in site.free_terraform.air:air[2]=8.0
	await create_timer(1.0).timeout
	check(app.session.authority.weather_presence[weather_actor].acid_factor==0.0 and app.surface_world.weather_view.badge.state.event.kind=="rain","restored atmosphere turns acid front into harmless rain")
	await capture("restored-rain")
	FrontierExpeditionBusiness.site(app.session.authority.world).free_terraform.air=original_air
	set_weather("rain",-8)
	app.pitch=1.0;app.test_scan=true
	await create_timer(4).timeout;app.test_scan=false
	check(app.session.authority.world.weather.observations.size()==1,"E sky survey records weather once")
	check(FrontierDiscoveryIndex.page(app.session.authority.world,"","weather","",0).total==1,"journal includes weather observation")
	set_weather("thunder",-8)
	look(actor,mast_point+Vector3(8,0,8),mast_point+Vector3.UP*2.8)
	var event: Dictionary=app.session.authority.world.weather.planets[body.id].event
	event.next_strike=float(event.end)+1
	var at:=mast_point+Vector3.UP*5;event.strikes=[{"id":1,"point":FrontierExpeditionBusiness.array(at),"at":float(app.session.authority.world.weather.clock)+4,"done":false,"grounded":true}]
	await create_timer(1).timeout;await capture("grounded-strike-warning")
	await create_timer(3.05).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/grounding-mast.png")
	check(app.session.authority.weather_presence[weather_actor].grounded,"mast protects live player")
	check(app.surface_world.weather_view.thunder.playing,"ElevenLabs thunder plays on host strike")
	# A second, fixed ungrounded strike exercises the host damage path after warning.
	look(actor,mast_point+Vector3(30,0,0),mast_point+Vector3.UP*2)
	await create_timer(.8).timeout
	app.session.authority.weather_presence[weather_actor].grace=0
	var hit_position: Vector3=actor.position
	var strike_health:=float(app.session.authority.world.crew.members[weather_actor].vitals.health)
	event=app.session.authority.world.weather.planets[body.id].event
	event.strikes.append({"id":2,"point":FrontierExpeditionBusiness.array(hit_position),"at":float(app.session.authority.world.weather.clock)+3,"done":false,"grounded":false})
	await create_timer(3.5).timeout
	check(app.session.authority.world.crew.members[weather_actor].vitals.health<strike_health,"host ungrounded lightning damage after fixed warning")
	var restored: Dictionary=app.session.authority.world.weather.duplicate(true);check(app.session.store.write(app.session.authority.world),"save in-progress front")
	var round_trip: Variant=app.session.store.read_state()
	check(round_trip is Dictionary and round_trip.get("weather",{})==JSON.parse_string(JSON.stringify(restored,"",true,true)),"saved front is unchanged")
	check(FrontierPlanetWeather.valid(restored),"active front and strikes validate")
	await app.session.close_session();app.queue_free();await process_frame
	print("WEATHER_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func set_weather(kind: String,start_offset: float) -> void:
	var world: Dictionary=app.session.authority.world;var row: Dictionary=world.weather.planets[world.location];row.serial+=1
	var clock:=float(world.weather.clock);var p:=canopy_point.lerp(mast_point,.5)
	row.event={"kind":kind,"serial":row.serial,"center":FrontierExpeditionBusiness.array(p),"announced":maxf(0,clock-10),"start":maxf(.1,clock+start_offset),"end":clock+65,"next_strike":clock+6,"strike_serial":0,"strikes":[]}
