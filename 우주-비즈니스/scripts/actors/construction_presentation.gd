class_name FrontierConstructionPresentation
extends Node3D
## Local, finite presentation of an already committed building; never owns gameplay state.
static var settings: Dictionary={}
static func config() -> Dictionary:
 if settings.is_empty():settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/construction_presentation.json"))
 return settings
var age:=0.0
var duration:=1.8
var solid: Array[MeshInstance3D]=[]
var concealed: Array[MeshInstance3D]=[]
var occluders: Array[Node3D]=[]
var hologram: ShaderMaterial
var beams: Array[MeshInstance3D]=[]
var rail: Node3D
var anchors: Node3D
var sparks: MultiMeshInstance3D
var bounds:=AABB()
var audio: FrontierAudio
var finished:=false

func configure(building: Node3D,speaker: FrontierAudio,seconds: float=0.0) -> void:
 audio=speaker;duration=maxf(float(config().seconds),seconds);building.set_meta("constructing",true)
 building.add_child(self)
 var visual: Node3D=building.get_meta("visual")
 hologram=ShaderMaterial.new();hologram.shader=load("res://assets/materials/construction_hologram.gdshader");hologram.set_shader_parameter("tint",Color(config().hologram_color))
 var initialized:=false
 for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  var pose:=global_transform.affine_inverse()*mesh.global_transform
  var box: AABB=pose*mesh.get_aabb()
  bounds=bounds.merge(box) if initialized else box;initialized=true
  var can_reveal:=true
  for surface in mesh.mesh.get_surface_count():
   var material:=mesh.get_active_material(surface)
   if not material is ShaderMaterial or material.shader!=FrontierInkStyle.CEL:can_reveal=false
  if can_reveal:solid.append(mesh)
  elif mesh.visible:concealed.append(mesh);mesh.hide()
  var ghost:=MeshInstance3D.new();ghost.mesh=mesh.mesh;ghost.material_override=hologram;ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ghost);ghost.transform=pose
 for node in building.get_children():
  if node is OccluderInstance3D and node.visible:occluders.append(node);node.hide()
 var color:=Color(config().hologram_color)
 anchors=Node3D.new();add_child(anchors);rail=Node3D.new();add_child(rail)
 var minimum:=bounds.position;var maximum:=bounds.end
 minimum.x-=.12;minimum.z-=.12;maximum.x+=.12;maximum.z+=.12
 for x in [minimum.x,maximum.x]:
  for z in [minimum.z,maximum.z]:
   var corner:=Vector3(x,.06,z)
   var inward:=Vector3(1 if x==minimum.x else -1,0,1 if z==minimum.z else -1)
   line(anchors,corner,corner+Vector3(inward.x*.5,0,0),color,.045)
   line(anchors,corner,corner+Vector3(0,0,inward.z*.5),color,.045)
   line(anchors,corner,corner+Vector3(0,.38,0),color,.035)
   line(rail,Vector3(x,0,z),Vector3(x,0,z+inward.z*.38),Color(config().weld_color),.035)
 for z in [minimum.z,maximum.z]:line(rail,Vector3(minimum.x,0,z),Vector3(maximum.x,0,z),color,float(config().beam_width))
 for x in [minimum.x,maximum.x]:line(rail,Vector3(x,0,minimum.z),Vector3(x,0,maximum.z),color,float(config().beam_width))
 sparks=MultiMeshInstance3D.new();var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
 var shard:=BoxMesh.new();shard.size=Vector3(.025,.07,.025);multi.mesh=shard;multi.instance_count=16;sparks.multimesh=multi;sparks.material_override=effect_material(Color(config().weld_color));sparks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(sparks)
 apply_frame(0.0)
 if is_instance_valid(audio):audio.play(config().start_sound,global_position)

func effect_material(color: Color) -> StandardMaterial3D:
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color;mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=.25
 return mat
func line(parent: Node3D,start: Vector3,end: Vector3,color: Color,width: float) -> void:
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(width,width,start.distance_to(end));mesh.mesh=box;mesh.material_override=effect_material(color);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh);mesh.position=(start+end)*.5
 mesh.look_at_from_position(mesh.global_position,to_global(end),Vector3.RIGHT if absf((end-start).normalized().y)>.9 else Vector3.UP)
 beams.append(mesh)
func apply_frame(t: float) -> void:
 var progress:=smoothstep(float(config().anchor_fraction),float(config().seal_fraction),t)
 var y:=lerpf(bounds.position.y-.12,bounds.end.y+.15,progress)
 var level:=global_position.y+y
 for mesh in solid:mesh.set_instance_shader_parameter("construction_level",level)
 hologram.set_shader_parameter("level",level);hologram.set_shader_parameter("opacity",1.0-smoothstep(.78,1.0,t))
 rail.position.y=y;rail.visible=t>float(config().anchor_fraction) and t<float(config().seal_fraction)
 anchors.scale=Vector3.ONE*lerpf(.88,1.,smoothstep(0.,float(config().anchor_fraction),t))
 anchors.visible=t<.96
 for i in 16:
  var angle:=float(i)*TAU/16+t*2.
  var phase:=fmod(t*7.+float(i)*.37,1.)
  var p:=Vector3(bounds.get_center().x+cos(angle)*bounds.size.x*.5,y+phase*.26,bounds.get_center().z+sin(angle)*bounds.size.z*.5)
  sparks.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(1.-phase)),p))
 sparks.visible=rail.visible
 if t>=float(config().seal_fraction):
  for mesh in concealed:mesh.show()
func _process(delta: float) -> void:
 age+=delta;apply_frame(minf(1.,age/duration))
 if age>=duration:
  if is_instance_valid(audio):audio.play(config().finish_sound,global_position,1.0,float(config().finish_gain_db))
  restore();queue_free()
func restore() -> void:
 if finished:return
 finished=true
 for mesh in solid:
  if is_instance_valid(mesh):mesh.set_instance_shader_parameter("construction_level",1e20)
 for mesh in concealed:
  if is_instance_valid(mesh):mesh.show()
 for node in occluders:
  if is_instance_valid(node):node.show()
 if is_instance_valid(get_parent()):get_parent().set_meta("constructing",false)
func _exit_tree() -> void:restore()
