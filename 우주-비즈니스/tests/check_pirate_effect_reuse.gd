extends "res://tests/check_pirate_play.gd"
func preview_radio(authority: FrontierCrewAuthority) -> void:
	folder=ProjectSettings.globalize_path("res://../docs/production/media/pirate-performance")
	DirAccess.make_dir_recursive_absolute(folder)
	var combat: FrontierSpaceCombatView=app.flight.combat_view
	var e: Dictionary=FrontierSpaceCombat.record(authority.world).encounter;e.warning=100.0
	var nav: Dictionary=authority.world.crew.navigation
	var origin:=FrontierSpaceCombat.point(nav.position)
	e.enemies[1].position=FrontierSpaceCombat.arr(origin+Vector3(0,0,-260))
	var aim: Vector3=(origin+Vector3(0,0,-260)-(origin+Vector3(0,19,62))).normalized()
	var missile_captured:=false;var started:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<5500:
		app.session.send_input(Vector2.ZERO,aim,false,false,[0,0,0,0,0,1,1],0,false)
		await process_frame
		if combat.missile_blasts>0 and not missile_captured:
			missile_captured=true;await capture("missile-burst")
	check(missile_captured and combat.missile_trails>0,"shared material renders real missile trails and host-confirmed burst")
	e=FrontierSpaceCombat.record(authority.world).encounter
	for i in e.enemies.size():
		var enemy: Dictionary=e.enemies[i]
		enemy.position=FrontierSpaceCombat.arr(origin+Vector3((i-1)*60,0,-220));enemy.shield=0.0
	app.session._publish();await create_timer(.2).timeout
	e=FrontierSpaceCombat.record(authority.world).encounter
	for enemy in e.enemies:FrontierSpaceCombat.damage_enemy(authority.world,enemy,2000,origin,FrontierSpaceCombat.point(enemy.position))
	await create_timer(float(FrontierSpaceCombat.config().presentation.corpse_seconds)+.18).timeout
	await capture("three-ship-burst")
	var active_blasts:=0
	for row in combat.fx.items:
		if row.has("blast"):active_blasts+=1
	check(active_blasts>0 and active_blasts+combat.fx.blast_pool.size()==FrontierSpaceCombatEffects.LIMIT,"overlapping explosions remain within the reusable resource budget")
	combat.suspend()
	check(combat.fx.items.is_empty() and combat.fx.blast_pool.size()==FrontierSpaceCombatEffects.LIMIT,"opening a menu returns every burst resource without losing effects")
	check(combat.fx.blast_pool.all(func(node):return not node.visible),"recycled effects stay hidden")
	await app.session.close_session();app.queue_free();await process_frame
	print("PIRATE_EFFECT_REUSE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
