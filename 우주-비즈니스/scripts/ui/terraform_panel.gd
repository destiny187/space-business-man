class_name FrontierTerraformPanel
extends VBoxContainer
## Instrument visualization: the same host cells drive globe, local map and world shading.
var app: FrontierCrewExpedition
var body: Dictionary={}
var site: Dictionary={}
var canvas: Control
var info: Label
var legend: Label
var layer:=0
var rotation_y:=0.0
var rotation_x:=-.1
var globe_zoom:=1.0
var focus:=Vector2.ZERO
var meters:=1.0
var dragging:=false
var drag_globe:=false
var chosen:=Vector2.INF
var terrain_texture: ImageTexture
var terrain_key:=""
var terrain_min:=Vector2.ZERO
var terrain_size:=Vector2.ZERO
var cached_body:=""
var globe_relief: Array=[]
var clock:=0.0
var buttons: Array[Button]=[]
func configure(owner_app: FrontierCrewExpedition) -> void:
 app=owner_app;size_flags_vertical=Control.SIZE_EXPAND_FILL
 var row:=HBoxContainer.new();add_child(row)
 for i in 4:
  var b:=Button.new();b.text=["대기","수질","토양","오염원"][i];b.toggle_mode=true;b.button_pressed=i==0;b.icon=load("res://assets/ui/previews/"+["atmosphere","water","biolab","terraform3/source_control"][i]+".png");b.expand_icon=true;b.custom_minimum_size=Vector2(104,40);b.add_theme_constant_override("icon_max_width",30);row.add_child(b);buttons.append(b)
  b.pressed.connect(func():layer=i;for_buttons();refresh())
 var home:=Button.new();home.text="내 위치";row.add_child(home);home.pressed.connect(func():focus=Vector2(app.camera.position.x,app.camera.position.z);chosen=focus;refresh())
 var source:=Button.new();source.text="오염 구역";row.add_child(source);source.pressed.connect(func():
  if site.has("tier3"):
   var p: Array=site.free_terraform.source if FrontierFreeTerraform.active(site) else site.regions["region:1"].center
   focus=Vector2(p[0],p[2]);chosen=focus;layer=3;for_buttons();refresh())
 canvas=Control.new();canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL;canvas.custom_minimum_size=Vector2(300,230);canvas.clip_contents=true;add_child(canvas);canvas.draw.connect(draw_view);canvas.gui_input.connect(input_view)
 legend=FrontierInterfaceStyle.label(self,"",13,FrontierInterfaceStyle.MUTED)
 info=FrontierInterfaceStyle.label(self,"",15);info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.custom_minimum_size.y=66
func for_buttons() -> void:
 for i in buttons.size():buttons[i].button_pressed=i==layer
func _process(dt: float) -> void:
 if not is_visible_in_tree():return
 clock-=dt
 if clock<=0:clock=.5;refresh()
func refresh() -> void:
 if app.surface_world==null:return
 body=app.surface_world.body;site=app.session.surface.get("business",{}).get("sites",{}).get(body.id,{})
 if cached_body!=body.id:cached_body=body.id;focus=Vector2(app.camera.position.x,app.camera.position.z);chosen=focus;terrain_key="";globe_relief=[]
 if not FrontierFreeTerraform.active(site):info.text="기존 저장의 지역 복원 규칙입니다. 자유 배치·구면 분포는 새 세계에 적용됩니다.";canvas.queue_redraw();return
 if globe_relief.is_empty():
  var cfg: Dictionary=site.free_terraform.rules;var f:=app.surface_world.terrain.field
  for z in int(cfg.air_rows):
   for x in int(cfg.air_columns):
    var p:=Vector2((x+.5)/float(cfg.air_columns)*2-1,(z+.5)/float(cfg.air_rows)*2-1)*float(cfg.extent)
    var h:=f.height(p.x,p.y);globe_relief.append(clampf((h+20)/120,0,1))
 var rect:=local_rect();terrain_size=rect.size*meters;terrain_min=focus-terrain_size*.5
 var key: String=body.id+str((focus/12).floor())+str(meters)+str(rect.size)+str(layer)
 if key!=terrain_key and rect.size.x>0:
  terrain_key=key;var image:=Image.create(100,100,false,Image.FORMAT_RGB8);var field:=app.surface_world.terrain.field
  for z in 100:
   for x in 100:
    var p:=terrain_min+Vector2(x/100.0,z/100.0)*terrain_size;var h:=field.height(p.x,p.y);var slope:=field.height(p.x+8,p.y)-h
    var color:=Color("3c4744").lerp(Color("9e947d"),clampf((h+40)/150,0,1)).lightened(clampf(slope*.025,-.15,.15))
    if layer==1:color=color.lerp(Color("448eaa"),clampf((FrontierFreeTerraform.water_gain(site,body,p)-1)/.75,0,1)*.7)
    if fposmod(h,10)<.65:color=color.darkened(.22)
    image.set_pixel(x,z,color)
  terrain_texture=ImageTexture.create_from_image(image)
 legend.text=["대기: 낮은 적합도 → 높은 적합도    구체 드래그 회전 / 오른쪽 지도 드래그·휠 확대","수질: 주황 부족 → 청록 확보    저지대 이점과 실제 침수는 별도 판정","토양: 갈색 미개량 → 녹색 개량    사각 구획 합집합 · 중첩 효과 없음","오염: 보라 고정 작업 구역 / 주황 잔류 오염    구역 안에서만 전문 처리"][layer]
 var p:=chosen if chosen.is_finite() else focus;var cell:=FrontierFreeTerraform.sample(site,p)
 info.text=FrontierFreeTerraform.detail(site)+"\n"
 if layer==0:info.text+="선택 지점 산소 %.1f%% · 기압 %.2f bar · 독성 %.1f"%[float(cell.environment.oxygen)*100,float(cell.environment.pressure),float(cell.environment.toxicity)]
 elif layer==1:info.text+="선택 지점 급수 %.0f · 염류 %.0f · 저지대 효율 ×%.2f · 실제 수면은 현장 확인"%[float(cell.environment.water),float(cell.restoration2.salinity),FrontierFreeTerraform.water_gain(site,body,p)]
 elif layer==2:info.text+="선택 지점 토양 %.0f · 생태 %.0f · 정착 %.0f%%"%[float(cell.restoration2.soil),float(cell.environment.ecology),float(cell.colonization)]
 else:info.text+="선택 지점 "+("오염 작업 구역 내부" if FrontierFreeTerraform.in_pollution(site,p) else "오염 작업 구역 외부")+" · 잔류 %.1f"%float(cell.pollution)
 if int(site.free_terraform.tier)==4 and layer==3:info.text+=" · %.1f°C · "%float(cell.environment.temperature)+site.tier3.rules.profiles[site.tier3.profile].name
 canvas.queue_redraw()
func local_rect() -> Rect2:return Rect2(Vector2(canvas.size.x*.43,38),Vector2(canvas.size.x*.57-16,maxf(40,canvas.size.y-72)))
func globe_center() -> Vector2:return Vector2(canvas.size.x*.215,canvas.size.y*.50)
func globe_radius() -> float:return minf(canvas.size.x*.195,canvas.size.y*.39)*globe_zoom
func basis_view() -> Basis:return Basis(Vector3.RIGHT,rotation_x)*Basis(Vector3.UP,rotation_y)
func project(v: Vector3) -> Vector2:return globe_center()+Vector2(v.x,-v.y)*globe_radius()
func at(p: Vector2) -> Vector2:return local_rect().get_center()+(p-focus)/meters
func from_map(p: Vector2) -> Vector2:return focus+(p-local_rect().get_center())*meters
func text_at(p: Vector2,s: String,color: Color=Color("e6e8df"),size: int=14) -> void:canvas.draw_string(get_theme_default_font(),p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func color_for(cell: Dictionary) -> Color:
 var e: Dictionary=cell.environment;var r: Dictionary=cell.get("restoration2",{})
 var amount:=0.0
 if layer==0:amount=float(FrontierEvaluator.scores(e).atmosphere)/100
 elif layer==1:amount=minf(float(e.water)/100,1-float(r.get("salinity",0))/100)
 elif layer==2:amount=float(r.get("soil",0))/100
 else:return Color("467277").lerp(Color("ed814e"),clampf(float(cell.get("pollution",0))/60,0,1))
 return Color("b46742").lerp(Color("72cbb3") if layer<2 else Color("82be70"),clampf(amount,0,1))
func draw_view() -> void:
 canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("10191f"))
 if not FrontierFreeTerraform.active(site):
  text_at(Vector2(24,50),"기존 지역 지도에서 복원 현장을 확인하세요.");return
 var rect:=local_rect();var cfg: Dictionary=site.free_terraform.rules;var view:=basis_view()
 canvas.draw_circle(globe_center(),globe_radius()+4,Color("03090d"));canvas.draw_circle(globe_center(),globe_radius()+1,Color("355b67"))
 var cols:=int(cfg.air_columns);var rows:=int(cfg.air_rows)
 for z in rows:
  for x in cols:
   var corners:=PackedVector2Array();var visible_count:=0;var depth:=0.0
   for offset in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
    var sy: float=(z+offset.y)/rows*2-1;var lon: float=(x+offset.x)/cols*TAU-PI;var ring:=sqrt(maxf(0,1-sy*sy));var v: Vector3=view*Vector3(sin(lon)*ring,sy,cos(lon)*ring)
    if v.z>=0:visible_count+=1
    depth+=v.z*.25;corners.append(project(v))
   if visible_count<4:continue
   var a: Array=site.free_terraform.air[z*cols+x]
   var e: Dictionary=site.free_terraform.base.duplicate();e.oxygen=a[0];e.pressure=a[1];e.toxicity=a[2]
   var tint:=color_for({"environment":e,"restoration2":site.free_terraform.restoration}) if layer==0 else Color("263c44")
   var relief: float=globe_relief[z*cols+x] if globe_relief.size()==cols*rows else .5
   tint=tint.lerp(Color("375968").lerp(Color("b2a886"),relief),.22 if layer==0 else .45)
   var light:=.55 if depth<.25 else (.78 if depth<.65 else 1.0)
   canvas.draw_colored_polygon(corners,tint*Color(light,light,light,1))
 # Geographic graticule makes orientation and rotation readable without fixed worksite pins.
 for latitude in [-.75,-.5,0.0,.5,.75]:
  for n in 96:
   var a:=n*TAU/96;var b: float=(n+1)*TAU/96;var ring:=sqrt(1-float(latitude)*float(latitude))
   var va: Vector3=view*Vector3(sin(a)*ring,latitude,cos(a)*ring);var vb: Vector3=view*Vector3(sin(b)*ring,latitude,cos(b)*ring)
   if va.z>0 and vb.z>0:canvas.draw_line(project(va),project(vb),Color(.8,.9,.9,.13),1,true)
 for meridian in 8:
  for n in 48:
   var a: float=n*PI/48-PI*.5;var b: float=(n+1)*PI/48-PI*.5;var lon:=meridian*TAU/8
   var va: Vector3=view*Vector3(sin(lon)*cos(a),sin(a),cos(lon)*cos(a));var vb: Vector3=view*Vector3(sin(lon)*cos(b),sin(b),cos(lon)*cos(b))
   if va.z>0 and vb.z>0:canvas.draw_line(project(va),project(vb),Color(.8,.9,.9,.13),1,true)
 if layer>0:
  for cell in site.free_terraform.cells.values():
   var p:=Vector2(cell.position[0],cell.position[2]);var v: Vector3=view*FrontierFreeTerraform.globe_vector(site,p)
   if v.z>0:canvas.draw_circle(project(v),maxf(1.5,globe_radius()*.004),color_for(cell))
 var player:=Vector2(app.camera.position.x,app.camera.position.z);var pv: Vector3=view*FrontierFreeTerraform.globe_vector(site,player)
 if pv.z>0:canvas.draw_arc(project(pv),6,0,TAU,16,Color.WHITE,2,true)
 text_at(Vector2(16,22),"행성 구체 · "+["대기 적합도","수질 상태","토양 개량","잔류 오염"][layer],Color("83d9c5"),16)
 text_at(Vector2(16,canvas.size.y-12),"밝은 점: 현장 기록  /  어두운 지표: 초기 상태",Color("a6b6b9"),11)
 if terrain_texture!=null:canvas.draw_texture_rect(terrain_texture,rect,false)
 text_at(rect.position+Vector2(10,-12),"현장 확대 · %.0f m 폭"%(rect.size.x*meters),Color("83d9c5"),16)
 # Cell boundaries remain an instrument overlay; placement is not snapped to their centers.
 for cell in site.free_terraform.cells.values():
  var p:=at(Vector2(cell.position[0],cell.position[2]));var side:=float(cfg.cell_size)/meters
  var square:=Rect2(p-Vector2.ONE*side*.5,Vector2.ONE*side).intersection(rect)
  if not square.has_area():continue
  var tint:=color_for(cell);tint.a=.58;canvas.draw_rect(square,tint)
  if side>7:canvas.draw_rect(square,Color(1,1,1,.09),false,1)
 if site.has("tier3"):
  var center: Array=site.free_terraform.source;var p:=at(Vector2(center[0],center[2]));var rad: float=cfg.pollution_radius/meters
  if rect.encloses(Rect2(p-Vector2.ONE*rad,Vector2.ONE*rad*2)):canvas.draw_arc(p,rad,0,TAU,80,Color("c394da"),2,true)
  if rect.has_point(p):text_at(p+Vector2(8,-8),"오염 작업 구역",Color("e3b6f5"),13)
 for b in site.buildings.values():
  var p:=at(Vector2(b.position[0],b.position[2]))
  if not rect.has_point(p):continue
  var wanted: String=["atmosphere","water","biolab","source_control"][layer]
  var tint:=Color("83d9c5") if b.get("active",false) else Color("ed814e")
  if b.get("submerged",false):tint=Color("619bd7")
  canvas.draw_rect(Rect2(p-Vector2(3,3),Vector2(6,6)),tint)
  if b.type==wanted:
   var r:=FrontierFreeTerraform.radius(site,b)/meters
   if rect.encloses(Rect2(p-Vector2.ONE*r,Vector2.ONE*r*2)):canvas.draw_arc(p,r,0,TAU,40,tint,1,true)
 var player_at:=at(player)
 if rect.has_point(player_at):canvas.draw_circle(player_at,4,Color.WHITE)
 if chosen.is_finite() and rect.has_point(at(chosen)):
  var p:=at(chosen);canvas.draw_line(p-Vector2(7,0),p+Vector2(7,0),Color.WHITE,1);canvas.draw_line(p-Vector2(0,7),p+Vector2(0,7),Color.WHITE,1)
 canvas.draw_rect(rect,Color("658c91"),false,1)
func input_view(event: InputEvent) -> void:
 if event is InputEventMouseButton:
  var on_map:=local_rect().has_point(event.position)
  if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
   var factor:=1.2 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else 1/1.2
   if on_map:meters=clampf(meters*factor,.3,24)
   else:globe_zoom=clampf(globe_zoom/factor,.5,1.15)
   refresh()
  if event.button_index==MOUSE_BUTTON_LEFT:
   dragging=event.pressed;drag_globe=not on_map
   if on_map and event.pressed:chosen=from_map(event.position);refresh()
 elif event is InputEventMouseMotion and dragging:
  if drag_globe:rotation_y+=event.relative.x*.008;rotation_x=clampf(rotation_x+event.relative.y*.008,-1.3,1.3)
  else:focus=(focus-event.relative*meters).clamp(Vector2(-8192,-8192),Vector2(8192,8192))
  canvas.queue_redraw()
 canvas.accept_event()
