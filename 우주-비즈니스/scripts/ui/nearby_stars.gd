extends Control
## Eight direction sectors, one nearest reachable star per sector.
var app: FrontierCrewExpedition
var markers: Array=[]
var hovered: Dictionary={}
var selection: int=-1
func configure(owner_app: FrontierCrewExpedition) -> void:
 app=owner_app;mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func available() -> bool:
 return app!=null and app.session.active and app.session.latest.get("phase")=="playing" and app.flight!=null and not app.flight.transit_overlay.presenting_arrival() and app.outside and app.surface_world==null and app._mouse_look_allowed() and app.session.latest.crew.navigation.mode=="idle"
func _process(_delta: float) -> void:
 visible=available()
 if not visible:hovered={};return
 markers.clear();hovered={}
 var nav: Dictionary=app.session.latest.crew.navigation
 var limit: float=app.session.latest.get("vessel_stats",{}).get("stellar_range",8.0)
 var camera: Camera3D=app.flight.camera
 var viewport_size:=Vector2(app.space_view.size)
 var scale_factor:=maxf(app.exterior_view.size.x/viewport_size.x,app.exterior_view.size.y/viewport_size.y)
 var offset: Vector2=app.exterior_view.global_position-(viewport_size*scale_factor-app.exterior_view.size)*.5
 var cursor: Vector2=size*.5 if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else get_global_mouse_position()
 var nearest:=24.0
 for item in FrontierStellarRoutes.directional(app.session.manifest,int(nav.system),limit):
  var direction:=Vector3(item.offset.x,0,item.offset.y).normalized()
  var marker:=FrontierSpaceGuidance.project(camera,camera.global_position+direction*100000,viewport_size)
  marker.guide_reason=app.onboarding.departure_reason(FrontierUniverse.first_ordinal(app.session.manifest,int(item.index)))
  marker.blocked=not marker.guide_reason.is_empty()
  marker.point=offset+marker.point*scale_factor;marker.index=item.index;marker.distance=item.distance
  markers.append(marker)
  var gap: float=cursor.distance_to(marker.point)
  if gap<nearest:nearest=gap;hovered=marker
 if not hovered.is_empty() and int(hovered.index)!=selection:
  selection=int(hovered.index)
  if app.flight.transit_audio!=null:app.flight.transit_audio.play("ui_discovery")
 if hovered.is_empty():selection=-1
 queue_redraw()
func _draw() -> void:
 for marker in markers:
  var point: Vector2=marker.point
  var focused: bool=not hovered.is_empty() and marker.index==hovered.index
  var color:=FrontierInterfaceStyle.WARNING if marker.blocked else Color("b2f4e1") if focused else Color(.55,.8,.82,.65)
  if marker.onscreen:
   draw_circle(point,3,color);draw_arc(point,8 if focused else 5,0,TAU,20,color,1,true)
  else:
   var direction: Vector2=marker.direction;var side:=direction.orthogonal()
   draw_polyline(PackedVector2Array([point-direction*5+side*4,point+direction*3,point-direction*5-side*4]),color,1.5,true)
  if focused:
   var name_value: String=FrontierUniverse.system(app.session.manifest,int(marker.index)).star.name
   var text_value: String=name_value+"  %.1f 항로 단위"%float(marker.distance)+("\n"+str(marker.guide_reason) if not marker.guide_reason.is_empty() else "\n클릭 / F  고속 항해")
   var base:=Vector2(clampf(point.x+18,16,size.x-300),clampf(point.y-12,35,size.y-65))
   for i in text_value.split("\n").size():
    draw_string(get_theme_default_font(),base+Vector2(0,i*23),text_value.split("\n")[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
func _input(event: InputEvent) -> void:
 if not available() or hovered.is_empty():return
 var pressed: bool=(event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F)
 if not pressed:return
 if app.session.latest.self_id!=app.session.latest.crew.pilot_id:return
 var ordinal:=FrontierUniverse.first_ordinal(app.session.manifest,int(hovered.index))
 app.chart.route_system=int(hovered.index)
 app.navigation_ui.start_route(ordinal);get_viewport().set_input_as_handled()
