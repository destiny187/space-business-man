extends "res://tests/check_pirate_play.gd"
func preview_radio(authority: FrontierCrewAuthority) -> void:
	var out:=ProjectSettings.globalize_path("res://../docs/production/media/pirate-missiles")
	DirAccess.make_dir_recursive_absolute(out)
	var r:=FrontierSpaceCombat.record(authority.world);r.encounter.warning=3.5
	var nav: Dictionary=authority.world.crew.navigation
	var enemy: Dictionary=r.encounter.enemies[1]
	enemy.position=FrontierSpaceCombat.arr(FrontierSpaceCombat.point(nav.position)+Vector3(0,0,-260))
	var combat: FrontierSpaceCombatView=app.flight.combat_view
	var initial_shield: float=enemy.shield
	var start_frame:=Engine.get_process_frames();var max_rockets:=0;var captured_hit:=false;var captured_trail:=false
	for frame in 1000:
		r=FrontierSpaceCombat.record(authority.world)
		if r.encounter.is_empty():break
		nav=authority.world.crew.navigation;enemy=r.encounter.enemies[1]
		var aim:=Vector3.FORWARD
		if float(enemy.hull)>0:
			var toward: Vector3=(FrontierSpaceCombat.point(enemy.position)-FrontierSpaceCombat.point(nav.position)).normalized()
			var direction:=FrontierSpaceCombat.point(nav.direction).slerp(toward,.06).normalized();nav.direction=FrontierSpaceCombat.arr(direction)
			var camera:=FrontierSpaceCombat.point(nav.position)+FrontierSpaceCombatPilot.basis(direction)*FrontierSpaceCombat.point(FrontierSpaceCombat.config().presentation.camera)
			aim=(FrontierSpaceCombat.point(enemy.position)-camera).normalized()
		# First salvo verifies curved launch and impact on a stationary warned target; then the real AI fights.
		app.session.send_input(Vector2.ZERO,aim,false,false,[0,0,0,0,1 if frame>=350 and enemy.hull>0 else 0,1,1 if (30<=frame and frame<42) or (310<=frame and frame<322) or (590<=frame and frame<602) else 0],0,false)
		max_rockets=maxi(max_rockets,combat.rockets.size())
		if frame==48:
			check(combat.missile_mount!=null and max_rockets>0,"current expedition renders launcher and flying missile")
			await still(out,"missile-launch")
		if combat.missile_trails>6 and not captured_trail:
			captured_trail=true;await still(out,"missile-trail")
		if enemy.shield<initial_shield and combat.missile_blasts>0 and not captured_hit:
			captured_hit=true;await still(out,"missile-impact")
			for n in 8:await process_frame
			await still(out,"missile-impact-plume")
		if frame==290:await still(out,"fighters-and-gunship")
		if frame==640:root.size=Vector2i(960,640);root.content_scale_size=root.size;await still(out,"combat-960")
		await process_frame
	check(captured_hit and enemy.shield<initial_shield,"host-confirmed missile impact renders its separate burst")
	check(combat.missile_trails>10 and combat.missile_blasts>0,"flight trails and detonation effects remain connected")
	check(combat.audio.last_played.has("sfx_ship_missile_launch") and combat.audio.last_played.has("sfx_ship_missile_blast"),"ElevenLabs missile launch and burst play in the game")
	check(combat.visible_enemies.any(func(e):return e.kind=="raider"),"fighters remain after the heavy ship is damaged")
	check(combat.hud.status_column.get_child_count()==3 and combat.hud.weapon_column.get_child_count()==2,"ship status icons sit left and both weapon meters sit right")
	# Keep the regular host steering and route UI active to verify the complete escape.
	authority.world.crew.navigation.direction=[0,0,1]
	var broke_out:=false
	for frame in 780:
		app.session.send_input(Vector2.ZERO,Vector3.BACK,false,false,[1,0,0,1,0,1,0],0,false)
		await process_frame
		if FrontierSpaceCombat.can_jump(authority.world):broke_out=true;break
	check(broke_out and FrontierSpaceCombat.record(authority.world).encounter.phase=="combat","real boosted flight opens departure while combat remains active")
	if broke_out:
		app.session._publish();await process_frame;await still(out,"breakout-ready-960")
		var system: int=authority.world.crew.navigation.system;var target: int=-1
		for index in range(5000):
			if index==system or FrontierUniverse.map_position(authority.world.manifest,index).distance_to(FrontierUniverse.map_position(authority.world.manifest,system))>FrontierVesselRefit.stellar_range(authority.world):continue
			var ordinal:=FrontierUniverse.first_ordinal(authority.world.manifest,index)
			if int(FrontierUniverse.body(authority.world.manifest,ordinal).planet_tier)<=2:target=ordinal;break
		app.session.send_request("ready",{"value":true})
		for i in 8:await process_frame
		if target>=0:app.navigation_ui.start_route(target)
		for i in 100:
			await process_frame
			if authority.world.crew.navigation.mode=="jump":break
		check(authority.world.crew.navigation.mode=="jump" and FrontierSpaceCombat.record(authority.world).encounter.phase=="escaped","normal navigation UI commits the other-system jump and confirms escape")
		for i in 70:await process_frame
		await still(out,"stellar-escape-960")
	combat.suspend();check(combat.rockets.is_empty() and combat.fx.items.is_empty() and not combat.armed(),"menu clears missiles and effects and blocks weapons")
	FileAccess.open(ProjectSettings.globalize_path("res://../output/pirate-missiles/movie.json"),FileAccess.WRITE).store_string(JSON.stringify({"start_frame":start_frame,"end_frame":Engine.get_process_frames(),"fps":60,"fixture":"actual crew expedition with host input; first homing salvo fired during warning; then live three-ship combat","maximum_visible_missiles":max_rockets,"missile_trails":combat.missile_trails,"missile_blasts":combat.missile_blasts,"checks":checks,"failures":failures}))
	print("MISSILE_PLAY_CHECKS ",checks," FAILURES ",failures)
	await app.session.close_session();app.queue_free();await process_frame;quit(1 if failures else 0)
func still(out: String,label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+label+".png")
func until(condition: Callable,label: String,seconds: float=60) -> bool:
	return await super.until(condition,label,maxf(seconds,180))
