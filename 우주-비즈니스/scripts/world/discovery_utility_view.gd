class_name FrontierDiscoveryUtilityView
extends Node
## Per-facility presentation reads its host record, never resamples water or biology.
var view: FrontierBusinessSiteView
var facility: Node3D
var kind: String
var lamp: OmniLight3D
var speaker: AudioStreamPlayer3D
var elapsed:=0.0
var cooldown:=0.0
var glow: Array[ShaderMaterial]=[]
var glow_parts: Array[Node]=[]
func _ready() -> void:
 name="DiscoveryUtility"
 if kind=="shell_refuge":set_process(false);return
 lamp=OmniLight3D.new();lamp.position.y=1.25;lamp.shadow_enabled=false;lamp.visible=false
 lamp.omni_range=float(FrontierDiscoveryUtilities.config().tank.light_range) if kind=="luminous_vivarium" else 4.
 lamp.light_color=Color("58f0d3") if kind=="luminous_vivarium" else Color("ff9b45") if kind=="flood_sentinel" else Color("84bcdc")
 facility.add_child(lamp)
 glow_parts=facility.get_meta("visual").find_children("Anim_Glow*","Node3D",true,false)
 for part in glow_parts:
  for mesh in part.find_children("*","MeshInstance3D",true,false):
   for i in mesh.mesh.get_surface_count():
    var material: Material=mesh.get_active_material(i)
    if material is ShaderMaterial:
     var copy: ShaderMaterial=material.duplicate();mesh.set_surface_override_material(i,copy);glow.append(copy)
 if kind in ["resonance_garden","flood_sentinel"]:
  var library:=FrontierAudio.new();add_child(library)
  speaker=AudioStreamPlayer3D.new();speaker.bus="Ambience" if kind=="resonance_garden" else "SFX"
  speaker.stream=library.stream(str(FrontierDiscoveryUtilities.config().garden.sound if kind=="resonance_garden" else FrontierDiscoveryUtilities.config().alarm.sound),kind=="resonance_garden")
  speaker.volume_db=-22 if kind=="resonance_garden" else -13;speaker.unit_size=3;speaker.max_distance=16 if kind=="resonance_garden" else 40
  speaker.position.y=1.2;facility.add_child(speaker)
func _process(dt: float) -> void:
 elapsed+=dt;cooldown=maxf(0,cooldown-dt)
 var b: Dictionary=view.ledger.get("sites",{}).get(view.body.id,{}).get("buildings",{}).get(str(facility.get_meta("business_id")),{})
 var surface:=view.get_parent() as FrontierCrewSurfaceScene
 var blocked:=false;var nearby:=true
 if surface!=null:
  nearby=surface.viewer.position.distance_to(facility.position)<(16. if kind=="resonance_garden" else 45.)
  var app:=surface.get_parent()
  if app is FrontierCrewExpedition:blocked=app.any_menu_open() or app.arrival.active or (not get_window().has_focus() and not app.test_mode)
 var active: bool=b.get("active",false)
 var sounding: bool=active and not b.get("muted",false) and nearby and not blocked
 var lit:=false
 if kind=="luminous_vivarium":
  var occupied: bool=not b.get("specimen_stock",{}).is_empty()
  lit=active and occupied
  for part in glow_parts:part.visible=occupied
 elif kind=="flood_sentinel":
  sounding=sounding and not str(b.get("alarm_target","")).is_empty()
  lit=active and not str(b.get("alarm_target","")).is_empty() and fmod(elapsed,1.)<.5
 else:lit=sounding
 lamp.visible=lit and nearby;lamp.light_energy=1.4 if kind=="luminous_vivarium" else .65
 for material in glow:
  material.set_shader_parameter("emission_strength",.4 if lit else 0.)
  material.set_shader_parameter("emission_color",lamp.light_color)
 if speaker==null:return
 if not sounding:speaker.stop();cooldown=0;return
 if kind=="resonance_garden":
  speaker.pitch_scale=float(FrontierDiscoveryUtilities.config().garden.pitches[int(b.get("resonance_tone",1))])
  if not speaker.playing:speaker.play()
 elif cooldown<=0:
  speaker.play();cooldown=float(FrontierDiscoveryUtilities.config().alarm.sound_interval)
