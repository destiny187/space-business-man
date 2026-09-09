class_name FrontierStationMarketPanel
extends PanelContainer
var preview_dirty:=true
signal command(kind: String,args: Dictionary)
var data: Dictionary={}
var mode: String="goods"
var selected: String=""
var pending:=false
var pending_sequence: int=-1
var pending_kind: String=""
var heading: Label
var money: Label
var message: Label
var browser: FrontierItemBrowser
var sale_only: CheckButton
var empty: Label
var unit_price: Label
var grid: GridContainer
var title_label: Label
var role: Label
var quantity: SpinBox
var buy: Button
var sell: Button
var bars: VBoxContainer
var preview: SubViewport
var preview_root: Node3D
var preview_camera: Camera3D
var preview_model: Node3D
var picture: TextureRect
var icon: TextureRect
var audio: FrontierAudio
var hum: AudioStreamPlayer
var last_state: String=""
func _ready() -> void:
 theme=FrontierInterfaceStyle.theme()
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 offset_left=24;offset_right=-24;offset_top=24;offset_bottom=-24
 add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,18))
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);add_child(column)
 var header:=HBoxContainer.new();column.add_child(header)
 heading=label(header,"WAYFARER · 교역",24);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 money=label(header,"",18);money.autowrap_mode=TextServer.AUTOWRAP_OFF;money.custom_minimum_size.x=120;money.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 button(header,"닫기  Esc",hide)
 var tabs:=HBoxContainer.new();column.add_child(tabs)
 for tab in [["goods","물자 거래"],["ships","선체 구매"],["owned","보유 선체"]]:
  var key: String=tab[0]
  button(tabs,tab[1],func():mode=key;selected="";rebuild())
 browser=FrontierItemBrowser.new();column.add_child(browser);browser.order.hide();browser.search.placeholder_text="상품 · 선체 이름 검색";browser.changed.connect(rebuild)
 sale_only=CheckButton.new();sale_only.text="내가 판매할 수 있는 물자";column.add_child(sale_only);sale_only.toggled.connect(func(_v):rebuild())
 var body:=HBoxContainer.new();body.add_theme_constant_override("separation",24);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
 var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(list)
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;list.add_child(scroll)
 grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(grid)
 empty=label(list,"조건에 맞는 상품이 없습니다.",14)
 var detail:=VBoxContainer.new();detail.custom_minimum_size.x=300;detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail.add_theme_constant_override("separation",6);body.add_child(detail)
 var detail_scroll:=ScrollContainer.new();detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail.add_child(detail_scroll)
 var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.add_child(content)
 var selected_row:=HBoxContainer.new();content.add_child(selected_row)
 var selected_text:=VBoxContainer.new();selected_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;selected_row.add_child(selected_text)
 title_label=label(selected_text,"상품 선택",25);role=label(selected_text,"",14)
 preview=SubViewport.new();preview.size=Vector2i(560,300);preview.own_world_3d=true;preview.transparent_bg=true;preview.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(preview)
 preview_root=Node3D.new();preview.add_child(preview_root)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-35,0);light.light_energy=1.6;preview_root.add_child(light)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("10191f");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("a0bbc3");environment.environment.ambient_light_energy=.45;preview_root.add_child(environment)
 preview_camera=Camera3D.new();preview_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;preview_camera.size=13;preview_camera.position=Vector3(18,12,24);preview_root.add_child(preview_camera);preview_camera.look_at(Vector3.ZERO);FrontierInkStyle.attach(preview_camera)
 picture=TextureRect.new();picture.custom_minimum_size.y=130;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.texture=preview.get_texture();content.add_child(picture)
 icon=TextureRect.new();icon.custom_minimum_size=Vector2(96,96);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;selected_row.add_child(icon)
 bars=VBoxContainer.new();bars.add_theme_constant_override("separation",9);content.add_child(bars)
 unit_price=label(detail,"",13)
 quantity=SpinBox.new();quantity.min_value=1;quantity.max_value=1000;quantity.value=1;quantity.prefix="수량 ";quantity.value_changed.connect(func(_v: float):refresh_detail());detail.add_child(quantity)
 buy=button(detail,"구매",func():send("station_equip" if mode=="owned" else "station_buy"))
 sell=button(detail,"판매",func():send("station_sell"))
 message=label(column,"공동 자금 · 구매 물자는 내 아이템창으로 이동",13)
 audio=FrontierAudio.new();add_child(audio)
 hum=AudioStreamPlayer.new();hum.bus="Ambience";hum.stream=audio.stream(FrontierSpaceStation.config().audio.ambience,true);hum.volume_db=-32;add_child(hum)
 visibility_changed.connect(func():
  preview_dirty=true;preview.render_target_update_mode=SubViewport.UPDATE_DISABLED
  if visible:audio.play(FrontierSpaceStation.config().audio.open);hum.play()
  else:hum.stop())
 hide()
func label(parent: Node,text_value: String,font_size: int) -> Label:
 var node:=FrontierInterfaceStyle.label(parent,text_value,font_size);node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return node
func button(parent: Node,text_value: String,callback: Callable) -> Button:
 var node:=Button.new();node.text=text_value;node.custom_minimum_size.y=38;node.pressed.connect(callback);parent.add_child(node);return node
func update_snapshot(value: Dictionary) -> void:
 data=value
 var next:=FrontierUniverse.fingerprint({"station":value.get("station",{}),"inventory":value.get("inventory",{}),"vessel":value.get("vessel",{})})
 if next!=last_state:last_state=next;rebuild()
 # The host can move while another crew member is inspecting the market.
 if visible and (value.get("station",{}).is_empty() or not in_range()):hide()
func in_range() -> bool:
 if data.is_empty() or data.get("station",{}).is_empty():return false
 var nav: Dictionary=data.crew.navigation
 return data.crew.get("landing",{}).is_empty() and nav.mode=="idle" and absf(float(nav.speed))<=5 and FrontierCrewWorld.vector(nav.position).distance_to(FrontierCrewWorld.vector(data.station.position))<=float(FrontierSpaceStation.config().trade_distance)
func rebuild() -> void:
 if grid==null:return
 for node in grid.get_children():grid.remove_child(node);node.queue_free()
 var station: Dictionary=data.get("station",{})
 heading.text=str(station.get("name","WAYFARER"))+" · 교역"
 money.text="%s Cr"%int(station.get("credits",0))
 var items: Array=[]
 if mode=="owned":items=data.get("vessel",{}).get("hulls",["kestrel"]).duplicate()
 else:
  for id in station.get("stock",{}):
   if id.begins_with("hull:")==(mode=="ships"):items.append(id)
 browser.category.visible=mode=="goods";sale_only.visible=mode=="goods"
 items=items.filter(func(id):
  var title: String=FrontierSpaceStation.config().hulls[id.trim_prefix("hull:")].name if mode!="goods" else FrontierCatalog.entry("resources",id).name
  var query:=browser.search.text.strip_edges().to_lower()
  if not query.is_empty() and not title.to_lower().contains(query):return false
  if mode=="goods":
   var count:=int(data.get("inventory",{}).get(id,0))
   if count<=0 and (sale_only.button_pressed or int(station.stock[id])<=0):return false
   if not browser.matches(title,FrontierItemBrowser.kind(id)):return false
  elif mode=="ships" and int(station.stock[id])<=0:return false
  return true)
 empty.visible=items.is_empty()
 if selected not in items:selected=str(items[0]) if not items.is_empty() else ""
 for id in items:
  var is_ship: bool=mode!="goods"
  var def: Dictionary=FrontierSpaceStation.config().hulls[id.trim_prefix("hull:")] if is_ship else FrontierCatalog.entry("resources",id)
  var caption: String=def.name+"\n"+(def.role if is_ship else (("상점 %d"%int(station.stock[id])) if int(station.stock[id])>0 else "상점 품절")+(" · 내 가방 %d"%int(data.inventory[id]) if int(data.get("inventory",{}).get(id,0))>0 else ""))
  var key: String=id
  var card:=button(grid,caption,func():selected=key;refresh_detail())
  card.custom_minimum_size=Vector2(160,100);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  card.icon=load("res://assets/ui/interface/ship.svg") if is_ship else FrontierResourceIcons.texture(id)
  card.expand_icon=true;card.add_theme_constant_override("icon_max_width",40)
  card.clip_text=true;card.tooltip_text=caption;card.set_meta("item",id);card.toggle_mode=true;card.disabled=pending
 refresh_detail()
func refresh_detail() -> void:
 if buy==null:return
 for node in bars.get_children():bars.remove_child(node);node.queue_free()
 var station: Dictionary=data.get("station",{})
 var valid: bool=not selected.is_empty() and not station.is_empty()
 buy.disabled=not valid or pending or data.get("self_id","")!=data.get("crew",{}).get("owner_id","") or not in_range()
 sell.disabled=buy.disabled
 quantity.visible=mode=="goods";sell.visible=mode=="goods";icon.visible=mode=="goods";picture.visible=mode!="goods"
 for card in grid.get_children():card.set_pressed_no_signal(card.get_meta("item")==selected);card.disabled=pending
 if not valid:
  title_label.text="상품 선택";role.text="";unit_price.text="";icon.hide();picture.hide();quantity.hide();buy.hide();sell.hide();preview.render_target_update_mode=SubViewport.UPDATE_DISABLED;return
 buy.show()
 var count:=int(quantity.value)
 if mode=="goods":
  var price:=int(station.prices[selected]);var sale:=maxi(1,floori(price*float(FrontierSpaceStation.config().sale_ratio)))
  title_label.text=FrontierCatalog.entry("resources",selected).name
  role.text=("상점 재고 %d"%int(station.stock[selected]) if int(station.stock[selected])>0 else "상점 품절")+(" · 내 가방 %d"%int(data.inventory[selected]) if int(data.get("inventory",{}).get(selected,0))>0 else "")
  unit_price.text="개당 구매 %d Cr · 판매 %d Cr"%[price,sale]
  icon.texture=FrontierResourceIcons.texture(selected)
  buy.text="구매 · %d Cr"%(price*count);sell.text="판매 · %d Cr"%(sale*count)
  buy.disabled=buy.disabled or int(station.stock[selected])<count or int(station.credits)<price*count
  sell.disabled=sell.disabled or int(data.get("inventory",{}).get(selected,0))<count
 else:
  unit_price.text=""
  var hull_id:=selected.trim_prefix("hull:");var def: Dictionary=FrontierSpaceStation.config().hulls[hull_id]
  title_label.text=def.name;role.text=def.role
  if preview_model==null or preview_model.get_meta("hull","")!=hull_id:
   if is_instance_valid(preview_model):preview_model.queue_free()
   preview_dirty=true
   preview_model=load(def.model).instantiate();preview_model.set_meta("hull",hull_id);FrontierInkStyle.apply(preview_model,{});preview_root.add_child(preview_model)
  for row in [["항속거리",FrontierVesselRefit.stellar_range({"vessel":{"hull":hull_id}}),350.0],["추진",float(def.speed),1.5],["적재",float(def.maximum_mass)-float(def.mass),30.0],["격납고",float(def.hangar),6.0],["전력",float(def.reactor_power),16.0]]:
   var line:=HBoxContainer.new();bars.add_child(line);var name_label:=label(line,row[0],12);name_label.custom_minimum_size.x=58
   var bar:=ProgressBar.new();bar.max_value=row[2];bar.value=row[1];bar.show_percentage=false;bar.custom_minimum_size=Vector2(120,9);bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER;bar.tooltip_text="%s: %.2f"%[row[0],row[1]];line.add_child(bar)
  var vessel: Dictionary=data.get("vessel",{})
  if mode=="owned":
   var equipped: bool=vessel.get("hull","kestrel")==selected
   buy.text="사용 중" if equipped else "이 선체로 교체";buy.disabled=buy.disabled or equipped
  else:
   var owned: bool=hull_id in vessel.get("hulls",["kestrel"])
   buy.text="보유 중" if owned else "선체 구매 · %d Cr"%int(station.prices[selected])
   buy.disabled=buy.disabled or owned or int(station.stock[selected])<=0 or int(station.credits)<int(station.prices[selected])
 if not visible or mode=="goods":preview.render_target_update_mode=SubViewport.UPDATE_DISABLED
func send(kind: String) -> void:
 if pending:return
 pending=true;pending_kind=kind;pending_sequence=-1;message.text="교역 승인 중…";refresh_detail()
 command.emit(kind,{"item":selected,"amount":int(quantity.value) if mode=="goods" else 1})
func response(sequence: int,value: Dictionary) -> void:
 if not pending or sequence!=pending_sequence:return
 pending=false
 var ok: bool=value.get("ok",false)
 message.text=("선체 구매 완료 · 보유 선체에서 교체하세요" if pending_kind=="station_buy" and selected.begins_with("hull:") else "교역 완료" if pending_kind!="station_equip" else "선체 교체 완료") if ok else str(value.get("error","교역 실패"))
 var sounds: Dictionary=FrontierSpaceStation.config().audio
 audio.play(sounds.hull if ok and (pending_kind=="station_equip" or selected.begins_with("hull:")) else sounds.trade if ok else sounds.failure)
 refresh_detail()

func _process(_delta: float) -> void:
 if not is_visible_in_tree() or not picture.visible:
  preview.render_target_update_mode=SubViewport.UPDATE_DISABLED
  return
 if preview_dirty:
  preview_dirty=false;preview.render_target_update_mode=SubViewport.UPDATE_ONCE
  if not RenderingServer.frame_post_draw.is_connected(_preview_rendered):RenderingServer.frame_post_draw.connect(_preview_rendered,CONNECT_ONE_SHOT)
func _preview_rendered() -> void:
 if is_instance_valid(preview):preview.render_target_update_mode=SubViewport.UPDATE_DISABLED
