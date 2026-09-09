extends Node
## ElevenLabs layers respond to the same wind, shelter and actual living actors as scenery.
var presence: FrontierSurfacePresence
var library: FrontierAudio
var layers: Dictionary={}
var gains: Dictionary={}
var voices: Array[AudioStreamPlayer3D]=[]
var event_left:=8.0
var rng:=RandomNumberGenerator.new()
var reverb: AudioEffectReverb
var bus_name: String
var creature_sources: Array[Vector3]=[]
var event_count:=0
var sample_left:=0.0
var targets: Dictionary={}
var machinery: Array[AudioStreamPlayer3D]=[]
var water_sources: Dictionary={}
var water_gains: Dictionary={"ocean":0.0,"river":0.0}
func configure(owner_presence: FrontierSurfacePresence) -> void:
 presence=owner_presence;library=FrontierAudio.new();add_child(library);rng.seed=int(presence.surface.body.seed)
 bus_name="SurfaceSpace_"+str(get_instance_id());AudioServer.add_bus();var index:=AudioServer.bus_count-1;AudioServer.set_bus_name(index,bus_name);AudioServer.set_bus_send(index,"Ambience")
 reverb=AudioEffectReverb.new();reverb.room_size=.65;reverb.wet=0;AudioServer.add_bus_effect(index,reverb)
 for key in ["wind","nature","foliage","grit","water","thermal"]:
  var player:=AudioStreamPlayer.new();player.bus=bus_name;player.stream=library.stream(presence.cfg.sounds[key],true);player.volume_db=-80;add_child(player);layers[key]=player;gains[key]=0.0
 for i in 4:
  var machine:=AudioStreamPlayer3D.new();machine.bus=bus_name;machine.stream=library.stream("sfx_robot_work",true);machine.max_distance=100;machine.unit_size=24;machine.volume_db=-80;add_child(machine);machinery.append(machine)
 for key in ["ocean","river"]:
  var source:=AudioStreamPlayer3D.new();source.bus=bus_name;source.stream=library.stream("amb_surface_river_v1" if key=="river" else "amb_surface_shallows_v1",true);source.max_distance=45;source.unit_size=10;source.volume_db=-80;add_child(source);water_sources[key]=source
func update(delta: float,blocked: bool) -> void:
 for key in water_sources:
  var source: AudioStreamPlayer3D=water_sources[key];source.stream_paused=blocked
  if blocked:continue
  var selected: Dictionary=presence.scenery.water
  var target:=float(presence.surface.atmosphere.current.atmosphere)*(1-presence.cave) if selected.kind==key and float(selected.distance)<40 else 0.0
  water_gains[key]=move_toward(float(water_gains[key]),target,delta*1.5)
  if selected.kind==key:source.global_position=selected.position+Vector3.UP*.15
  if water_gains[key]>.001:
   source.volume_db=linear_to_db(water_gains[key])-25
   if not source.playing:source.play()
  else:source.stop()
 for player in machinery:player.stream_paused=blocked
 if not blocked:
  sample_left-=delta
  if sample_left<=0:sample_left=.5;_sample()
  for i in machinery.size():
   var player: AudioStreamPlayer3D=machinery[i]
   if i>=presence.scenery.machines.size() or not is_instance_valid(presence.scenery.machines[i]):player.stop();continue
   var node: Node3D=presence.scenery.machines[i];player.global_position=node.global_position+Vector3.UP*1.5
   var sound_id: String=node.get_meta("scenery_sound","sfx_robot_work")
   if player.get_meta("sound","")!=sound_id:player.stop();player.stream=library.stream(sound_id,true);player.set_meta("sound",sound_id)
   var distance_value:=presence.surface.viewer.position.distance_to(node.position)
   var gain:=smoothstep(16,36,distance_value)*(1-smoothstep(70,100,distance_value))*float(presence.surface.atmosphere.current.atmosphere)*(1-presence.cave*.9)
   player.volume_db=linear_to_db(maxf(.0001,gain))-29;player.attenuation_filter_cutoff_hz=lerpf(2000,450,smoothstep(25,90,distance_value))
   if gain>.001 and not player.playing:player.play()
 _mix(delta,blocked)
func _sample() -> void:
 var s:=presence.surface
 var p: Vector3=s.viewer.position
 var weight:=presence.local_weight();var air: float=s.atmosphere.current.atmosphere
 creature_sources.clear()
 for id in s.ecology.actors:
  var row: Dictionary=s.ecology.encounters[id]
  if row.status!="active":continue
  var form:=FrontierEcologyCatalog.form(row.form_id)
  if form.category=="animal" and p.distance_to(s.ecology.actors[id].global_position)<55:creature_sources.append(s.ecology.actors[id].global_position)
 var foliage_near:=0.0
 for row in presence.patches:
  if row.valid:foliage_near=maxf(foliage_near,float(row.growth)*(1-smoothstep(4,20,p.distance_to(row.node.position))))
 var water_near:=0.0
 for row in presence.ponds:
  if row.valid:water_near=maxf(water_near,float(row.strength)*(1-smoothstep(3,18,p.distance_to(row.node.position))))
 for q in presence.scenery.plant_sources:foliage_near=maxf(foliage_near,1-smoothstep(4,20,p.distance_to(q)))
 var native: Dictionary=s.body.traits
 var dry: float=1-float(presence.state.wet)*weight
 var temperature: float=lerpf(float(native.temperature),float(presence.region.environment.temperature),weight) if not presence.region.is_empty() else float(native.temperature)
 targets={"foliage":foliage_near*air*presence.shelter*(.03+presence.gust*.12),"wind":air*presence.shelter*(.14+presence.gust*.20),"nature":minf(.15,creature_sources.size()*.045)*air*presence.shelter,"grit":air*presence.gust*dry*presence.shelter*.07,"water":water_near*air*.13,"thermal":smoothstep(65,160,temperature)*air*(.025+.02*presence.cave)}
func _mix(delta: float,blocked: bool) -> void:
 if targets.is_empty():return
 var s:=presence.surface;var p: Vector3=s.viewer.position
 var native: Dictionary=s.body.traits;var air: float=s.atmosphere.current.atmosphere
 var temperature: float=lerpf(float(native.temperature),float(presence.region.environment.temperature),presence.local_weight()) if not presence.region.is_empty() else float(native.temperature)
 reverb.wet=lerpf(reverb.wet,presence.cave*.3,minf(1,delta*2))
 for key in layers:
  var player: AudioStreamPlayer=layers[key];player.stream_paused=blocked
  if blocked:continue
  gains[key]=move_toward(float(gains[key]),float(targets[key]),delta*.12)
  if gains[key]>.001 and player.stream!=null:
   player.volume_db=linear_to_db(float(gains[key]))-9
   if not player.playing:player.play(rng.randf()*maxf(.01,player.stream.get_length()-.1))
  else:player.stop()
 for voice in voices:
  if is_instance_valid(voice):voice.stream_paused=blocked
 if blocked:return
 event_left-=delta
 if event_left<=0:
  event_left=rng.randf_range(presence.cfg.event_interval_seconds[0],presence.cfg.event_interval_seconds[1])
  if not creature_sources.is_empty() and air>.05:_event("creature",creature_sources[rng.randi_range(0,creature_sources.size()-1)],-22)
  elif not presence.scenery.rock_sources.is_empty() and air>.05 and presence.cave<.3:
   var at: Vector3=presence.scenery.rock_sources[rng.randi_range(0,presence.scenery.rock_sources.size()-1)]
   if temperature<0 and float(native.water)>5:_event("ice",at,-30)
   elif temperature>65:_event("thermal",at,-33);presence.scenery.puff(at,6)
   elif presence.gust>.2:_event("grit",at,-34);presence.scenery.puff(at,4)
 for i in range(voices.size()-1,-1,-1):
  if not is_instance_valid(voices[i]):voices.remove_at(i)
func _event(key: String,at: Vector3,level: float) -> void:
 var voice:=AudioStreamPlayer3D.new();voice.stream=library.stream(presence.cfg.sounds[key]);voice.bus=bus_name;voice.volume_db=level;voice.unit_size=5;voice.max_distance=55;voice.pitch_scale=rng.randf_range(.85,1.08)
 if voice.stream==null:voice.free();return
 add_child(voice);voice.global_position=at;voice.finished.connect(voice.queue_free);voices.append(voice);voice.play();event_count+=1
func _exit_tree() -> void:
 for p in layers.values():p.stop();p.stream=null
 for p in machinery:p.stop();p.stream=null
 for p in water_sources.values():p.stop();p.stream=null
 for voice in voices:
  if is_instance_valid(voice):voice.stop();voice.stream=null
 var index:=AudioServer.get_bus_index(bus_name)
 if index>=0:AudioServer.remove_bus(index)
