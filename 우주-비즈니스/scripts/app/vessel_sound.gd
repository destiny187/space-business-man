class_name FrontierVesselSound
extends Node
## Playback follows acknowledged navigation, never input requests.
var library: FrontierAudio
var layers: Dictionary={}
var gains: Dictionary={}
var events: Array[AudioStreamPlayer]=[]
var config: Dictionary={}
var previous_mode: String=""
var previous_progress:=0.0
var previous_running:=false
var previous_boost:=false
var previous_brake:=false
var initialized:=false
var stage: String="idle"
var last_event: String=""
var paused:=false
func _ready() -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/space_audio.json")).drive
	library=FrontierAudio.new();add_child(library)
	if AudioServer.get_bus_index("SpaceCabin")<0:
		AudioServer.add_bus();var bus:=AudioServer.bus_count-1;AudioServer.set_bus_name(bus,"SpaceCabin");AudioServer.set_bus_send(bus,"SFX")
		var filter:=AudioEffectLowPassFilter.new();filter.cutoff_hz=float(config.cabin_cutoff_hz);AudioServer.add_bus_effect(bus,filter)
	for key in config.layers:
		var player:=AudioStreamPlayer.new();player.name=key;player.bus="SFX";player.volume_db=-80;player.stream=library.stream(config.layers[key],true);add_child(player);layers[key]=player;gains[key]=0.0
func update(delta: float,nav: Dictionary,thrust: float,turn: Vector2,brake: float,finch: bool,exterior: bool,blocked: bool) -> void:
	paused=blocked
	for event in events:
		if is_instance_valid(event):event.stream_paused=blocked
	for player in layers.values():player.stream_paused=blocked
	if blocked:return
	var jumping: bool=nav.get("mode","")=="jump"
	var progress: float=nav.get("transit",{}).get("progress",0.0)
	var boosting: bool=nav.get("boosting",false)
	var running: bool=thrust>.04
	var target_stage: String="cruise" if running else "idle"
	if brake>.08:target_stage="brake"
	if jumping:target_stage="charge" if progress<.2 else ("departure" if progress<.3 else ("silence" if progress>.94 else "transit"))
	if initialized:
		if jumping and previous_mode!="jump":play_event("sfx_vessel_boost",-20)
		if jumping and previous_mode=="jump" and previous_progress<.2 and progress>=.2:play_event("sfx_vessel_brake",-17,.75)
		if not jumping:
			if running and not previous_running and previous_mode!="jump":play_event("sfx_vessel_boost",-27,1.3 if finch else .8)
			elif not running and previous_running:play_event("sfx_vessel_brake",-26,1.25 if finch else .8)
			if boosting and not previous_boost:play_event("sfx_vessel_boost",-23)
			if brake>.15 and not previous_brake:play_event("sfx_vessel_brake",-27)
	initialized=true;previous_mode=nav.get("mode","");previous_progress=progress;previous_running=running;previous_boost=boosting;previous_brake=brake>.15;stage=target_stage
	var transition_gain:=1.0
	if jumping:
		if progress<.2:transition_gain=lerpf(.12,.8,progress/.2)
		elif progress>.92:transition_gain=1.0-smoothstep(.92,.98,progress)
	var rcs:=clampf(maxf(turn.length()*.5,brake),0,1)
	var targets: Dictionary={
		"reactor":(.07+thrust*.93)*(float(config.finch_bass) if finch else 1.0)*(0.55 if exterior else 1.0),
		"turbine":thrust*(.12 if finch else 1.0),
		"finch":thrust*(1.0 if finch else .12),
		"exhaust":thrust*(1.0 if boosting or jumping else .35)*(1.0 if exterior else .28),
		"attitude":rcs*(1.0 if exterior else .45)}
	for key in layers:
		var player: AudioStreamPlayer=layers[key]
		var target: float=float(targets[key])*transition_gain
		gains[key]=move_toward(float(gains[key]),target,delta/float(config.attack_seconds if target>float(gains[key]) else config.release_seconds))
		player.bus="SFX" if exterior else "SpaceCabin"
		player.pitch_scale=(.82 if key=="reactor" else (1.65 if key=="attitude" else 1.0))+thrust*.17
		if key=="finch":player.pitch_scale=.92+thrust*.28
		if float(gains[key])>.001 and player.stream!=null:
			player.volume_db=float(config.levels_db[key])+linear_to_db(maxf(.0001,gains[key]))
			if not player.playing:player.play(.7 if key=="attitude" else 0.0)
		else:player.stop()
func play_event(id: String,level: float,pitch: float=1.0) -> void:
	if paused:return
	for i in range(events.size()-1,-1,-1):
		if not is_instance_valid(events[i]):events.remove_at(i)
	if events.size()>=4:return
	var player:=AudioStreamPlayer.new();player.stream=library.stream(id);player.bus="SFX";player.volume_db=level;player.pitch_scale=pitch
	if player.stream==null:player.free();return
	add_child(player);events.append(player);player.finished.connect(player.queue_free);player.play();last_event=id
func _exit_tree() -> void:
	for player in layers.values():player.stop();player.stream=null
	for player in events:
		if is_instance_valid(player):player.stop();player.stream=null

func suspend() -> void:
	for player in layers.values():player.stop()
	for player in events:
		if is_instance_valid(player):player.stop();player.queue_free()
	events.clear()
	for key in gains:gains[key]=0.0
	initialized=false
