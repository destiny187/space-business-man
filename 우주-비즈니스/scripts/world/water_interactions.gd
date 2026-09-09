class_name FrontierWaterInteractions
extends Node3D
## Three shared draw batches, fixed voice count; contacts follow approved host motion.
var surface: FrontierCrewSurfaceScene
var cfg: Dictionary
var seen: Dictionary={}
var batches: Array[MultiMeshInstance3D]=[]
var particles: Array=[]
var voices: Array[AudioStreamPlayer3D]=[]
var streams: Dictionary={}
var clock_value:=0.0
var emitted: Dictionary={"enter":0,"exit":0,"step":0,"stroke":0,"shot":0,"wake":0,"bubble":0}
var bus_name: String
var lowpass: AudioEffectLowPassFilter
var overlay: ColorRect
var veil:=0.0

func configure(value: FrontierCrewSurfaceScene) -> void:
 surface=value;cfg=JSON.parse_string(FileAccess.get_file_as_string("res://data/water_interactions.json"))
 var plane:=PlaneMesh.new();plane.size=Vector2(2,2)
 var drop:=SphereMesh.new();drop.radius=1;drop.height=2;drop.radial_segments=6;drop.rings=3
 var meshes: Array[Mesh]=[plane,_crown(),drop]
 var limits: Array=[cfg.ring_limit,cfg.crown_limit,cfg.droplet_limit]
 for i in 3:
  var node:=MultiMeshInstance3D.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_custom_data=true;node.multimesh.mesh=meshes[i];node.multimesh.instance_count=int(limits[i]);node.multimesh.visible_instance_count=0
  var material:=ShaderMaterial.new();material.shader=load("res://assets/materials/space/water_interaction.gdshader");material.set_shader_parameter("shape",i);node.material_override=material
  add_child(node);batches.append(node);particles.append([])
 bus_name="WaterContact_"+str(get_instance_id());AudioServer.add_bus();var bus:=AudioServer.bus_count-1;AudioServer.set_bus_name(bus,bus_name);AudioServer.set_bus_send(bus,"SFX")
 lowpass=AudioEffectLowPassFilter.new();lowpass.cutoff_hz=20000;AudioServer.add_bus_effect(bus,lowpass)
 for key in cfg.sounds:
  var path: String="res://assets/audio/"+str(cfg.sounds[key])+".wav"
  if ResourceLoader.exists(path):streams[key]=load(path)
 for i in int(cfg.audio_voices):
  var voice:=AudioStreamPlayer3D.new();voice.bus=bus_name;voice.max_distance=float(cfg.view_distance);voice.unit_size=4;voice.attenuation_filter_cutoff_hz=6500;add_child(voice);voices.append(voice)
 var layer:=CanvasLayer.new();layer.layer=8;add_child(layer)
 overlay=ColorRect.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.color=Color(.04,.23,.28,0);layer.add_child(overlay)

func _crown() -> ArrayMesh:
 var vertices:=PackedVector3Array();var uvs:=PackedVector2Array()
 for i in 32:
  for index in [0,2,1,1,2,3]:
   var n:=i+index/2 as int;var top: int=index%2
   var angle:=n*TAU/32
   var height:=.38+.24*pow(.5+.5*sin(angle*8),2)
   var radius:=.5 if top==0 else .76
   vertices.append(Vector3(cos(angle)*radius,height*top,sin(angle)*radius));uvs.append(Vector2(n/32.0,float(top)))
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

func _exit_tree() -> void:
 var index:=AudioServer.get_bus_index(bus_name)
 if index>=0:AudioServer.remove_bus(index)

func _particle(batch: int,p: Vector3,v: Vector3,size: Vector3,life: float,growth: float=0.0,gravity: float=7.0) -> void:
 if particles[batch].size()>=batches[batch].multimesh.instance_count:return
 particles[batch].append({"p":p,"v":v,"size":size,"life":life,"age":0.0,"growth":growth,"gravity":gravity,"seed":randf()*TAU})

func _sound(kind: String,p: Vector3,strength: float) -> void:
 if not streams.has(kind):return
 for voice in voices:
  if voice.playing:continue
  voice.position=p;voice.stream=streams[kind];voice.pitch_scale=randf_range(.94,1.06)
  voice.volume_db=(-14.0 if kind in ["enter","shot"] else -20.0)+linear_to_db(clampf(strength,.3,1.4))
  voice.play();return

func emit_contact(kind: String,p: Vector3,strength: float=1.0,direction: Vector3=Vector3.ZERO) -> void:
 if surface==null or surface.viewer.position.distance_to(p)>float(cfg.view_distance):return
 emitted[kind]=int(emitted.get(kind,0))+1
 var scale_value:=clampf(strength,.2,1.8)
 var shot:=kind=="shot"
 var subtle:=kind in ["step","stroke","wake","exit"]
 if kind!="bubble":
  _particle(0,p+Vector3.UP*.035,Vector3.ZERO,Vector3.ONE*(.15 if shot else .25),1.5 if not subtle else 1.1,.75*scale_value,0)
  if not subtle:
   _particle(0,p+Vector3.UP*.042,Vector3.ZERO,Vector3.ONE*.1,1.9,.5*scale_value,0)
   _particle(1,p,Vector3.ZERO,Vector3(.28,1.6,.28)*scale_value if shot else Vector3(.8,.65,.8)*scale_value,.46,1.2,0)
 var count:=0 if kind=="wake" else (3 if kind=="bubble" else (6 if subtle else 18))
 var quality:=FrontierClientSettings.ensure(get_tree()).quality_level("effects")
 if quality==0:count=mini(count,6)
 for i in count:
  var angle:=float(i)*TAU/maxi(1,count)+randf()*.4
  var radial:=Vector3(cos(angle),0,sin(angle))*randf_range(.35,1.1)*scale_value
  var velocity:=radial+Vector3.UP*randf_range(1.5,3.3)*scale_value+direction*.18
  if shot:velocity.x*=.35;velocity.z*=.35
  var size:=randf_range(.018,.048)*scale_value
  if kind=="bubble":velocity=Vector3(randf_range(-.1,.1),.25,randf_range(-.1,.1))
  _particle(2,p+radial*.10,velocity,Vector3(size,size*(1.6 if shot else 1.0),size),randf_range(.4,.75),0,-.6 if kind=="bubble" else 7.0)
 if kind not in ["wake","bubble"]:_sound(kind,p,scale_value)

func observe(id: String,p: Vector3,motion: Dictionary,enabled: bool) -> void:
 if motion.is_empty():return
 var depth:=float(motion.get("water_depth",0))
 var step:=int(floor(fposmod(float(motion.get("phase",0)),TAU)/PI))
 var stroke:=int(floor(fposmod(float(motion.get("swim_phase",0)),TAU)/PI))
 var serial:=int(motion.get("water_serial",0))
 var shot: Dictionary=motion.get("water_shot",{})
 var shot_serial:=int(shot.get("serial",0))
 var previous: Dictionary=seen.get(id,{})
 var next: Dictionary={"point":p,"serial":serial,"shot":shot_serial,"step":step,"stroke":stroke,"depth":depth,"time":float(previous.get("time",-100)),"event_time":float(previous.get("event_time",-100)),"enabled":enabled}
 seen[id]=next
 if previous.is_empty() or not enabled or not previous.enabled or p.distance_to(previous.point)>3:return
 var velocity:=FrontierCrewWorld.vector(motion.velocity)
 var at:=p+Vector3.UP*minf(depth,1.85)
 if serial>int(previous.serial) and clock_value-float(previous.event_time)>float(cfg.event_cooldown):
  var kind:=str(motion.get("water_kind",""))
  if kind in ["enter","exit"]:
   if kind=="exit":at=previous.point+Vector3.UP*minf(float(previous.depth),1.85)
   emit_contact(kind,at,clampf(float(motion.get("water_impact",1))*.25,.35,1.7),velocity)
   next.event_time=clock_value
 if shot_serial>int(previous.shot):emit_contact("shot",FrontierCrewWorld.vector(shot.point),.85)
 if depth<.04:return
 if motion.state in ["swim","tread"]:
  if stroke!=int(previous.stroke) and clock_value-float(previous.time)>.3:
   var forward:=Vector3(-sin(float(motion.yaw)),0,-cos(float(motion.yaw)))
   var side:=forward.cross(Vector3.UP)*(1 if stroke==0 else -1)
   if depth<1.85:emit_contact("stroke",at+side*.34+forward*.25,.5,velocity)
   else:emit_contact("bubble",p+Vector3.UP*1.5,.5)
   next.time=clock_value
  elif motion.state=="swim" and depth<1.85 and clock_value-float(previous.time)>float(cfg.wake_interval):
   emit_contact("wake",at,.65,velocity);next.time=clock_value
 elif motion.grounded and motion.state in ["walk","run"] and step!=int(previous.step):
  if clock_value-float(previous.time)>.16:emit_contact("step",at,clampf(velocity.length()*.13,.3,.75),velocity);next.time=clock_value

func clear() -> void:
 for i in 3:particles[i].clear();batches[i].multimesh.visible_instance_count=0
 for voice in voices:voice.stop()

func _process(delta: float) -> void:
 if surface==null:return
 var app=surface.get_parent()
 var enabled: bool=surface.session.active and (not app is FrontierCrewExpedition or (not app.feedback.blocked() and not app.outside and (app.test_mode or get_window().has_focus())))
 if not enabled:clear();overlay.color.a=0;return
 clock_value+=delta
 var submerged:=surface.water_depth(surface.viewer.position)>1.68
 veil=lerpf(veil,1.0 if submerged else 0.0,1-exp(-delta*7))
 overlay.color=Color(.025,.20,.24,veil*.13)
 lowpass.cutoff_hz=lerpf(20000,900,veil)
 for batch in 3:
  var live: Array=particles[batch]
  for i in range(live.size()-1,-1,-1):
   var e: Dictionary=live[i];e.age+=delta
   if e.age>=e.life or (batch==2 and float(e.gravity)>0 and (e.v.y*float(e.age)-.5*float(e.gravity)*float(e.age)*float(e.age))<-.03):live.remove_at(i)
  var mesh:=batches[batch].multimesh
  for i in live.size():
   var e: Dictionary=live[i];var t:=float(e.age)/float(e.life)
   var p: Vector3=e.p+e.v*float(e.age)+Vector3.DOWN*.5*float(e.gravity)*float(e.age)*float(e.age)
   var size: Vector3=e.size+Vector3.ONE*float(e.growth)*float(e.age)
   if batch==1:size.y*=1-t;size.x*=1+t;size.z*=1+t
   mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(size),p))
   mesh.set_instance_custom_data(i,Color(t,e.seed,0,0))
  mesh.visible_instance_count=live.size()
