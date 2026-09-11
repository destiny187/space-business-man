class_name FrontierTerraformPlacement
extends Node3D
## Terrain-following placement instrument, attached to the existing Blender placement ghost.
var app: FrontierCrewExpedition
var kind: String
var mesh: MeshInstance3D
var label: Label3D
var timer:=0.0
func configure(owner_app: FrontierCrewExpedition,building: String) -> void:
 app=owner_app;kind=building
 mesh=MeshInstance3D.new();add_child(mesh);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.vertex_color_use_as_albedo=true;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.no_depth_test=false;mesh.material_override=material
 label=Label3D.new();label.font=load("res://assets/fonts/NotoSansKR.ttf");label.font_size=28;label.pixel_size=.007;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.outline_size=8;label.position=Vector3(0,5,0);add_child(label)
func _process(dt: float) -> void:
 timer-=dt
 if timer>0 or app.surface_world==null:return
 timer=.2
 var body: Dictionary=app.surface_world.body;var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(body.id,{})
 var weather: bool=kind=="grounding_mast"
 visible=weather or FrontierFreeTerraform.active(site) and kind in site.get("free_terraform",{}).get("rules",{}).get("radius",{})
 if not visible:return
 var p:=Vector2(global_position.x,global_position.z);var radius:=float(FrontierPlanetWeather.config().mast_radius) if weather else FrontierFreeTerraform.radius(site,{"type":kind})
 var inside:=false if weather else FrontierFreeTerraform.in_pollution(site,p);var tint:=Color(.4,.9,.72,.8)
 if kind=="source_control" and not inside:tint=Color(1,.35,.22,.9)
 var geometry:=ImmediateMesh.new();geometry.surface_begin(Mesh.PRIMITIVE_LINES)
 var field:=app.surface_world.terrain.field
 for ring in ([radius] if weather else [radius*.4,radius]):
  for n in 64:
   var a:=n*TAU/64;var b: float=(n+1)*TAU/64
   geometry.surface_set_color(tint)
   for angle in [a,b]:
    var x: float=cos(angle)*ring;var z: float=sin(angle)*ring
    geometry.surface_add_vertex(Vector3(x,field.height(p.x+x,p.y+z)-global_position.y+.12,z))
 geometry.surface_end();mesh.mesh=geometry
 var overlaps:=0
 for row in site.buildings.values():
  if row.type==kind and Vector2(row.position[0]-p.x,row.position[2]-p.y).length()<radius*1.6:overlaps+=1
 label.text=("자연 낙뢰 보호 %.0fm" if weather else "영향 반경 %.0fm")%radius
 if kind=="water":
  var box:=FrontierFacilityFlooding.bounds({"type":"water","tier":1})
  label.text+="\n저지대 ×%.2f · 침수 시 정지\n설비 상단 %.1fm / 기준 해수면 −4m"%[FrontierFreeTerraform.water_gain(site,body,p),global_position.y+box.end.y]
 elif kind=="biolab":label.text+="\n중첩 후보 %d대 · 겹친 토양 효과 1회"%overlaps
 elif kind=="source_control":label.text+="\n"+("오염 구역 내부 · 전문 처리 가능" if inside else "오염 구역 외부 · 효과 없음")
 elif kind=="atmosphere":label.text+="\n구면 분포·전달은 Tab 테라포밍"
 label.modulate=tint
