extends "res://tests/review_weapon_loot.gd"
func review_inventory() -> void:
	app.session.firearm_event_received.connect(func(event):events.append(event))
	await transaction("equipment_equip",{"slot":2,"item_id":"fixture:pulse_2"})
	if not await until(func():return app.firearm.tool().get("item_id")=="fixture:pulse_2","damage-range weapon equipped",4):quit(1);return
	await create_timer(.5).timeout
	var counts: Array=[]
	for index in 2:
		core.resolve_autonomous(true);reset_target()
		look_at_point(FrontierExplorationIncidents.point(source,Vector3(0,1.45,0)));events.clear()
		await create_timer(.25).timeout;app.firearm.shoot()
		await until(func():return events.any(func(event):return event.get("impact_only",false)),"random damage reaches real ground target",4)
		counts.append(core.world.crew.members[actor_id].loadout.weapon_states["fixture:pulse_2"].get("damage_shots",0))
		await capture("damage-combat-"+str(index));await create_timer(.3).timeout
	check(counts==[1,2],"actual trigger advances one saved roll per shot")
	check(app.feedback.audio.last_played.has("sfx_gun_carbine"),"existing ElevenLabs shot still plays")
	await super.review_inventory()
