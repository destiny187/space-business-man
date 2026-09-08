extends "res://tests/test_solo_entry.gd"
## Reproduce the guide overlapping body/inventory controls using an isolated A04 save.
func run() -> void:
	folder="/tmp/augmentation-a04"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/augmentation-a04" not in OS.get_cmdline_user_args():quit(1);return
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.surface_world!=null and not has_meta("startup_loader") and not app.arrival.active,"isolated saved field",60):quit(1);return
	if not app.test_mode or app.world_store.path!=folder+"/world.json":printerr("ISOLATION_MISMATCH");quit(1);return
	app.onboarding.letter.hide();app.close_menus();app.session.send_request("equipment_select",{"slot":0});app.onboarding.progress={"eligible":true,"complete":false,"inventory":false}
	await create_timer(.2).timeout
	check(app.onboarding.card.visible,"guide enabled before inventory")
	app.toggle_inventory();app.inventory_panel.tabs.current_tab=3;await create_timer(.2).timeout
	check(not app.onboarding.card.visible and app.onboarding.progress.inventory,"body screen hides guide and records equipment visit")
	await capture("body-guide-fixed-960")
	app.close_menus();await create_timer(.2).timeout
	check(app.onboarding.card.visible and app.onboarding.step=="mine","closing inventory resumes next relevant field hint")
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	print("INVENTORY_GUIDE ",checks," FAILURES ",failures);quit(1 if failures else 0)
