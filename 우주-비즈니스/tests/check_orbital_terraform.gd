extends "res://tests/test_crew_surface.gd"
var folder:=ProjectSettings.globalize_path("res://../docs/production/media/orbital-terraforming")
func capture(name_value: String) -> void:
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800)
	var profile:=FrontierPlayerProfile.new_character("궤도 복원 확인",0)
	var core:=FrontierCrewAuthority.new()
	check(core.start(FrontierUniverse.new_world(71503),profile,persist),"isolated host world")
	core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"));core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings)
	var body: Dictionary={}
	for ordinal in range(8,5000):
		var candidate:=FrontierUniverse.body(core.world.manifest,ordinal)
		if candidate.traits.id=="oxidized" and int(candidate.planet_tier)==1 and FrontierStarVisual.appearance(FrontierUniverse.system(core.world.manifest,int(candidate.system_ordinal))).id=="yellow":body=candidate;break
	if body.is_empty():check(false,"T1 specimen");quit(1);return
	core.world.location=body.id;core.world.crew.landing={"body_id":body.id,"epoch":1}
	core.world.crew.navigation.target=body.ordinal;core.world.crew.navigation.system=body.system_ordinal
	core.world.crew.members[profile.character_id].position=FrontierCrewSurface.config().ship_position.duplicate()
	core.world.crew.members[profile.character_id].area="surface";core.world.crew.members[profile.character_id].aboard=false
	var site:=FrontierExpeditionBusiness.ensure_site(core.world)
	check(FrontierOrbitalTerraform.describe(body,site).is_empty(),"unworked world retains native appearance")
	site.state="active";core.world.business.active=body.id;FrontierCoopWorkload.activate(site,body,1)
	var view:=FrontierCrewFlightView.new();view.state={"manifest":core.world.manifest};root.add_child(view)
	var nav:=FrontierCrewNavigation.create(core.world);nav.system=body.system_ordinal;nav.target=body.ordinal;nav.orbit_time=0.0
	var target:=FrontierUniverse.position(core.world.manifest,body.ordinal)
	var offset:=(-target.normalized()+Vector3(0,.25,0)).normalized();var radius:=FrontierUniverse.radius(body)
	var point:=target+offset*radius*3.1
	nav.position=FrontierExpeditionBusiness.array(point);nav.direction=FrontierExpeditionBusiness.array(-offset)
	view.update_navigation(nav);view.scan_enabled=false;view.transit_overlay.hide()
	await create_timer(.6).timeout;view.set_process(false)
	view.update_orbits(0.0)
	view.ship.position=point;view.ship.basis=view._flight_basis(-offset)
	await capture("before")
	# Prepared climate/cells; settlement and publication use the real domain and host snapshot.
	var extent:=float(site.free_terraform.rules.extent)
	var local_direction: Vector3=view.planets[body.ordinal].node.basis.orthonormalized().inverse()*offset
	var location:=Vector2(atan2(local_direction.x,local_direction.z)/PI*extent,local_direction.y*extent)
	FrontierFreeTerraform.ensure_cells(site,body,location,48)
	for air in site.free_terraform.air:air[0]=.21;air[1]=1.0;air[2]=0.0
	for c in site.free_terraform.cells.values():
		c.environment={"oxygen":.21,"pressure":1.0,"toxicity":0.0,"temperature":18.0,"water":85.0,"ecology":25.0,"stable_seconds":0.0};c.restoration2={"soil":70.0,"salinity":0.0};c.treated=true
	FrontierFreeTerraform.finish(site,35)
	var partial: Dictionary=core.snapshot().orbital_terraform
	check(partial.has(body.id) and not partial[body.id].completed,"host publishes actual work before settlement")
	view.update_terraforming(partial);await capture("recovering")
	for c in site.free_terraform.cells.values():c.environment.ecology=85.0
	FrontierFreeTerraform.finish(site,1)
	var error:=FrontierExpeditionBusiness.apply(core.world,profile.character_id,"business_settle",{"retain":false},core.peers)
	check(error.is_empty(),"real successful settlement: "+error)
	var committed: Dictionary=core.snapshot().orbital_terraform
	check(committed.has(body.id) and committed[body.id].completed,"settled transferred world remains visible")
	view.update_terraforming(committed);await capture("restored")
	var mesh: MeshInstance3D=view.planets[body.ordinal].node
	check(int(mesh.material_override.get_shader_parameter("terraform_count"))>0,"actual flight surface uses restored state")
	var cloud:=mesh.get_node("OrbitalCloudLayer") as MeshInstance3D
	check(cloud!=null and int(cloud.material_override.get_shader_parameter("terraform_count"))>0,"cloud shell follows restored state")
	var serialized:=JSON.stringify(core.world)
	var output:=FileAccess.open(folder+"/world.json",FileAccess.WRITE);output.store_string(serialized);output.close()
	var restored: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/world.json"))
	check(FrontierExpeditionBusiness.validate(restored.business,restored.manifest).is_empty(),"existing business save validates")
	var reloaded:=FrontierOrbitalTerraform.new().summaries(restored)
	check(FrontierUniverse.fingerprint(reloaded)==FrontierUniverse.fingerprint(committed),"disk reload reproduces presentation without save migration")
	if FrontierUniverse.fingerprint(reloaded)!=FrontierUniverse.fingerprint(committed):print("ROUNDTRIP_DIAGNOSTIC ",committed,"\n",reloaded)
	var before_read:=JSON.stringify(restored);FrontierOrbitalTerraform.new().summaries(restored)
	check(before_read==JSON.stringify(restored),"presentation does not alter saved geography or rewards")
	var retained: Dictionary=site.duplicate(true);retained.state="supply";retained.settlement.retained=true
	check(FrontierOrbitalTerraform.describe(body,retained).completed,"retained settlement included")
	var legacy: Dictionary=site.duplicate(true);legacy.erase("free_terraform");legacy.erase("regions");legacy.environment=site.free_terraform.cells.values()[0].environment.duplicate()
	check(FrontierOrbitalTerraform.describe(body,legacy).completed,"legacy local contract included")
	check(FrontierOrbitalTerraform.describe(FrontierUniverse.body(core.world.manifest,3),legacy).is_empty(),"authored restored Mars is preserved")
	view._load_system(int(body.system_ordinal));view.update_terraforming(reloaded)
	check(int(view.planets[body.ordinal].node.material_override.get_shader_parameter("terraform_count"))>0,"revisit rebuild retains restoration")
	view.ship.position=target+offset*radius*13.0;view.ship.basis=view._flight_basis(-offset)
	await capture("restored-far")
	check(view.planets[body.ordinal].node.get_node("OrbitalLOD").distant,"far LOD retains material")
	print("ORBITAL_TERRAFORM checks=%d failures=%d body=%d"%[checks,failures,int(body.ordinal)])
	var report:=FileAccess.open(folder+"/verification.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures,"ordinal":body.ordinal,"fixture":"prepared climate and cells; real settlement, host publication and disk roundtrip"},"\t"));report.close()
	view.queue_free();await process_frame;quit(1 if failures else 0)
