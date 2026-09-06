extends SceneTree
var failures:=0
var app: FrontierCrewExpedition
var folder: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func request(a: FrontierCrewAuthority,peer: int,kind: String,args: Dictionary={}) -> Dictionary:
	return a.request(peer,{"session_id":a.session_id,"sequence":100+int(a.world.crew.revision),"revision":a.world.crew.revision,"kind":kind,"args":args})
func capture(label: String) -> void:
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+label+".png")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	var world:=FrontierUniverse.new_world(7215)
	check(FrontierUniverse.validate_world(world).is_empty(),"new manifest valid")
	check(FrontierUniverse.body_from_id(world.manifest,world.location).name=="지구","new world starts at Earth")
	check(FrontierUniverse.body(world.manifest,999999).system_ordinal==124999,"one million addresses belong to 125000 systems")
	check(FrontierUniverse.body(world.manifest,200)==FrontierUniverse.body(FrontierUniverse.generate(7215),200),"seed reproduces body and orbit")
	check(not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,4)),"Jupiter cannot be landed on")
	check(FrontierUniverse.position(world.manifest,2,0)!=FrontierUniverse.position(world.manifest,2,100),"planet revolves around star")
	var profile:=FrontierPlayerProfile.new(folder+"/domain-profile.json");profile.ensure("호스트")
	var guest:=FrontierPlayerProfile.new(folder+"/guest-profile.json");guest.ensure("참가자")
	var a:=FrontierCrewAuthority.new();check(a.start(world,profile.data.character,func(_w: Dictionary):return true),"authority opens lobby")
	check(not request(a,1,"depart").ok,"world commands blocked in lobby")
	var admitted:=a.admit(2,guest.data.character,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admitted.ok and a.acknowledge(2,a.session_id).ok,"guest admission")
	check(not request(a,1,"start_game").ok,"unready guest blocks start")
	check(request(a,2,"lobby_ready",{"value":true}).ok and not request(a,2,"start_game").ok,"guest can ready but cannot start")
	check(request(a,1,"start_game").ok and a.phase=="playing","host starts prepared session")
	var late:=FrontierPlayerProfile.new(folder+"/late-profile.json");late.ensure("중간 입장")
	admitted=a.admit(3,late.data.character,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admitted.ok and a.acknowledge(3,a.session_id).ok and a.snapshot(3).phase=="playing","late join retains running world")
	a.world.crew.navigation.target=4
	check(FrontierCrewSurface.apply(a.world,a.world.crew.owner_id,"land",{},a.peers).contains("표면"),"host rejects gas landing")
	for id in a.world.crew.members:a.world.crew.members[id].ready=true
	check(FrontierCrewNavigation.apply(a.world,a.world.crew.owner_id,"navigate",{"ordinal":999999},a.peers).is_empty(),"distant address selectable")
	check(FrontierCrewNavigation.apply(a.world,a.world.crew.owner_id,"depart",{},a.peers).is_empty(),"distant departure accepted")
	var safe:=true
	for i in 2000:
		FrontierCrewNavigation.step(a.world,.1)
		if a.world.crew.navigation.mode=="approach" and FrontierCrewWorld.vector(a.world.crew.navigation.position).length()<1200:safe=false
		if a.world.crew.navigation.mode=="idle":break
	check(safe and a.world.location==FrontierUniverse.body_id(a.world.manifest,999999),"flight reaches last planet and avoids star interior")
	check(FrontierUniverse.validate_world(a.world).is_empty(),"travel state remains saveable")
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	check(app.waiting_screen.visible and not app.cabin_root.visible,"separate entry without cabin")
	await capture("entry")
	app.profile.ensure("지구 탐험가")
	check(app.session.host(app.profile,app.world_store,24569,"*",true),"isolated local session")
	check(app.waiting_screen.visible and app.flight==null,"no flight scene before host starts")
	await capture("lobby")
	app.session.send_request("start_game",{})
	await create_timer(.5).timeout
	app.outside=true;app.exterior_view.show();app.if_flight_view()
	check(not app.waiting_screen.visible and app.flight.planets.size()==8,"host start reveals eight orbital bodies")
	check(not app.panel.get_node("Land").disabled,"Earth orbit immediately supports landing")
	await capture("earth")
	app.chart.galaxy=true;app.chart.queue_redraw();await capture("galaxy")
	app.address.text="5";app.select_destination()
	check(app.panel.get_node("Land").disabled,"gas destination disables landing UI")
	# Inspect the gas shader in the actual Forward+ flight viewport.
	var body:=FrontierUniverse.body(app.session.manifest,4)
	var point:=FrontierUniverse.position(app.session.manifest,4,float(app.session.latest.crew.navigation.orbit_time))+Vector3(0,0,FrontierUniverse.radius(body)+1300)
	app.session.authority.world.crew.navigation.position=[point.x,point.y,point.z]
	app.session.authority.world.location=body.id
	await create_timer(.5).timeout;await capture("gas-giant")
	root.size=Vector2i(960,640);await capture("small-window")
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/galaxy-v2.json"))
	check(app.session._valid_manifest(FrontierUniverse.generate(71491,legacy)),"legacy manifest still accepted")
	app.session.authority.world.crew.navigation.target=2
	body=FrontierUniverse.body(app.session.manifest,2)
	point=FrontierUniverse.position(app.session.manifest,2,float(app.session.latest.crew.navigation.orbit_time))+Vector3(0,0,FrontierUniverse.radius(body)+600)
	app.session.authority.world.crew.navigation.position=[point.x,point.y,point.z];app.session.authority.world.location=body.id
	app.session._publish()
	app.travel_action("land")
	var deadline:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline and (app.surface_world==null or not app.surface_world.ready_at(app.actors[app.session.latest.self_id].position)):
		await create_timer(.1).timeout
	check(app.surface_world!=null and app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),"Earth landing loads existing playable surface")
	check(not app.navigation_frame.visible and app.surface_tools.visible,"landing restores direct controls and building tools")
	await capture("earth-surface")
	await app.session.close_session()
	print("GALAXY START FAILURES ",failures)
	quit(1 if failures else 0)
