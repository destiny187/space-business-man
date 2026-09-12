class_name FrontierSpaceAudio
extends Node
var library: FrontierAudio
var scan: AudioStreamPlayer
var arrival: AudioStreamPlayer
var config: Dictionary={}
var pending_tier: int=-1
var blocked:=false
var transition_left:=0.0
var route_requests: Dictionary={}
func _ready() -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/space_audio.json"))
	library=FrontierAudio.new();add_child(library)
	scan=AudioStreamPlayer.new();scan.bus="SFX";scan.stream=library.stream("sfx_orbital_scan",true);scan.volume_db=-60;add_child(scan)
	arrival=AudioStreamPlayer.new();arrival.bus="SFX";arrival.volume_db=float(config.arrival_volume_db);add_child(arrival)
func enter(band: int) -> void:pending_tier=clampi(band,0,4)
func cancel_arrival() -> void:
	pending_tier=-1;arrival.stop()
func update(delta: float,scanning: bool,progress: float) -> void:
	transition_left=maxf(0,transition_left-delta)
	arrival.stream_paused=blocked
	if pending_tier>=0 and not blocked:
		arrival.stream=library.stream(config.arrival_ids[pending_tier]);arrival.play();pending_tier=-1
	var active: bool=scanning and not blocked
	if active and not scan.playing:scan.play()
	scan.pitch_scale=1.0+progress*.2
	scan.volume_db=move_toward(scan.volume_db,float(config.scan_volume_db) if active else -60,delta*180)
	if not active and scan.volume_db<=-59:scan.stop()
func transition(id: String) -> void:
	if blocked or transition_left>0:return
	library.play(id);transition_left=float(config.transition_cooldown_seconds)
func complete() -> void:
	scan.stop()
	if not blocked:library.play("sfx_orbital_complete")

func bind_session(session: FrontierCrewSession) -> void:
	session.request_started.connect(func(sequence: int,kind: String,_args: Dictionary):
		if kind in ["navigate","depart","tutorial_depart"]:route_requests[sequence]=kind)
	session.response_received.connect(func(sequence: int,result: Dictionary):
		if not route_requests.has(sequence):return
		var kind: String=route_requests[sequence];route_requests.erase(sequence)
		if not result.get("ok",false):library.play("sfx_build_invalid")
		elif kind=="navigate":library.play("ui_discovery"))
