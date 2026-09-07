extends SceneTree
var app: FrontierCrewExpedition
func _initialize() -> void:run.call_deferred()
func run() -> void:
	if not "--crew-ui-test" in OS.get_cmdline_user_args() or not str(OS.get_cmdline_user_args()).contains("--crew-folder="):quit(2);return
	root.size=Vector2i(960,640)
	for round_value in 2:
		app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
		app.start_solo(round_value==0)
		await create_timer(.4).timeout
		app.onboarding.letter.hide()
		for frame in [app.navigation_frame,app.inventory_panel,app.business_panel,app.shipyard_panel,app.research_frame]:frame.hide()
		app.outside=false;app.exterior_view.hide();app.if_flight_view()
		await create_timer(.3).timeout
		assert(app.chart!=null,"navigation builds in fresh cabin")
		var id: String=app.session.latest.self_id
		var motion: Dictionary=app.session.authority.motions[id]
		assert(int(motion.jump_serial)==0,"motion resets on saved-world reopen")
		app.test_jump=true
		await create_timer(.3).timeout
		assert(int(motion.jump_serial)==1,"current solo route jumps")
		app.test_jump=false
		await create_timer(1.0).timeout
		assert(motion.grounded,"solo lands")
		await app.session.close_session();app.queue_free();await process_frame
	print("LOCOMOTION_STARTUP_PASS: 960x640 fresh cabin, jump, landing, saved-world reopen; no stale motion")
	quit()
