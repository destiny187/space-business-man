class_name FrontierLandingAudio
extends Node
var library: FrontierAudio
var layers: Dictionary={}
var gains: Dictionary={}
var events: Array[AudioStreamPlayer]=[]
var active:=false
var air:=0.0
var finch:=false
var previous_phase: String=""
var hatch_played:=false
var ground_material: String=""
func _ready() -> void:
	library=FrontierAudio.new();add_child(library)
	for entry in [["thruster","sfx_landing_thrusters"],["air","sfx_atmosphere_entry"],["ground","sfx_landing_grit_v2"],["cooling","sfx_landing_cooling_v2"],["ambience","amb_barren_wind"]]:
		var player:=AudioStreamPlayer.new();player.bus="SFX" if entry[0]!="ambience" else "Ambience";player.stream=library.stream(entry[1],true);player.volume_db=-80;add_child(player);layers[entry[0]]=player;gains[entry[0]]=0.0
func begin(profile: Dictionary,small: bool) -> void:
	active=true;air=profile.air;finch=small;previous_phase="";hatch_played=false
func event(id: String,db: float=-20,pitch: float=1.0) -> void:
	for i in range(events.size()-1,-1,-1):
		if not is_instance_valid(events[i]):events.remove_at(i)
	var player:=AudioStreamPlayer.new();player.stream=library.stream(id);player.bus="SFX";player.volume_db=db;player.pitch_scale=pitch*(1.2 if finch else .9);add_child(player);events.append(player);player.finished.connect(player.queue_free);player.play()
func update(delta: float,phase: String,progress: float,height: float,hatch: float,ground: String,blocked: bool) -> void:
	for p in layers.values():p.stream_paused=blocked
	for p in events:
		if is_instance_valid(p):p.stream_paused=blocked
	if blocked:return
	if phase=="touchdown" and previous_phase!="touchdown":event("sfx_landing_gear_v2",-16)
	if hatch>.03 and not hatch_played:hatch_played=true;event("sfx_landing_hatch_v2",-21)
	previous_phase=phase
	if ground_material!=ground:
		ground_material=ground;layers.ground.stream=library.stream("sfx_water_loop" if ground=="water" else "sfx_landing_grit_v2",true)
	var thrust:=.35
	if phase=="approach":thrust=lerpf(.55,.38,progress)
	elif phase=="descent":thrust=.4+sin(progress*PI)*.2+smoothstep(.7,.94,progress)*.22
	elif phase=="touchdown":thrust=.7*(1-smoothstep(0,1,progress))
	elif phase in ["disembark","handover",""]:thrust=0
	var near:=1-smoothstep(2,22,height)
	var target: Dictionary={"thruster":thrust,"air":air*(.2+thrust*.8) if phase in ["approach","loading","warming","descent"] else 0.0,"ground":near*thrust*air*.65,"cooling":.32 if phase in ["touchdown","disembark","handover"] else 0.0,"ambience":air*hatch*.32}
	for key in layers:
		var player: AudioStreamPlayer=layers[key];gains[key]=move_toward(float(gains[key]),float(target[key]) if active else 0.0,delta*1.5)
		if gains[key]>.001 and player.stream!=null:
			player.volume_db=linear_to_db(maxf(.0001,float(gains[key])))-18
			player.pitch_scale=(1.2 if finch else .85)+(thrust*.25 if key=="thruster" else 0.0)
			if key=="ground":player.pitch_scale=1.5 if ground=="ice" else (.65 if ground=="water" else 1.0)
			if not player.playing:player.play()
		else:player.stop()
func finish() -> void:
	active=false
func _process(delta: float) -> void:
	if not active:update(delta,"",0,100,0,"dust",not get_window().has_focus())
func _exit_tree() -> void:
	for p in layers.values():p.stop();p.stream=null
