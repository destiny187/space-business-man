class_name FrontierPlanetMap
extends PanelContainer
var app: FrontierCrewExpedition
var canvas: Control
var title: Label
var detail: Label
var layers: OptionButton
var body: Dictionary={}
var site: Dictionary={}
var terrain: FrontierTerrainField
var texture: ImageTexture
var cached_id: String=""
var map_key: String=""
const MapBake=preload("res://scripts/ui/planet_map_bake.gd")
var bake_job: RefCounted
var bake_task: int=-1
var map_min:=Vector2.ZERO
var map_size:=Vector2.ONE
var focus:=Vector2.ZERO
var meters_per_pixel:=3.0
var dragging:=false
var selected: String=""
var waypoint:=Vector2.INF
var timer:=0.0
var groups: Array=[]
var terraform: FrontierTerraformPanel
var modes: TabBar
var map_bar: HBoxContainer
func configure(owner_app: FrontierCrewExpedition) -> void:
 app=owner_app;name="PlanetMap";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);offset_left=24;offset_top=28;offset_right=-24;offset_bottom=-28
 theme=app.ui_theme
 var column:=VBoxContainer.new();add_child(column)
 var header:=HBoxContainer.new();column.add_child(header)
 title=FrontierInterfaceStyle.label(header,"행성지도",22);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var system:=Button.new();system.text="항성계";header.add_child(system);system.pressed.connect(func():app.open_menu(app.navigation_frame))
 var close:=Button.new();close.text="닫기  Tab / Esc";header.add_child(close);close.pressed.connect(app.close_menus)
 modes=TabBar.new();modes.add_tab("행성지도");modes.add_tab("테라포밍");column.add_child(modes)
 var bar:=HBoxContainer.new();column.add_child(bar);map_bar=bar
 layers=OptionButton.new()
 for text in ["자원·지질","환경·복원","시설·공급","기상·대피"]:layers.add_item(text)
 bar.add_child(layers);layers.item_selected.connect(func(_i):update_detail();canvas.queue_redraw())
 var home:=Button.new();home.text="내 위치";bar.add_child(home);home.pressed.connect(func():focus=Vector2(app.camera.position.x,app.camera.position.z);canvas.queue_redraw())
 for pair in [["−",1.4],["+",1.0/1.4]]:
  var button:=Button.new();button.text=pair[0];bar.add_child(button);button.pressed.connect(func():zoom(float(pair[1])))
 FrontierInterfaceStyle.label(bar,"드래그 이동   휠 확대   클릭 목적지",12,FrontierInterfaceStyle.MUTED)
 canvas=Control.new();canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL;canvas.custom_minimum_size=Vector2(300,200);canvas.clip_contents=true;column.add_child(canvas)
 canvas.draw.connect(draw_map);canvas.gui_input.connect(input_map)
 detail=FrontierInterfaceStyle.label(column,"지도를 선택하면 공급·복원 정보를 확인합니다.",16);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size.y=78
 terraform=FrontierTerraformPanel.new();column.add_child(terraform);terraform.configure(app);terraform.hide()
 modes.tab_changed.connect(func(i):map_bar.visible=i==0;canvas.visible=i==0;detail.visible=i==0;terraform.visible=i==1;refresh())
 hide()
func refresh() -> void:
 if app.surface_world==null:hide();return
 body=app.surface_world.body;terrain=app.surface_world.terrain.field
 site=app.session.surface.get("business",{}).get("sites",{}).get(body.id,{})
 title.text=body.name+"  T%d  행성지도"%int(body.planet_tier)
 if modes.current_tab==1:terraform.refresh();return
 if cached_id!=body.id:
  texture=null;map_key=""
  cached_id=body.id;focus=Vector2(app.camera.position.x,app.camera.position.z);groups=[];waypoint=Vector2.INF;selected=""
 _finish_bake()
 var bake_key:=_bake_key()
 if bake_task<0 and bake_key!=map_key and canvas.size.x>0:
  bake_job=MapBake.new()
  var extent:=canvas.size*meters_per_pixel
  bake_job.configure(terrain,body,focus-extent*.5,extent,bake_key)
  bake_task=WorkerThreadPool.add_task(bake_job.run,false,"Planet map")
 update_detail();canvas.queue_redraw()
func _bake_key() -> String:
 return str([cached_id,terrain.seed_value,(focus/32).floor(),meters_per_pixel,canvas.size])
func _finish_bake() -> void:
 if bake_task<0 or not WorkerThreadPool.is_task_completed(bake_task):return
 WorkerThreadPool.wait_for_task_completion(bake_task);bake_task=-1
 # Navigation may have changed while the worker was drawing. Never install a stale map.
 if terrain!=null and bake_job.key==_bake_key():
  texture=ImageTexture.create_from_image(bake_job.result)
  map_key=bake_job.key;map_min=bake_job.map_min;map_size=bake_job.map_size
  canvas.queue_redraw()
 bake_job=null
func _exit_tree() -> void:
 if bake_task>=0:WorkerThreadPool.wait_for_task_completion(bake_task);bake_task=-1;bake_job=null
func _process(dt: float) -> void:
 _finish_bake()
 if not visible:return
 timer-=dt
 if timer<=0:timer=.5;refresh()
func at(p: Vector2) -> Vector2:return canvas.size*.5+(p-focus)/meters_per_pixel
func world(p: Vector2) -> Vector2:return focus+(p-canvas.size*.5)*meters_per_pixel
func zoom(factor: float) -> void:
 meters_per_pixel=clampf(meters_per_pixel*factor,.25,32);canvas.queue_redraw()
func input_map(event: InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:zoom(1/1.2)
  elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:zoom(1.2)
  elif event.button_index==MOUSE_BUTTON_LEFT:
   dragging=event.pressed
   if event.pressed:
    waypoint=world(event.position);selected=""
    for region in site.get("regions",{}).values():
     if at(Vector2(region.center[0],region.center[2])).distance_to(event.position)<maxf(18,region.radius/meters_per_pixel):selected=region.id
    for clue in app.session.latest.get("coopertech_clues",{}).values():
     if clue.body_id==body.id and at(Vector2(clue.position[0],clue.position[2])).distance_to(event.position)<22:selected=clue.id;waypoint=Vector2(clue.position[0],clue.position[2])
    update_detail();canvas.queue_redraw()
 elif event is InputEventMouseMotion and dragging:
  focus-=event.relative*meters_per_pixel;focus=focus.clamp(Vector2(-8192,-8192),Vector2(8192,8192));canvas.queue_redraw()
 canvas.accept_event()
func text_at(p: Vector2,text: String,color: Color=Color("e6e8df"),font_size: int=16) -> void:
 canvas.draw_string(get_theme_default_font(),p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func draw_map() -> void:
 if body.is_empty():return
 canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("10191f"))
 if texture!=null:canvas.draw_texture_rect(texture,Rect2(at(map_min),map_size/meters_per_pixel),false,Color(1,1,1,.85))
 var spacing:=1000.0 if meters_per_pixel>4 else 100.0
 var minp:=world(Vector2.ZERO);var maxp:=world(canvas.size)
 for x in range(floori(minp.x/spacing),ceili(maxp.x/spacing)+1):canvas.draw_line(at(Vector2(x*spacing,minp.y)),at(Vector2(x*spacing,maxp.y)),Color(1,1,1,.08))
 for z in range(floori(minp.y/spacing),ceili(maxp.y/spacing)+1):canvas.draw_line(at(Vector2(minp.x,z*spacing)),at(Vector2(maxp.x,z*spacing)),Color(1,1,1,.08))
 if layers.selected==0 and FrontierSurfaceRegions.enabled(body):
  var span: float=body.regional_rules.region_span
  for x in range(maxi(-13,floori(minp.x/span)),mini(13,ceili(maxp.x/span))+1):
   for z in range(maxi(-13,floori(minp.y/span)),mini(13,ceili(maxp.y/span))+1):
    var group:=FrontierSurfaceRegions.cluster(body,x,z);var pos:=at(group.center)
    canvas.draw_circle(pos,maxf(3,span*.20/meters_per_pixel),Color(.78,.66,.39,.12))
    canvas.draw_arc(pos,maxf(3,span*.20/meters_per_pixel),0,TAU,24,Color(.87,.74,.45,.4),1,true)
    var icon:=FrontierResourceIcons.texture(group.resource)
    if icon!=null:canvas.draw_texture_rect(icon,Rect2(pos-Vector2(14,14),Vector2(28,28)),false)
    if meters_per_pixel<6:text_at(pos+Vector2(20,5),FrontierCatalog.entry("resources",group.resource).name+" ?",Color("e1bd74"),15)
 if layers.selected==0:
  var hints: Dictionary={}
  for row in FrontierGroundExploration.deposits(body):
   if not hints.has(row.resource):hints[row.resource]=Vector2(row.position[0],row.position[2])
  for resource in hints:
   var point:=at(hints[resource]);var icon:=FrontierResourceIcons.texture(resource)
   canvas.draw_arc(point,16,0,TAU,20,Color("83d9c5"),1,true)
   if icon!=null:canvas.draw_texture_rect(icon,Rect2(point-Vector2(12,12),Vector2(24,24)),false)
   text_at(point+Vector2(20,4),FrontierCatalog.entry("resources",resource).name+" 공급 후보",Color("83d9c5"),15)
  for observation in app.session.latest.crew.get("survey",{}).values():
   if observation.body_id!=body.id:continue
   var row:=FrontierExpeditionBusiness.find_vein(body,observation.vein_id)
   if row.is_empty() or row.get("underground",false):continue
   var point:=at(Vector2(row.position[0],row.position[2]));canvas.draw_circle(point,4,Color.WHITE)
   if meters_per_pixel<2:text_at(point+Vector2(8,20),"확인 잔량 %d"%int(site.get("remaining",{}).get(row.id,row.capacity)),Color.WHITE,14)
 for region in ([] if FrontierFreeTerraform.active(site) else site.get("regions",{}).values()):
  var center:=Vector2(region.center[0],region.center[2]);var pos:=at(center)
  var color:=Color("83d9c5") if FrontierRegionalTerraform.ready(region) else Color("efb46f")
  canvas.draw_arc(pos,maxf(10,float(region.radius)/meters_per_pixel),0,TAU,40,color,2,true)
  if layers.selected==1:
   for cell in region.cells:
    var cell_pos:=at(Vector2(cell.position[0],cell.position[2]));var score:=FrontierEvaluator.environment_report(cell)
    canvas.draw_circle(cell_pos,maxf(3,24/meters_per_pixel),Color(.22,.8,.56,.15+.55*float(score.overall)/100).lerp(Color(.85,.32,.18,.7),clampf(float(cell.get("pollution",0))/60,0,1)))
  text_at(pos+Vector2(maxf(18,float(region.radius)/meters_per_pixel)+8,-12),region.name,color)
  text_at(pos+Vector2(maxf(18,float(region.radius)/meters_per_pixel)+8,8),"✓ 안정" if FrontierRegionalTerraform.ready(region) else "복원 대기",color,14)
  if not site.has("tier3") and region.id!="region:0":canvas.draw_dashed_line(at(Vector2(site.regions["region:0"].center[0],site.regions["region:0"].center[2])),pos,Color(.6,.8,.8,.3),1,6)
 if site.has("tier3") and not FrontierFreeTerraform.active(site):
  for edge in [["region:1","region:2"],["region:2","region:3"]]:
   var a: Array=site.regions[edge[0]].center;var b: Array=site.regions[edge[1]].center
   var start:=at(Vector2(a[0],a[2]));var finish:=at(Vector2(b[0],b[2]));var direction: Vector2=(finish-start).normalized()
   var tint:=Color("efb46f").lerp(Color("83d9c5"),float(site.tier3.suppression))
   canvas.draw_dashed_line(start,finish,tint,2,8)
   var tip:=start.lerp(finish,.55);canvas.draw_line(tip,tip-direction.rotated(.5)*14,tint,2);canvas.draw_line(tip,tip-direction.rotated(-.5)*14,tint,2)
  text_at(Vector2(12,24),site.tier3.rules.profiles[site.tier3.profile].name+"  원인 → 영향 지역",Color("efb46f"),15)
 for row in site.get("buildings",{}).values():
  var pos:=at(Vector2(row.position[0],row.position[2]));canvas.draw_rect(Rect2(pos-Vector2(3,3),Vector2(6,6)),Color("83d9c5") if row.active else Color("efb46f"))
  if layers.selected==2 and int(row.get("tier",1))==3:canvas.draw_arc(pos,48/meters_per_pixel,0,TAU,32,Color(.4,.8,.7,.3),1,true)
  if layers.selected==2 and meters_per_pixel<3:text_at(pos+Vector2(8,0),FrontierCatalog.entry("buildings",row.type).name,Color("e6e8df"),11)
 if layers.selected==3:
  var weather: Dictionary=app.session.latest.get("weather",{});var front: Dictionary=weather.get("event",{})
  if not front.is_empty():
   var center:=at(Vector2(front.center[0],front.center[2]));var radius:=float(FrontierPlanetWeather.config().front_radius)/meters_per_pixel
   canvas.draw_circle(center,radius,Color(.7,.55,.25,.12));canvas.draw_arc(center,radius,0,TAU,64,Color("edbe81"),2,true)
   text_at(center+Vector2(12,-14),{"rain":"雨 · 비","acid":"산성비","thunder":"뇌우"}.get(front.kind,"기상"),Color("edbe81"),14)
  for row in site.get("buildings",{}).values():
   var point:=at(Vector2(row.position[0],row.position[2]))
   if row.type=="grounding_mast":canvas.draw_arc(point,float(FrontierPlanetWeather.config().mast_radius)/meters_per_pixel,0,TAU,32,Color("8ae0bb"),2,true);text_at(point+Vector2(8,-8),"접지",Color("8ae0bb"),13)
   elif row.type=="field_canopy":canvas.draw_rect(Rect2(point-Vector2(6,5),Vector2(12,10)),Color("8ad6df"),false,2);text_at(point+Vector2(9,0),"차양",Color("8ad6df"),13)
 for id in app.session.latest.get("crew",{}).get("members",{}):
  var member: Dictionary=app.session.latest.crew.members[id]
  if member.get("place_key","")!=app.session.latest.crew.members[app.session.latest.self_id].get("place_key",""):continue
  var pos:=at(Vector2(member.position[0],member.position[2]));canvas.draw_circle(pos,5,Color("83d9c5") if id==app.session.latest.self_id else Color("e6e8df"))
 var ship: Array=FrontierCrewSurface.config().ship_position;text_at(at(Vector2(ship[0],ship[2]))+Vector2(8,20),"착륙선",Color("a5c9ff"))
 for clue in app.session.latest.get("coopertech_clues",{}).values():
  if clue.body_id!=body.id:continue
  var pos:=at(Vector2(clue.position[0],clue.position[2]));var tint:=Color("94edcf") if int(clue.stage)==2 else Color("ffb16e")
  canvas.draw_texture_rect(load(FrontierCorporations.icon_path("coopertech")),Rect2(pos-Vector2(16,16),Vector2(32,32)),false)
  canvas.draw_arc(pos,20,0,TAU,24,tint,2,true);text_at(pos+Vector2(25,5),FrontierCooperTechClues.STATES[int(clue.stage)],tint,14)
 if waypoint.is_finite():
  var pos:=at(waypoint);canvas.draw_line(pos-Vector2(8,0),pos+Vector2(8,0),Color.WHITE,2);canvas.draw_line(pos-Vector2(0,8),pos+Vector2(0,8),Color.WHITE,2)
 text_at(Vector2(12,canvas.size.y-12),"N ↑   후보 범위 ? / 실제 확인 전 잔량 미확정   ·   지원 지표 ±8.2km",Color("e6e8df"),12)
func show_clue(clue: Dictionary) -> void:
 modes.current_tab=0;refresh();selected=clue.id;waypoint=Vector2(clue.position[0],clue.position[2]);focus=waypoint;app.open_menu(self);refresh();update_detail()
func update_detail() -> void:
 if layers.selected==3:
  var weather: Dictionary=app.session.latest.get("weather",{});var front: Dictionary=weather.get("event",{})
  detail.text="기상 관측이 없는 기존 세계" if weather.is_empty() else str(weather.profile.name)+" · 차양은 비, 접지봉은 18m 안 자연 낙뢰를 차단합니다."
  if not front.is_empty():detail.text+="\n"+("도착까지 %.0f초"%maxf(0,float(front.start)-float(weather.clock)) if float(weather.clock)<float(front.start) else "소강까지 %.0f초"%maxf(0,float(front.end)-float(weather.clock)))+" · E로 하늘 관측 / J 발견 기록"
  return
 var clue: Dictionary=app.session.latest.get("coopertech_clues",{}).get(selected,{})
 if not clue.is_empty() and clue.body_id==body.id:
  detail.text="CooperTech  ·  "+FrontierCooperTechClues.STATES[int(clue.stage)]+"\n좌표 %.0f, %.0f · 현장까지 %.0fm"%[clue.position[0],clue.position[2],Vector2(clue.position[0],clue.position[2]).distance_to(Vector2(app.camera.position.x,app.camera.position.z))];return
 if FrontierFreeTerraform.active(site):detail.text=FrontierFreeTerraform.detail(site)+"\n대기·수질·토양·오염 분포는 테라포밍 탭에서 확인하세요.";return
 if selected.is_empty() or not site.get("regions",{}).has(selected):
  detail.text="공급 후보는 지질 추정입니다. 현장에서 광맥과 잔량을 확인하세요.\n"+("목적지 %.0fm  좌표 %.0f, %.0f"%[waypoint.distance_to(Vector2(app.camera.position.x,app.camera.position.z)),waypoint.x,waypoint.y] if waypoint.is_finite() else "환경 탭에서 복원 구획, 시설 탭에서 현장 공급을 확인합니다.")
  return
 var region: Dictionary=site.regions[selected];var report:=FrontierEvaluator.environment_report(region)
 var names: Array=[]
 for key in region.inventory:
  if int(region.inventory[key])>0:names.append(FrontierCatalog.entry("resources",key).name+" "+str(int(region.inventory[key])))
 detail.text="%s  적합도 %.0f%%   %s\n현장 재고: %s\n%s"%[region.name,report.overall,"✓ 안정" if FrontierRegionalTerraform.ready(region) else ({"settlement":"정착 환경", "water":"급수·염류", "soil":"토양 기반"}.get(region.role,"환경")+" 구획 %d곳 · 30초 안정"%mini(3,region.cells.size())),", ".join(names) if not names.is_empty() else "비어 있음",("중간 대금 지급 완료 %d Cr"%int(site.regional_paid[selected])) if site.get("regional_paid",{}).has(selected) else "원료는 직접 운반하고 이 현장의 창고에 보관하세요."]

 if site.has("tier3"):
  var item: String=site.tier3.rules.profiles[site.tier3.profile].item
  var packs: int=5 if region.role=="source" else 10
  detail.text="%s  %s\n%s\n%s · 10분 공급 참고 %s %d개%s"%[region.name,"✓ 안정" if FrontierRegionalTerraform.ready(region) else "목표 구획 3곳 · 45초 유지",FrontierTerraformTier3.detail(site,region),"현장 재고: "+", ".join(names.slice(0,4)) if not names.is_empty() else "현장 창고에 직접 공급",FrontierProductionTier2.product(item).name,packs," · 정착 팩 별도" if region.role=="recovery" else ""]
