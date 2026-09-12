extends "res://tests/check_pirate_play.gd"
func preview_radio(authority: FrontierCrewAuthority) -> void:
	var record:=FrontierSpaceCombat.record(authority.world);record.encounter.warning=1.6
	var start_frame:=Engine.get_process_frames();var death_frame: int=-1
	for frame in 840:
		record=FrontierSpaceCombat.record(authority.world)
		if record.encounter.is_empty():break
		var enemy: Dictionary=record.encounter.enemies[0]
		var aim:=Vector3.FORWARD
		if frame>=480 and float(enemy.hull)>0:
			var nav: Dictionary=authority.world.crew.navigation
			var toward: Vector3=(FrontierSpaceCombat.point(enemy.position)-FrontierSpaceCombat.point(nav.position)).normalized()
			var direction:=FrontierSpaceCombat.point(nav.direction).slerp(toward,.07).normalized();nav.direction=FrontierSpaceCombat.arr(direction)
			var origin:=FrontierSpaceCombat.point(nav.position)+FrontierSpaceCombatPilot.basis(direction)*FrontierSpaceCombat.point(FrontierSpaceCombat.config().presentation.camera)
			aim=(FrontierSpaceCombat.point(enemy.position)-origin).normalized()
		send_controls(aim,frame>=480 and enemy.hull>0)
		if enemy.hull<=0 and death_frame<0:death_frame=frame
		if death_frame>=0 and frame-death_frame>150:break
		if frame==60:
			check(app.flight.combat_view.audio.last_played.has("sfx_pirate_contact_warning"),"dedicated hostile contact warning played")
			check(not app.flight.soundscape.arrival.playing and app.flight.soundscape.pending_tier<0,"interception cancels arrival sound and queue")
		if death_frame>=0 and frame-death_frame in [65,70,77,86,100,120,145]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/pirate-explosion/death-%03d.png"%(frame-death_frame)))
		await process_frame
	var end_frame:=Engine.get_process_frames()
	FileAccess.open(ProjectSettings.globalize_path("res://../output/pirate-explosion/movie.json"),FileAccess.WRITE).store_string(JSON.stringify({"start_frame":start_frame,"end_frame":end_frame,"fps":60,"death_frame":death_frame,"fixture":"actual crew expedition, host input, scripted pilot"}))
	print("PIRATE_MOVIE ",start_frame," ",end_frame," DESTROYED ",death_frame)
	var combat: FrontierSpaceCombatView=app.flight.combat_view
	var alarm_stamp: int=combat.audio.last_played.get("sfx_pirate_contact_warning",0)
	combat.suspend();combat.update(.016,false)
	check(combat.fx.items.is_empty(),"menu clears explosion effects")
	check(combat.audio.last_played.get("sfx_pirate_contact_warning",0)==alarm_stamp,"menu does not replay old contact warning")
	check(death_frame>=0,"host shots destroyed raider and rendered new explosion")
	# A new local-flight encounter must alert too; the same warning must not repeat on menu close.
	authority.world.crew.space_combat.encounter={};authority.world.crew.navigation.combat_active=false
	check(FrontierSpaceCombat.begin(authority.world,"crew","local_transit"),"new local encounter begins")
	app.flight.soundscape.enter(0)
	app.session._publish()
	for i in 20:await process_frame
	check(combat.audio.last_played.get("sfx_pirate_contact_warning",0)>alarm_stamp,"local flight receives its own fresh warning")
	check(not app.flight.soundscape.arrival.playing and app.flight.soundscape.pending_tier<0,"new warning clears previously pending arrival")
	alarm_stamp=combat.audio.last_played.get("sfx_pirate_contact_warning",0)
	combat.suspend();combat.update(.016,false)
	check(combat.audio.last_played.get("sfx_pirate_contact_warning",0)==alarm_stamp,"reopening during warning does not repeat alarm")
	for speaker in combat.audio.get_children():
		if speaker is AudioStreamPlayer and speaker.get_meta("cue","")=="sfx_pirate_contact_warning":check(not speaker.playing,"menu stops warning playback")
	print("EXPLOSION_CHECKS ",checks," FAILURES ",failures)
	await app.session.close_session();app.queue_free();await process_frame;quit(1 if failures else 0)

func until(condition: Callable,label: String,seconds: float=60) -> bool:
	return await super.until(condition,label,maxf(seconds,180))
