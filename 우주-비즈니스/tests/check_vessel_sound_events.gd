extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var sound:=FrontierVesselSound.new();root.add_child(sound)
	for i in 5:
		sound.play_event("sfx_vessel_brake",-25,3.0)
		await create_timer(1.2).timeout
	assert(sound.last_event=="sfx_vessel_brake")
	var nav: Dictionary={"mode":"jump","transit":{"progress":.6},"boosting":false}
	sound.update(1,nav,1,Vector2.ZERO,0,false,true,false)
	assert(sound.layers.exhaust.playing)
	nav.transit.progress=.99;sound.update(2,nav,1,Vector2.ZERO,0,false,true,false)
	assert(not sound.layers.exhaust.playing and sound.stage=="silence")
	sound.paused=true;sound.play_event("sfx_vessel_boost",-25);assert(sound.last_event=="sfx_vessel_brake")
	print("VESSEL_SOUND_EVENTS: retired one-shots, transit quiet and blocked cues PASS")
	sound.queue_free();await process_frame;quit()
