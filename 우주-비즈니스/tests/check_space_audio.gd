extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var scene:=Node.new();root.add_child(scene)
 var sound:=FrontierSpaceAudio.new();scene.add_child(sound)
 for tier in 5:
  sound.enter(tier);sound.update(.1,false,0)
  assert(sound.arrival.playing and sound.arrival.stream.get_length()>=5.9)
  await create_timer(6.1).timeout
 sound.update(.1,true,.4)
 assert(sound.scan.playing)
 await create_timer(1.9).timeout
 sound.complete()
 assert(not sound.scan.playing)
 await create_timer(2.1).timeout
 for id in ["sfx_vessel_engine","sfx_vessel_boost","sfx_vessel_brake","sfx_stellar_warning"]:
  var audio:=sound.library.stream(id)
  assert(audio!=null and audio.get_length()>1.0)
  sound.library.play(id)
  await create_timer(audio.get_length()+.1).timeout
 sound.blocked=true;sound.enter(4);sound.update(.1,true,.1)
 assert(sound.pending_tier==4 and not sound.scan.playing)
 sound.blocked=false;sound.update(.1,true,.2)
 assert(sound.arrival.playing and sound.scan.playing)
 sound.blocked=true;sound.update(1.0,true,.2)
 assert(sound.arrival.stream_paused and not sound.scan.playing)
 print("SPACE AUDIO: 11 WAVs, tier playback, scan completion and menu suppression OK")
 scene.queue_free();await process_frame;quit()
