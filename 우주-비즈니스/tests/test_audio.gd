extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func run() -> void:
	var audio := FrontierAudio.new()
	root.add_child(audio)
	AudioServer.set_bus_mute(0,true)
	var one_shots: Array[String] = ["sfx_mine_hit_metal","sfx_mine_break","sfx_pickup_resource","sfx_build_place","sfx_build_invalid","sfx_factory_complete","ui_discovery","ui_planet_sold","sfx_combat_pulse","sfx_creature_call"]
	var loops: Array[String] = ["sfx_robot_move","sfx_robot_work","sfx_robot_charge","sfx_terraform_active","amb_barren_wind","amb_restored_nature"]
	for id in one_shots+loops:
		var stream: AudioStream = audio.stream(id,id in loops)
		check(stream != null,"load generated sound "+id)
		if stream == null: continue
		check(stream.get_length() >= 0.3 and stream.get_length() <= 21,"valid sound duration "+id)
		check(stream is AudioStreamWAV and stream.mix_rate == 48000,"PCM48k runtime import "+id)
		if id in loops: check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > 0,"loop configured "+id)
		else:
			audio.play(id)
			check(audio.get_child_count() > 1,"oneshot player spawned "+id)
	var c := FrontierCampaign.new()
	c.persistence_enabled = false
	c.new_campaign()
	c.buy_planet("basalt")
	audio.update_world(c.planet,false)
	check(audio.ambient.playing and audio.ambient_key == "amb_barren_wind","barren ambience plays")
	c.planet.environment.ecology = 60
	audio.update_world(c.planet,false)
	check(audio.ambient.playing and audio.ambient_key == "amb_restored_nature","restored ambience plays")
	audio.update_world(c.planet,true)
	check(audio.ambient.stream_paused,"menus pause ambience")
	audio.update_world({},false)
	check(not audio.ambient.playing and audio.emitters.is_empty(),"leaving planet clears audio")
	await create_timer(0.1).timeout
	audio.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	print("AUDIO_TESTS checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
