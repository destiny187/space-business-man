extends "res://tests/check_pirate_play.gd"
## Real-time current expedition, isolated save. MovieMaker must not be used.
var measurements: Array=[]
var label:="baseline"
var output: String
var settings: FrontierClientSettings
class ActivePresentation extends Node:
	var flight: FrontierCrewFlightView
	func _process(_delta: float) -> void:flight.presentation_blocked=false
func preview_radio(authority: FrontierCrewAuthority) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--measure-label="):label=arg.trim_prefix("--measure-label=")
	output=ProjectSettings.globalize_path("res://../output/pirate-performance")
	DirAccess.make_dir_recursive_absolute(output)
	settings=FrontierClientSettings.ensure(self)
	settings.values=FrontierClientSettings.DEFAULTS.duplicate();settings.values.vsync=false;settings.values.fps=0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--render-scale="):settings.values.scale=float(arg.trim_prefix("--render-scale="));settings.values.upscaler=1
	if "--fast-aa" in OS.get_cmdline_user_args():settings.values.msaa=0;settings.values.fxaa=true
	settings.apply_all()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	if "--full-hd" in OS.get_cmdline_user_args():root.size=Vector2i(1920,1080);root.content_scale_size=root.size
	app.set_process(true);DisplayServer.window_move_to_foreground()
	# Retain all app work; only bypass native focus pausing in this automated probe.
	app.process_priority=-10
	var active_view:=ActivePresentation.new();active_view.flight=app.flight;active_view.process_priority=-5;app.add_child(active_view)
	var e: Dictionary=FrontierSpaceCombat.record(authority.world).encounter;e.warning=120.0
	# Exclude finite index/loading preparation, not regular host or UI work.
	while FrontierStellarRoutes.built<FrontierStellarRoutes.points.size():
		FrontierStellarRoutes.build(app.session.manifest,int(authority.world.crew.navigation.system),1500)
		await process_frame
	for vp in [root,app.space_view]:RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(),true)
	await create_timer(3).timeout
	await measure(authority,"ready",5.0)
	e=FrontierSpaceCombat.record(authority.world).encounter
	e.phase="combat";e.warning=0.0;e.elapsed=0.0
	# Sustain the real three-ship workload without ending from target/player death.
	for enemy in e.enemies:enemy.hull=10000.0;enemy.shield=0.0
	await measure(authority,"combat",14.0)
	if "--capture-stills" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/"+label+"-combat.png")
	await measure(authority,"simultaneous_destruction",4.5)
	check(measurements[1].max_missiles>0 and measurements[1].max_effects>0,"real-time combat includes rendered missiles and effects")
	check(not authority.stopped,"normal host and checkpoint processing stay active")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png")
	var result: Dictionary={"label":label,"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y],"viewport":[app.space_view.size.x,app.space_view.size.y],"settings":settings.values,"samples":measurements,"checks":checks,"failures":failures,"note":"Real-time local host, current crew expedition, scripted aim replaces player input only. Sustained three-ship combat uses high enemy hull and replenished player shield; final host damage destroys all three simultaneously. Navigation index and 3-second warmup excluded. No MovieMaker. GPU timer zero is unavailable. Scene includes current star-system presentation and traffic."}
	FileAccess.open(output+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PIRATE_PERFORMANCE ",JSON.stringify(result))
	await app.session.close_session();app.queue_free();await process_frame;quit(1 if failures else 0)
func measure(authority: FrontierCrewAuthority,phase: String,seconds: float) -> void:
	var times: Array[float]=[];var processes: Array[float]=[];var physics: Array[float]=[]
	var draws:=0.0;var primitives:=0.0;var cpu:=0.0;var gpu:=0.0;var effects:=0;var rockets:=0;var stutters:=0
	var start:=Time.get_ticks_usec();var previous:=start
	var e: Dictionary=FrontierSpaceCombat.record(authority.world).encounter
	if phase=="simultaneous_destruction":
		for enemy in e.enemies:FrontierSpaceCombat.damage_enemy(authority.world,enemy,20000.0,FrontierSpaceCombat.point(authority.world.crew.navigation.position),FrontierSpaceCombat.point(enemy.position))
	while (Time.get_ticks_usec()-start)/1000000.0<seconds:
		e=FrontierSpaceCombat.record(authority.world).encounter
		var nav: Dictionary=authority.world.crew.navigation
		var aim:=Vector3.FORWARD
		if phase=="combat":
			if e.is_empty() or e.phase!="combat":check(false,"host stays in live combat during sample");break
			var enemy: Dictionary=e.enemies[1]
			var target:=FrontierSpaceCombat.point(enemy.position);var p:=FrontierSpaceCombat.point(nav.position)
			var direction:=FrontierSpaceCombat.point(nav.direction).slerp((target-p).normalized(),.06).normalized();nav.direction=FrontierSpaceCombat.arr(direction)
			var camera:=p+FrontierSpaceCombatPilot.basis(direction)*FrontierSpaceCombat.point(FrontierSpaceCombat.config().presentation.camera)
			aim=(target-camera).normalized()
			FrontierSpaceCombat.record(authority.world).ships.crew.shield=100.0
		app.session.send_input(Vector2.ZERO,aim,false,false,[0,0,0,0,1 if phase=="combat" else 0,1,1 if phase=="combat" else 0],0,false)
		await process_frame
		var now:=Time.get_ticks_usec();var ms: float=(now-previous)/1000.0;previous=now;times.append(ms)
		processes.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		if ms>33.333:stutters+=1
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME);primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		cpu+=RenderingServer.viewport_get_measured_render_time_cpu(app.space_view.get_viewport_rid());gpu+=RenderingServer.viewport_get_measured_render_time_gpu(app.space_view.get_viewport_rid())
		effects=maxi(effects,app.flight.combat_view.fx.items.size());rockets=maxi(rockets,app.flight.combat_view.rockets.size())
	var total:=0.0
	for ms in times:total+=ms
	times.sort();processes.sort();physics.sort()
	var n:=times.size();var slow_total:=0.0;var slow_n:=maxi(1,ceili(n*.01))
	for i in range(n-slow_n,n):slow_total+=times[i]
	var row: Dictionary={"phase":phase,"frames":n,"mean_ms":total/n,"fps":1000*n/total,"p95_ms":times[int(n*.95)],"p99_ms":times[int(n*.99)],"one_percent_low_fps":1000*slow_n/slow_total,"max_ms":times[-1],"frames_over_33ms":stutters,"draws":draws/n,"primitives":primitives/n,"render_cpu_ms":cpu/n,"render_gpu_ms":gpu/n if gpu>0 else null,"process_median_ms":processes[n/2],"process_p95_ms":processes[int(n*.95)],"physics_median_ms":physics[n/2],"physics_p95_ms":physics[int(n*.95)],"max_effects":effects,"max_missiles":rockets}
	measurements.append(row);print("PIRATE_MEASURE ",JSON.stringify(row))
