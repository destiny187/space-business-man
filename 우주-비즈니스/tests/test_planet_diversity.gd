extends SceneTree
var failed:=false
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failed=true
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var m:=FrontierUniverse.generate(91723)
	var samples: Dictionary={};var colors: Dictionary={};var mixed:=false
	for i in range(8,180):
		var body:=FrontierUniverse.body(m,i)
		samples[body.traits.id]=body;colors[body.traits.dust]=true
		if not body.mineral_profile.is_empty() and "+" in body.mineral_profile.name:mixed=true
	check(samples.size()==FrontierPlanetTraits.rules().archetypes.size() and colors.size()>50,"configured archetypes and seeded palettes")
	check(mixed,"mixed geological profiles")
	check(FrontierUniverse.fingerprint(FrontierUniverse.body(JSON.parse_string(JSON.stringify(m)),19))==FrontierUniverse.fingerprint(FrontierUniverse.body(m,19)),"save/load reproduces traits and resource rules")
	var body: Dictionary=samples.volcanic
	var site: Dictionary={"center":[0,0,0],"environment":{"temperature":body.traits.temperature,"pressure":body.traits.pressure,"oxygen":body.traits.oxygen,"toxicity":body.traits.toxicity,"water":0,"ecology":0,"stable_seconds":0},"buildings":{"cooler":{"type":"thermal","active":true}},"inventory":{"ice":0}}
	var vein: Dictionary={"position":[20,0,0],"required_tier":2}
	check(FrontierExpeditionBusiness.thermal_locked(body,site,vein),"hot deposits locked")
	var world: Dictionary={"manifest":m,"location":body.id}
	FrontierExpeditionIndustry.environment(world,site,2000)
	check(not FrontierExpeditionBusiness.thermal_locked(body,site,vein),"actual thermal facility unlocks cooled deposits")
	vein.position=[100,0,0]
	check(FrontierExpeditionBusiness.thermal_locked(body,site,vein),"cooling does not unlock outside development zone")
	var legacy:=m.duplicate(true);legacy.settings.erase("planet_rules")
	check(FrontierUniverse.body(legacy,19).terrain_traits.is_empty(),"old saves preserve ground geometry")
	var field:=FrontierTerrainField.new();field.configure(int(samples.continental.streams.terrain),[],24,samples.continental.terrain_traits)
	check(is_equal_approx(field.height(0,0),2),"landing platform remains safe")
	var ecology:=FrontierEcology.create()
	FrontierEcology.ensure_planet(ecology,body)
	check(is_equal_approx(float(ecology.planets[body.id].profile.temperature),float(body.traits.temperature)),"native ecology shares new planet climate")
	check(FrontierEcology.validate(JSON.parse_string(JSON.stringify(ecology)),JSON.parse_string(JSON.stringify(m))).is_empty(),"new ecology survives save/load")
	if failed:quit(1);return
	if "--rules-only" in OS.get_cmdline_user_args():quit();return
	# Render the exact flight loader's meshes/materials, arranged for comparison.
	root.size=Vector2i(1440,960)
	var view:=FrontierCrewFlightView.new();view.state={"manifest":m};root.add_child(view)
	view.ship.hide();view.ui_root.hide();view.transit_overlay.hide()
	var board:=Node3D.new();view.add_child(board)
	var ids: Array=FrontierPlanetTraits.rules().archetypes.keys()
	for index in ids.size():
		var b: Dictionary=samples[ids[index]]
		view._load_system(int(b.system_ordinal))
		var node: Node3D=view.planets[int(b.ordinal)].node
		view.planets.erase(int(b.ordinal));node.reparent(board)
		node.position=Vector3((index/3-2)*2.5,(1-index%3)*2.55,0);node.scale=Vector3.ONE*.94
	for entry in view.planets.values():entry.node.hide()
	view.system_art.hide()
	if view.galactic_core!=null:view.galactic_core.hide()
	var camera:=Camera3D.new();view.add_child(camera);camera.position=Vector3(0,0,20);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=13.2;camera.current=true
	await process_frame
	for i in 12:await process_frame
	var out:=ProjectSettings.globalize_path("res://../docs/production/media/planet-diversity")
	DirAccess.make_dir_recursive_absolute(out)
	root.get_texture().get_image().save_png(out+"/godot-variants.png")
	print("PASS rendered flight variants")
	view.queue_free();await process_frame;quit()
