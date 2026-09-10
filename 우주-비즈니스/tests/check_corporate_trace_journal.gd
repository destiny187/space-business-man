extends "res://tests/test_solo_entry.gd"
func run() -> void:
	if "--crew-folder=/tmp/corporate-traces-play" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../docs/production/media/corporate-traces")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"saved trace session opens",45):quit(1);return
	app.onboarding.letter.hide();app.close_menus();app.set_process(false);app.session.set_process(false);app.session.set_physics_process(false)
	app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(5);app.survey_journal.refresh();await create_timer(.5).timeout
	app.survey_journal.select(app.survey_journal.selected_entry)
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await create_timer(.6).timeout
	if app.survey_journal.detail_column.get_global_rect().end.x>960:dump_sizes(app.research_frame)
	check(app.survey_journal.detail_column.get_global_rect().end.x<=960,"reselected trace dossier fits narrow display")
	await capture("trace-journal-960")
	var scroll: ScrollContainer=app.survey_journal.detail_column.get_child(0);scroll.scroll_vertical=1000;await capture("trace-journal-detail-960")
	app.queue_free();await process_frame;await process_frame
	print("CORPORATE_TRACE_JOURNAL_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func dump_sizes(node: Node) -> void:
	if node is Control and node.get_combined_minimum_size().x>300:print("LAYOUT ",node.get_path()," size ",node.size," min ",node.get_combined_minimum_size())
	for child in node.get_children():dump_sizes(child)
