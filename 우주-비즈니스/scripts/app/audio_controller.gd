class_name FrontierAudio
extends Node

var streams: Dictionary = {}
var emitters: Dictionary = {}
var last_played: Dictionary = {}
var ambient: AudioStreamPlayer
var ambient_key: String = ""
var suction: AudioStreamPlayer
var survey: AudioStreamPlayer

func _exit_tree() -> void:
	for speaker in get_children():
		if speaker is AudioStreamPlayer or speaker is AudioStreamPlayer3D:
			speaker.stop()
			speaker.stream = null
	streams.clear()
	emitters.clear()

func _ready() -> void:
	for bus_name in ["SFX","Ambience","UI","Voice","Music"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
	ambient = AudioStreamPlayer.new()
	ambient.bus = "Ambience"
	ambient.volume_db = -20
	add_child(ambient)

func set_suction(strength: float) -> void:
	if strength <= 0.01:
		if is_instance_valid(suction): suction.stop()
		return
	if not is_instance_valid(suction):
		suction = AudioStreamPlayer.new()
		suction.bus = "SFX"
		suction.stream = stream("sfx_terraform_active",true)
		suction.pitch_scale = 1.25
		add_child(suction)
	suction.pitch_scale = lerpf(.78,1.18,strength)
	suction.volume_db = -19+linear_to_db(maxf(0.01,strength))
	if not suction.playing: suction.play()

func set_survey(progress: float) -> void:
	if progress<=0:
		if is_instance_valid(survey):survey.stop()
		return
	if not is_instance_valid(survey):
		survey=AudioStreamPlayer.new();survey.bus="SFX"
		survey.stream=stream("sfx_robot_charge",true);add_child(survey)
	survey.pitch_scale=lerpf(.85,1.35,progress)
	survey.volume_db=-27
	if not survey.playing:survey.play()

func stream(id: String,looped: bool = false) -> AudioStream:
	var key: String = id+str(looped)
	if streams.has(key): return streams[key]
	var path: String = "res://assets/audio/"+id+".mp3"
	if ResourceLoader.exists("res://assets/audio/"+id+".wav"): path = "res://assets/audio/"+id+".wav"
	if not ResourceLoader.exists(path): return null
	var audio: AudioStream = load(path).duplicate()
	if audio is AudioStreamMP3: audio.loop = looped
	if audio is AudioStreamWAV:
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
		audio.loop_begin = 0
		audio.loop_end = roundi(audio.get_length()*audio.mix_rate)
	streams[key] = audio
	return audio

func play(id: String,location: Vector3 = Vector3.INF) -> void:
	var now: int = Time.get_ticks_msec()
	var cooldown: int = 8000 if id == "sfx_creature_call" else (500 if id == "sfx_combat_pulse" else 100)
	if now-int(last_played.get(id,-10000)) < cooldown: return
	var audio: AudioStream = stream(id)
	if audio == null: return
	last_played[id] = now
	if location == Vector3.INF:
		var speaker := AudioStreamPlayer.new()
		speaker.stream = audio
		speaker.bus = "UI" if id.begins_with("ui_") else "SFX"
		speaker.volume_db = -10
		add_child(speaker)
		speaker.finished.connect(speaker.queue_free)
		speaker.play()
	else:
		var speaker := AudioStreamPlayer3D.new()
		speaker.stream = audio
		speaker.bus = "SFX"
		speaker.volume_db = -8
		speaker.max_distance = 30
		add_child(speaker)
		speaker.global_position = location
		speaker.finished.connect(speaker.queue_free)
		speaker.play()

func update_world(p: Dictionary,paused: bool) -> void:
	if p.is_empty():
		ambient.stop()
		ambient_key = ""
		for emitter in emitters.values(): emitter.queue_free()
		emitters.clear()
		return
	var key: String = "amb_restored_nature" if p.environment.ecology >= 35 else "amb_barren_wind"
	if key != ambient_key:
		ambient_key = key
		ambient.stream = stream(key,true)
		if ambient.stream: ambient.play()
	ambient.stream_paused = paused
	var wanted: Dictionary = {}
	var listener := Vector2(float(p.player.position[0]),float(p.player.position[1]))
	for robot in p.robots:
		var location := Vector2(float(robot.position[0]),float(robot.position[1]))
		if listener.distance_to(location) > 30 or wanted.size() >= 12: continue
		if robot.status == "전투 작전 중" and not paused: play("sfx_combat_pulse",Vector3(location.x,1.5,location.y))
		var sound: String = ""
		if robot.status == "채광 중": sound = "sfx_robot_work"
		elif robot.status == "충전 중": sound = "sfx_robot_charge"
		elif robot.status.ends_with("이동") or robot.status == "자원 운반": sound = "sfx_robot_move"
		if not sound.is_empty(): wanted[robot.id] = [sound,Vector3(location.x,0.8,location.y)]
	if not paused:
		for event in p.events:
			if event.kind == "animal" and event.choice != "capture":
				var position: Vector2 = FrontierCampaign.point(event.position)
				if listener.distance_to(position) < 22: play("sfx_creature_call",Vector3(position.x,0.8,position.y))
	for b in p.buildings:
		if not b.get("active",false):continue
		if b.type=="factory" and (not b.get("production",{}).is_empty() or b.get("working",false)):
			var at:=Vector2(float(b.position[0]),float(b.position[1]))
			if listener.distance_to(at)<35 and wanted.size()<12:wanted[b.id]=["sfx_robot_work",Vector3(at.x,1.5,at.y)]
			continue
		if b.type not in ["atmosphere","thermal","water","biolab"] or not b.get("working",b.active):continue
		var location := Vector2(float(b.position[0]),float(b.position[1]))
		if listener.distance_to(location) < 35 and wanted.size() < 12: wanted[b.id] = [{"atmosphere":"sfx_terraform_active","thermal":"sfx_thermal_loop","water":"sfx_water_loop","biolab":"sfx_biolab_loop"}[b.type],Vector3(location.x,1.5,location.y)]
	for id in emitters.keys():
		if not wanted.has(id):
			var retiring: AudioStreamPlayer3D=emitters[id]
			if paused:retiring.stream_paused=true
			var fade:=create_tween();fade.tween_property(retiring,"volume_db",-55,.18);fade.tween_callback(retiring.queue_free)
			emitters.erase(id)
	for id in wanted:
		var value: Array = wanted[id]
		if not emitters.has(id):
			if stream(value[0],true) == null: continue
			var emitter := AudioStreamPlayer3D.new()
			emitter.bus = "SFX"
			emitter.max_distance = 35
			emitter.unit_size = 8
			emitter.volume_db = -50
			add_child(emitter)
			emitters[id] = emitter
		var emitter: AudioStreamPlayer3D = emitters[id]
		if emitter.get_meta("sound","") != value[0]:
			emitter.stream = stream(value[0],true)
			emitter.set_meta("sound",value[0])
			if emitter.stream:
				emitter.volume_db=-50
				emitter.play(fmod(float(hash(str(id))%1000)/1000.0*emitter.stream.get_length(),emitter.stream.get_length()))
				var level:= -8.0 if value[0] in ["sfx_thermal_loop","sfx_water_loop","sfx_biolab_loop"] else (-20.0 if value[0] in ["sfx_robot_work","sfx_robot_move"] else -18.0)
				create_tween().tween_property(emitter,"volume_db",level,.22)
		emitter.global_position = value[1]
		emitter.stream_paused = paused
