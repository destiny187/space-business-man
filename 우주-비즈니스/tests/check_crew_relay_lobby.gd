extends SceneTree
var app: FrontierCrewExpedition
var failures:=0
var output:="/tmp/locus-relay-lobby"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):output=argument.trim_prefix("--crew-folder=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	app.connection_options.settings_path=output+"/connection.cfg"
	app.name_input.text="초대 호스트"
	app.connection_options.address.text="ws://127.0.0.1:24680/relay"
	await create_timer(.5).timeout
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	await frame("entry")
	await app.host_world()
	check(app.session.active and app.session.hosting and app.session.invite_code.length()==12,"host invitation")
	await frame("host")
	app.invite_copy.pressed.emit()
	check(DisplayServer.clipboard_get()==app.session.invite_code,"clipboard")
	await app.leave_lobby()
	check(app.lobby.visible and not app.session.active,"leave")
	app.connection_options.code.text="AAAAAAAAAAAA"
	await app.join_world()
	check(not app.session.active and not app.network_busy and app.lobby.visible and "초대 코드" in app.status.value,"invalid code and retry")
	await frame("invalid-code")
	if failures==0:print("PASS relay lobby: invalid code, host, clipboard, leave at 960x640")
	quit(0 if failures==0 else 1)
func frame(label: String) -> void:
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	var screenshot:=root.get_texture().get_image()
	check(screenshot.get_size()==Vector2i(960,640),"actual viewport size")
	screenshot.save_png(output+"/"+label+".png")

func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL "+label)
