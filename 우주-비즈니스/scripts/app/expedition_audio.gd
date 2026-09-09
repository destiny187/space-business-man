extends Node
## Scene music with restrained discovery/danger variations and local crossfades.
var app: Node
var library: FrontierAudio
var music: Dictionary={}
var gains: Dictionary={}
var config: Dictionary
var current_place: String=""
var current_mood: String="space"
var previous_system: int=-1
var previous_mode: String=""
var discovery_left:=0.0
var danger_left:=0.0
var music_duck:=1.0
var planet_music_key: String=""
var planet_music_mood: String="planet"
func configure(owner_app: Node) -> void:
	app=owner_app;config=JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition_audio.json"))
	library=FrontierAudio.new();add_child(library)
	for place in config.music:
		var player:=AudioStreamPlayer.new();player.name="Music_"+place;player.bus="Music";player.volume_db=-80
		player.stream=library.stream(str(config.music[place]),true);add_child(player);music[place]=player;gains[place]=0.0
func _process(delta: float) -> void:
	if app==null:return
	var playing: bool=app.session.active and app.session.latest.get("phase","")=="playing"
	var crew: Dictionary=app.session.latest.get("crew",{})
	var on_planet: bool=playing and not crew.get("landing",{}).is_empty()
	if app.arrival.active and app.arrival.phase in ["approach","loading","warming"]:on_planet=false
	current_place=("planet" if on_planet else "space") if playing else ""
	var paused: bool=not DisplayServer.window_is_focused() or app.any_menu_open()
	var settings:=FrontierClientSettings.current(get_tree())
	var volume:=.65
	if settings!=null:paused=paused or settings.is_open();volume=float(settings.values.get("music_volume",.65))
	var nav: Dictionary=crew.get("navigation",{})
	if playing and not paused:_update_mood(delta,nav,on_planet)
	for place in music:
		var player: AudioStreamPlayer=music[place]
		if not playing:
			player.stop();gains[place]=0.0;previous_system=-1;previous_mode="";discovery_left=0;danger_left=0;continue
		player.stream_paused=paused
		if paused:continue
		var target:=1.0 if place==current_mood else 0.0
		gains[place]=move_toward(float(gains[place]),target,delta/float(config.crossfade_seconds))
		if gains[place]>.001 and player.stream!=null:
			if not player.playing:player.play()
			var position:=player.get_playback_position();var edge:=float(config.loop_fade_seconds)
			var envelope:=minf(clampf(position/edge,0,1),clampf((player.stream.get_length()-position)/edge,0,1))
			player.volume_db=linear_to_db(maxf(.0001,sqrt(float(gains[place]))*volume*float(config.level)*envelope*music_duck))
		elif player.playing:player.stop()
func _update_mood(delta: float,nav: Dictionary,on_planet: bool) -> void:
	discovery_left=maxf(0,discovery_left-delta);danger_left=maxf(0,danger_left-delta)
	var system:=int(nav.get("system",-1));var mode: String=nav.get("mode","")
	if system>=0 and mode!="jump":
		if system!=previous_system and previous_system>=0:discovery_left=float(config.discovery_seconds)
		elif previous_mode=="jump":discovery_left=float(config.discovery_seconds)
		previous_system=system
	previous_mode=mode
	if nav.get("star_warning",false) or nav.get("star_danger",false) or float(nav.get("hull",100))<35:danger_left=float(config.danger_hold_seconds)
	current_mood=_planet_music() if on_planet else ("danger" if danger_left>0 else ("discovery" if discovery_left>0 else "space"))
	if not music.has(current_mood) or music[current_mood].stream==null:current_mood=current_place
	var duck:=1.0
	if not on_planet and mode=="jump":
		var p: float=nav.get("transit",{}).get("progress",0.0)
		duck=.4 if p<.3 else (1.0-smoothstep(.90,.98,p)*.94)
	elif not on_planet and discovery_left>float(config.discovery_seconds)-4:duck=.5
	if app.arrival.active:duck=minf(duck,.5)
	music_duck=move_toward(music_duck,duck,delta*3.0)
func _planet_music() -> String:
	# Per-player snapshots already resolve FINCH's independent landing context.
	var landing: Dictionary=app.session.latest.get("crew",{}).get("landing",{})
	var body_id: String=str(landing.get("body_id",app.session.latest.get("location","")))
	if body_id.is_empty():return "planet"
	var key: String=str(app.session.manifest.get("id",""))+":"+body_id
	if key!=planet_music_key:
		planet_music_key=key
		var body: Dictionary=FrontierUniverse.body_from_id(app.session.manifest,body_id)
		var tier:=clampi(int(body.get("planet_tier",1)),1,5)
		planet_music_mood=str(config.get("planet_tiers",{}).get(str(tier),"planet"))
	return planet_music_mood
func _exit_tree() -> void:
	for player in music.values():player.stop();player.stream=null
