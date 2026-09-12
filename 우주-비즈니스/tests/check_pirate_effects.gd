extends "res://tests/check_pirate_play.gd"
func preview_radio(authority: FrontierCrewAuthority) -> void:
	folder=ProjectSettings.globalize_path("res://../docs/production/media/pirate-quality")
	var e: Dictionary=FrontierSpaceCombat.record(authority.world).encounter;e.warning=.2
	var view: FrontierSpaceCombatView=app.flight.combat_view
	for i in 50:
		send_controls(Vector3.FORWARD,false);await create_timer(.1).timeout
	await capture("final-attack")
	# Show a shield wave attached to a banking, moving enemy from a host fire result.
	var enemy: Dictionary=FrontierSpaceCombat.record(authority.world).encounter.enemies[0]
	var nav: Dictionary=authority.world.crew.navigation
	var direction: Vector3=(FrontierSpaceCombat.point(enemy.position)-FrontierSpaceCombat.point(nav.position)).normalized()
	nav.direction=FrontierSpaceCombat.arr(direction)
	await create_timer(.35).timeout
	enemy=FrontierSpaceCombat.record(authority.world).encounter.enemies[0];nav=authority.world.crew.navigation
	direction=(FrontierSpaceCombat.point(enemy.position)-FrontierSpaceCombat.point(nav.position)).normalized();nav.direction=FrontierSpaceCombat.arr(direction)
	var camera_origin:=FrontierSpaceCombat.point(nav.position)+FrontierSpaceCombatPilot.basis(direction)*FrontierSpaceCombat.point(FrontierSpaceCombat.config().presentation.camera)
	var aim: Vector3=(FrontierSpaceCombat.point(enemy.position)-camera_origin).normalized()
	send_controls(aim,true);await create_timer(.12).timeout;send_controls(aim,false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/final-shield-hit.png")
	var follows:=false
	for row in view.fx.items:
		if row.has("shield") and is_instance_valid(row.get("follow")):follows=true
	check(follows,"live shield ripple follows its moving ship transform")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("final-960")
	var record:=FrontierSpaceCombat.record(authority.world)
	var key: String="enemy:"+str(record.encounter.id)+":"+str(record.encounter.enemies[0].id)
	FrontierSpaceCombat.finish(authority.world,"escaped");app.session._publish()
	var before: Vector3=view.models[key].root.position
	for i in 10:send_controls(Vector3.FORWARD,false);await create_timer(.1).timeout
	var distance: float=view.models[key].root.position.distance_to(before)
	check(distance>60 and distance<450,"withdrawal advances from a fixed trajectory without accumulating frame offsets")
	view.suspend();var silent:=true
	for speaker in view.audio.get_children():
		if speaker is AudioStreamPlayer3D and speaker.playing:silent=false
	check(silent,"menu stops both transient shots and looping charge voices")
	check(await app.session.close_session(),"effect review closes through normal save")
	app.queue_free();await process_frame;print("PIRATE_EFFECT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
