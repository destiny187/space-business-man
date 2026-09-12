extends "res://tests/check_pirate_play.gd"
func preview_radio(authority: FrontierCrewAuthority) -> void:
	var record:=FrontierSpaceCombat.record(authority.world);record.encounter.warning=.5
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
		await process_frame
	var end_frame:=Engine.get_process_frames()
	FileAccess.open(ProjectSettings.globalize_path("res://../output/pirate-quality/movie.json"),FileAccess.WRITE).store_string(JSON.stringify({"start_frame":start_frame,"end_frame":end_frame,"fps":60,"death_frame":death_frame,"fixture":"actual crew expedition, host input, scripted pilot"}))
	print("PIRATE_MOVIE ",start_frame," ",end_frame," DESTROYED ",death_frame)
	await app.session.close_session();app.queue_free();await process_frame;quit()
