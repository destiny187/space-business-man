extends Node3D
var combat: Node3D
var vessel: Node3D
var requested:=false
var materials: Dictionary={}
var label: Label
func configure(owner_combat: Node3D) -> void:
 combat=owner_combat
 var layer:=CanvasLayer.new();add_child(layer);label=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2);layer.add_child(label)
func _process(delta: float) -> void:
 var e: Dictionary=combat.encounter();var active: bool=combat.relevant() and e.has("rescue") and not combat.blocked and combat.view.exterior
 label.visible=active
 if vessel:vessel.visible=active
 if not active:return
 var path: String="res://assets/models/incidents/mission_lander.glb"
 if vessel==null:
  if not requested:ResourceLoader.load_threaded_request(path);requested=true
  if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:return
  vessel=(ResourceLoader.load_threaded_get(path) as PackedScene).instantiate();add_child(vessel);vessel.scale=Vector3.ONE*3.;FrontierInkStyle.apply(vessel,materials)
 vessel.position=FrontierSpaceCombat.point(e.rescue.position)
 if e.phase=="victory":vessel.position+=FrontierSpaceCombat.point(e.heading)*float(e.elapsed)*160
 var heading:=FrontierSpaceCombat.point(e.heading)
 if heading.length()>.1:vessel.look_at(vessel.position+heading)
 var size:=get_viewport().get_visible_rect().size
 label.position=Vector2(24,size.y*.30);label.size=Vector2(minf(470,size.x-48),65);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.text="수송선 구조 신호  추격 편대를 격퇴하세요" if e.phase in ["warning","combat"] else "수송선 구조 완료  J 사건 기록에 착륙 현장을 전송했습니다" if e.phase=="victory" else "수송선 구조 중단"
