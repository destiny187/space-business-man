extends "res://tests/check_pirate_play.gd"
var frame_number:=0
var timeline: Array=[]
var captured_phases: Dictionary={}
var capture_effect: AudioEffectCapture
var samples:=PackedVector2Array()
func preview_radio(authority: FrontierCrewAuthority) -> void:
	folder=ProjectSettings.globalize_path("res://../docs/production/media/pirate-quality")
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../output/pirate-quality/frames"))
	print("QUALITY_PREVIEW_READY")
	var record:=FrontierSpaceCombat.record(authority.world)
	record.encounter.warning=.5
	capture_effect=AudioEffectCapture.new();capture_effect.buffer_length=2.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),capture_effect)
	var view: FrontierSpaceCombatView=app.flight.combat_view
	for i in 130:
		send_controls(Vector3.FORWARD,false)
		await create_timer(.1).timeout
		record=FrontierSpaceCombat.record(authority.world)
		var enemy: Dictionary=record.encounter.enemies[0]
		var phase: String=enemy.get("maneuver","warning")
		if not captured_phases.has(phase) and float(enemy.get("maneuver_age",0))>.4:
			captured_phases[phase]=true;await capture("raider-"+phase)
		await frame_capture(enemy)
	check(captured_phases.has("align") and captured_phases.has("strike") and captured_phases.has("break"),"current game renders preparation, attack pass and banked exit")
	check(view.key_light.light_energy>0 and view.models.size()==2,"combat fill reaches actual ship models")
	check(view.audio.last_played.has("sfx_robot_charge"),"weapon charge audio follows the preparation phase")
	check(view.audio.last_played.has("sfx_combat_pulse"),"enemy discharge plays through the flight distance mix")
	check(FrontierSpaceCombat.valid(record),"live maneuvers and projectiles remain save-valid")
	# Fire through the current host input into the raider, then keep the camera on its death motion.
	var wreck_before: int=record.wrecks.size()
	for i in 125:
		record=FrontierSpaceCombat.record(authority.world)
		var enemy: Dictionary=record.encounter.enemies[0]
		var nav: Dictionary=authority.world.crew.navigation
		var direction: Vector3=(FrontierSpaceCombat.point(enemy.position)-FrontierSpaceCombat.point(nav.position)).normalized()
		nav.direction=FrontierSpaceCombat.arr(direction)
		var camera_origin:=FrontierSpaceCombat.point(nav.position)+FrontierSpaceCombatPilot.basis(direction)*FrontierSpaceCombat.point(FrontierSpaceCombat.config().presentation.camera)
		var aim: Vector3=(FrontierSpaceCombat.point(enemy.position)-camera_origin).normalized()
		send_controls(aim,true);await create_timer(.1).timeout
		if i%2==0:await frame_capture(FrontierSpaceCombat.record(authority.world).encounter.enemies[0])
		if view.hit_confirm>0 and not captured_phases.has("hit"):
			captured_phases.hit=true;await capture("pulse-impact")
		if FrontierSpaceCombat.record(authority.world).encounter.enemies[0].hull<=0:break
	record=FrontierSpaceCombat.record(authority.world)
	check(record.wrecks.size()>wreck_before,"actual host fire disables a moving ship and creates one pod")
	for i in 32:
		send_controls(Vector3.FORWARD,false);await create_timer(.1).timeout
		if i in [3,10,16]:await capture("destruction-"+str(i))
		await frame_capture(FrontierSpaceCombat.record(authority.world).encounter.enemies[0])
	check(view.audio.last_played.has(str(FrontierSpaceCombat.config().audio.destroy)),"secondary explosion audio follows the disabled hull delay")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("combat-960")
	view.update(.1,true)
	check(view.fx.items.is_empty() and view.radio.is_empty() and view.key_light.light_energy==0,"menus clear transient combat presentation")
	save_audio()
	FileAccess.open(folder+"/timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline))
	check(await app.session.close_session(),"normal session saves the maneuver state")
	app.queue_free();await process_frame
	print("PIRATE_QUALITY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func frame_capture(enemy: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	if capture_effect!=null:samples.append_array(capture_effect.get_buffer(capture_effect.get_frames_available()))
	var img:=root.get_texture().get_image();img.resize(768,480,Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path("res://../output/pirate-quality/frames/%04d.png"%frame_number))
	timeline.append({"frame":frame_number,"clock":Time.get_ticks_msec(),"phase":enemy.get("maneuver","warning"),"position":enemy.position,"direction":enemy.direction,"roll":enemy.get("roll",0),"windup":enemy.windup,"hull":enemy.hull})
	frame_number+=1

func save_audio() -> void:
	samples.append_array(capture_effect.get_buffer(capture_effect.get_frames_available()))
	var pcm:=PackedByteArray();pcm.resize(samples.size()*4);var peak:=0.0
	for i in samples.size():
		peak=maxf(peak,maxf(absf(samples[i].x),absf(samples[i].y)))
		pcm.encode_s16(i*4,roundi(clampf(samples[i].x,-1,1)*32767));pcm.encode_s16(i*4+2,roundi(clampf(samples[i].y,-1,1)*32767))
	var clip:=AudioStreamWAV.new();clip.format=AudioStreamWAV.FORMAT_16_BITS;clip.stereo=true;clip.mix_rate=roundi(AudioServer.get_mix_rate());clip.data=pcm
	clip.save_to_wav(folder+"/combat-sfx.wav")
	print("COMBAT_SFX_CAPTURE seconds=",float(samples.size())/clip.mix_rate," peak=",peak," discarded=",capture_effect.get_discarded_frames())
	check(peak>.001 and peak<1.0 and capture_effect.get_discarded_frames()==0,"actual SFX bus contains unclipped audio without dropped capture frames")
