extends Node
## Local soundtrack. Snapshot updates never restart the current track.
var app: Node
var library: FrontierAudio
var music: Dictionary={}
var gains: Dictionary={"space":0.0,"planet":0.0}
var config: Dictionary
var current_place: String=""

func configure(owner_app: Node) -> void:
	app=owner_app
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition_audio.json"))
	library=FrontierAudio.new();add_child(library)
	for place in ["space","planet"]:
		var player:=AudioStreamPlayer.new();player.bus="Music";player.volume_db=-80
		player.stream=library.stream(str(config.music[place]),true)
		add_child(player);music[place]=player

func _process(delta: float) -> void:
	if app==null:return
	var playing: bool=app.session.active and app.session.latest.get("phase","")=="playing"
	var on_planet: bool=playing and not app.session.latest.get("crew",{}).get("landing",{}).is_empty()
	current_place=("planet" if on_planet else "space") if playing else ""
	var paused: bool=not DisplayServer.window_is_focused() or app.any_menu_open()
	var settings:=FrontierClientSettings.current(get_tree())
	var volume: float=.65
	if settings!=null:
		paused=paused or settings.is_open()
		volume=float(settings.values.get("music_volume",.65))
	for place in music:
		var player: AudioStreamPlayer=music[place]
		if not playing:
			player.stop();gains[place]=0.0;continue
		player.stream_paused=paused
		# Freeze the transition while presentation is paused, too.
		if paused:continue
		var target: float=1.0 if place==current_place else 0.0
		gains[place]=move_toward(float(gains[place]),target,delta/float(config.crossfade_seconds))
		if gains[place]>.001 and player.stream!=null:
			if not player.playing:player.play()
			var position: float=player.get_playback_position()
			var edge: float=float(config.loop_fade_seconds)
			var envelope: float=minf(clampf(position/edge,0,1),clampf((player.stream.get_length()-position)/edge,0,1))
			player.volume_db=linear_to_db(maxf(.0001,float(gains[place])*volume*float(config.level)*envelope))
		elif player.playing:player.stop()

func _exit_tree() -> void:
	for player in music.values():player.stop();player.stream=null
