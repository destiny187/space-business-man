extends "res://tests/test_solo_entry.gd"
var save_folder: String="/tmp/orbital-ports-play"
func request(kind: String,args: Dictionary={}) -> Dictionary:
	var core:=app.session.authority;var actor: String=core.peers[1]
	return core.request(1,{"session_id":core.session_id,"sequence":int(core.world.crew.members[actor].last_sequence)+1,"revision":core.world.crew.revision,"kind":kind,"args":args})
func run() -> void:
	if "--crew-folder=/tmp/orbital-ports-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	if "--trade-review" in OS.get_cmdline_user_args():await review_trade();return
	folder=ProjectSettings.globalize_path("res://../docs/production/media/corporate-space");DirAccess.make_dir_recursive_absolute(folder);DirAccess.make_dir_recursive_absolute(save_folder)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("궤도 항만 확인",2)
	var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true),"new port world")
	var world: Dictionary=core.world;var m: Dictionary=world.manifest
	var legacy: Dictionary=m.duplicate(true);legacy.settings.erase("corporate_space")
	var sp03: Dictionary=m.duplicate(true);sp03.settings.corporate_space.erase("ports")
	check(FrontierSpaceStation.all(legacy,0).is_empty() and FrontierSpaceStation.all(sp03,0).is_empty(),"legacy and SP03 saved worlds gain no ports")
	check(FrontierSpaceStation.all(m,0).size()==2,"two fixed endpoints")
	check(FrontierSpaceStation.definition(m,FrontierUniverse.system_index(m,FrontierCrewNavigation.first_destination(m))).is_empty(),"introductory destination excluded")
	var other: Dictionary={}
	for i in range(1,100):
		other=FrontierSpaceStation.definition(m,i)
		if not other.is_empty():break
	check(not other.is_empty() and FrontierSpaceStation.definition(m,int(other.id),int(other.id)).is_empty(),"actual first destination exclusion retained")
	var station:=FrontierSpaceStation.definition(m,0,-1,0,"solar_mars_port")
	var later:=FrontierSpaceStation.definition(m,0,-1,100,"solar_mars_port")
	check(FrontierCrewWorld.vector(station.position).distance_to(FrontierCrewWorld.vector(later.position))>100,"port follows orbital epoch")
	var offers:=FrontierSpaceStation.market(m,0,station.id)
	for id in offers.prices:check(maxi(1,floori(int(offers.prices[id])*float(offers.sale_ratio)))<int(FrontierLotusSupport.config().prices[id]),"no paid Lotus resale profit "+id)
	var nav: Dictionary=world.crew.navigation
	var point:=FrontierCrewWorld.vector(station.position)+Vector3(0,700,2900)
	nav.position=FrontierExpeditionBusiness.array(point);nav.direction=FrontierExpeditionBusiness.array((FrontierCrewWorld.vector(station.position)-point).normalized());nav.manual=true;nav.target=3
	world.flight_position=nav.position.duplicate();world.business=FrontierExpeditionBusiness.create();world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory();world.business.credits=2000;world.business.bags[owner.character_id].iron=10
	var store:=FrontierWorldStore.new(save_folder+"/world.json");check(store.write(world),"isolated fixture saved "+store.last_error)
	var profile:=FrontierPlayerProfile.new(save_folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current Forward+ flight",45):quit(1);return
	app.onboarding.letter.hide();app.close_menus();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	app.outside=true;app.exterior_view.show();app.if_flight_view();app.flight.transit_overlay.arrival_age=100
	await create_timer(.7).timeout
	check(app.flight.station_models.size()==2,"both actual station models loaded")
	app.approach_trade_station("solar_mars_port")
	check(app.session.latest.crew.navigation.get("station_id")=="solar_mars_port" and app.session.latest.crew.navigation.mode=="approach","explicit port approach accepted")
	await capture("mars-port-approach")
	if not await until(func():return app.session.latest.crew.navigation.mode=="idle","natural approach reaches relative stop",30):quit(1);return
	check(app.session.latest.crew.navigation.get("station_docked")=="solar_mars_port" and FrontierSpaceStation.available(app.session.authority.world),"docked in trade range")
	check(FrontierCorporations.records(app.session.authority.world).has("space_y"),"real port encounter records Space Y")
	app.open_trade_station();check(app.station_market.visible,"F trade panel opens")
	check(app.station_market.hum.playing,"existing ElevenLabs station ambience")
	check(not app.station_market.service_tabs.ships.visible and (not app.station_market.service_tabs.has("blueprints") or not app.station_market.service_tabs.blueprints.visible),"solar port sells only basic goods")
	var initial_iron:=int(app.session.latest.inventory.get("iron",0))
	app.station_market.selected="iron";app.station_market.quantity.value=3;app.station_market.refresh_detail();app.station_market.send("station_buy")
	check(not app.station_market.pending and int(app.session.latest.inventory.iron)==initial_iron+3 and int(app.session.latest.station.credits)==1970,"host buy inventory credit and acknowledgment")
	app.station_market.quantity.value=2;app.station_market.send("station_sell")
	check(int(app.session.latest.inventory.iron)==initial_iron+1 and int(app.session.latest.station.stock.iron)==79 and int(app.session.latest.station.credits)==1978,"host sale finite stock and funds")
	check(app.station_market.audio.last_played.has(FrontierSpaceStation.config().audio.trade),"successful host trade sound")
	var before: Dictionary=app.session.authority.world.duplicate(true)
	check(not request("station_buy",{"station":"solar_earth_logistics","item":"iron","amount":1}).ok,"other port cannot trade remotely")
	check(not request("station_buy",{"station":"solar_mars_port","item":"hull:swift","amount":1}).ok,"solar ship offer cannot be forged")
	check(not request("station_blueprint",{"station":"solar_mars_port","item":"pressure_chamber_mk3","amount":1}).ok,"solar blueprint request denied")
	var trial: Dictionary=before.duplicate(true);trial.business.bags[owner.character_id].iron=500
	check(not FrontierSpaceStation.apply(trial,owner.character_id,"station_sell",{"station":"solar_mars_port","item":"iron","amount":200},{1:owner.character_id}).is_empty(),"bounded port purchasing capacity")
	var drift: Dictionary=before.duplicate(true);FrontierCrewNavigation.step(drift,120)
	check(FrontierSpaceStation.available(drift) and FrontierUniverse.validate_world(drift).is_empty(),"120 seconds orbit drift keeps relative dock and valid save")
	FrontierCrewNavigation.steer(drift,[1,0,0,0],.1);check(not drift.crew.navigation.has("station_docked"),"manual thrust releases docking")
	await capture("mars-port-market")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("mars-port-market-960")
	check(app.station_market.sell.get_global_rect().end.y<=640 and app.station_market.money.get_global_rect().end.x<=960,"market fits 960x640")
	app.close_menus();root.size=Vector2i(1280,800);root.content_scale_size=root.size
	# Capture each real asset close enough to inspect its brand and mechanics.
	for id in FrontierOrbitalPorts.BODIES:
		world=app.session.authority.world;nav=world.crew.navigation;nav.erase("station_docked");nav.station_target=false;nav.speed=0
		station=FrontierSpaceStation.definition(m,0,-1,float(nav.orbit_time),id)
		point=FrontierCrewWorld.vector(station.position)+Vector3(440,360,650)
		nav.position=FrontierExpeditionBusiness.array(point);nav.direction=FrontierExpeditionBusiness.array((FrontierCrewWorld.vector(station.position)-point).normalized());world.flight_position=nav.position.duplicate()
		app.session._publish();app.flight.ship.position=point;app.flight.ship.basis=app.flight._flight_basis(FrontierCrewWorld.vector(nav.direction));app.flight.scan_enabled=false;app.flight.transit_overlay.scan_body={}
		await create_timer(.7).timeout;await capture(id+"-game")
		if id=="solar_earth_logistics":
			app.open_trade_station();app.station_market.selected="iron";app.station_market.quantity.value=1;app.station_market.refresh_detail();app.station_market.send("station_buy")
			check(app.session.latest.station.id==id and int(app.session.latest.station.stock.iron)==99,"Earth independent market transaction")
			check(int(app.session.authority.world.station_markets.solar_mars_port.iron)==79,"Earth transaction preserves Mars stock")
			await capture("earth-port-market");app.close_menus()
	app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(5);app.survey_journal.refresh();await create_timer(.2).timeout
	var entries:=FrontierDiscoveryIndex.page(app.session.authority.world,"Space Y","corporation","",0)
	check(entries.total==1,"Space Y first encounter appears once in journal")
	app.survey_journal.select(entries.entries[0]);await capture("space-y-port-journal");app.close_menus()
	var expected:=FrontierUniverse.fingerprint(app.session.authority.world.station_markets)
	check(await app.session.close_session(),"port transactions saved")
	var saved:=FrontierWorldStore.new(save_folder+"/world.json").read_state()
	check(not saved.is_empty() and FrontierUniverse.fingerprint(saved.station_markets)==expected,"both endpoint stocks reload unchanged")
	app.queue_free();await process_frame;await process_frame
	print("ORBITAL_PORT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

func review_trade() -> void:
	folder=ProjectSettings.globalize_path("res://../docs/production/media/corporate-space")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"saved port resumes",45):quit(1);return
	app.onboarding.letter.hide();app.close_menus();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	app.open_trade_station();check(app.station_market.visible,"saved orbital hold remains in market range")
	var initial_iron:=int(app.session.latest.inventory.get("iron",0));var credit:=int(app.session.latest.station.credits);var stock:=int(app.session.latest.station.stock.iron)
	app.station_market.selected="iron";app.station_market.quantity.value=3;app.station_market.refresh_detail();app.station_market.send("station_buy")
	check(not app.station_market.pending and int(app.session.latest.inventory.iron)==initial_iron+3 and int(app.session.latest.station.stock.iron)==stock-3 and int(app.session.latest.station.credits)==credit-30,"buy changes actual resumed inventory stock and money")
	app.station_market.quantity.value=2;app.station_market.send("station_sell")
	check(int(app.session.latest.inventory.iron)==initial_iron+1 and int(app.session.latest.station.stock.iron)==stock-1 and int(app.session.latest.station.credits)==credit-22,"sell changes actual resumed inventory stock and money")
	await capture("earth-port-market");app.close_menus()
	app.toggle_navigation();app.chart.galaxy=false;app.chart.system_index=0;app.chart.reset_view();await create_timer(.5).timeout
	var ids: Array=[]
	for hit in app.chart.hits:
		if hit.has("station_id"):ids.append(hit.station_id)
	check("solar_mars_port" in ids and "solar_earth_logistics" in ids,"map exposes both independently selectable endpoints")
	await capture("solar-ports-map");app.close_menus()
	app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(5);app.survey_journal.refresh();await create_timer(.2).timeout
	var entries:=FrontierDiscoveryIndex.page(app.session.authority.world,"Space Y","corporation","",0)
	app.survey_journal.select(entries.entries[0]);await capture("space-y-port-journal");app.close_menus()
	check(await app.session.close_session(),"resumed port save")
	app.queue_free();await process_frame;await process_frame
	print("ORBITAL_PORT_REVIEW_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
