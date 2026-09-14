extends Node3D
## Authored backpack; exhaust and sound follow confirmed thrust, never equip requests.
var pack: Node3D
var exhaust: Array[MeshInstance3D]=[]
var speaker: AudioStreamPlayer3D
func configure(model: Node3D,skeleton: Skeleton3D) -> void:
 var mount:=BoneAttachment3D.new();mount.bone_name="spine";skeleton.add_child(mount)
 pack=load("res://assets/models/equipment/jetpack_mk2.glb").instantiate();mount.add_child(pack)
 # Align an upright pack in model space, then convert to the bone's rest frame.
 pack.transform=skeleton.get_bone_global_rest(skeleton.find_bone("spine")).affine_inverse()*Transform3D(Basis.IDENTITY,Vector3(0,1.24,.25))
 FrontierInkStyle.apply(pack,{})
 for x in [-.27,.27]:
  var plume:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.065;mesh.bottom_radius=.012;mesh.height=.4;plume.mesh=mesh
  var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.35,.85,1.);mat.emission_enabled=true;mat.emission=Color(.12,.6,1.);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  plume.material_override=mat;plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;pack.add_child(plume);plume.position=Vector3(x,-.52,0);exhaust.append(plume)
 speaker=AudioStreamPlayer3D.new();speaker.stream=load("res://assets/audio/sfx_finch_turbine_v2.wav").duplicate();speaker.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;speaker.stream.loop_end=roundi(speaker.stream.get_length()*speaker.stream.mix_rate)
 speaker.bus="SFX";speaker.volume_db=-24;speaker.pitch_scale=1.45;speaker.max_distance=24;add_child(speaker)
func sync(equipped: bool,active: bool,draw: bool,audible: bool) -> void:
 pack.visible=equipped and draw
 for plume in exhaust:plume.visible=active
 if equipped and active and audible:
  if not speaker.playing:speaker.play()
 else:speaker.stop()
