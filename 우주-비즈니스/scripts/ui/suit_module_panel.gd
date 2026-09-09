class_name FrontierSuitModulePanel
extends VBoxContainer
var app: FrontierCrewExpedition
var slots: HBoxContainer
var grid: GridContainer
var preview: FrontierEquipmentPreview
var detail: VBoxContainer
var equip: Button
var remove: Button
var salvage: Button
var starter: Button
var status: Label
var count: Label
var selected:=""
var signature:=""
var pending:=-1
var member: Dictionary={}
var confirm: ConfirmationDialog
var filter: OptionButton
func configure(owner_app: FrontierCrewExpedition) -> void:
 app=owner_app;name="모듈";add_theme_constant_override("separation",10)
 var top:=HBoxContainer.new();add_child(top)
 count=FrontierInterfaceStyle.label(top,"",14);count.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 filter=OptionButton.new();filter.add_item("전체 부위");top.add_child(filter)
 for slot in FrontierSuitModules.config().slots:filter.add_item(FrontierSuitModules.config().slots[slot].name)
 filter.item_selected.connect(func(_i):signature="")
 slots=HBoxContainer.new();slots.alignment=BoxContainer.ALIGNMENT_CENTER;slots.add_theme_constant_override("separation",6);add_child(slots)
 var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",18);add_child(body)
 var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
 grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);scroll.add_child(grid)
 var right:=VBoxContainer.new();right.custom_minimum_size.x=300;right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(right)
 var detail_scroll:=ScrollContainer.new();detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_child(detail_scroll)
 var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.add_child(content)
 preview=FrontierEquipmentPreview.new();preview.custom_minimum_size.y=105;content.add_child(preview)
 detail=VBoxContainer.new();content.add_child(detail)
 var buttons:=HBoxContainer.new();right.add_child(buttons)
 equip=Button.new();equip.text="장착";equip.size_flags_horizontal=Control.SIZE_EXPAND_FILL;buttons.add_child(equip);equip.pressed.connect(func():request("equip"))
 remove=Button.new();remove.text="해제";buttons.add_child(remove);remove.pressed.connect(func():request("unequip"))
 salvage=Button.new();salvage.text="분해";buttons.add_child(salvage);salvage.pressed.connect(func():confirm.dialog_text=FrontierSuitModules.title(member.modules.items[selected])+"\n정제 철 %d개로 분해합니다."%int(member.modules.items[selected].tier);confirm.popup_centered())
 starter=Button.new();starter.text="기초 실드 조립 · 철 6 / 구리 4";add_child(starter);starter.pressed.connect(func():request("starter"))
 status=FrontierInterfaceStyle.label(self,"탐험 화물에서 획득 · I에서 장착 · 외형 변화 없음",13,FrontierInterfaceStyle.MUTED);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 confirm=ConfirmationDialog.new();confirm.exclusive=true;confirm.title="모듈 분해";confirm.ok_button_text="분해";add_child(confirm);confirm.confirmed.connect(func():request("salvage"));confirm.canceled.connect(func():pass)
 app.session.request_started.connect(func(seq,kind,_args):
  if kind=="suit_module":pending=seq)
 app.session.response_received.connect(func(seq,result):
  if seq!=pending:return
  pending=-1;status.text="장비 적용 완료" if result.get("ok",false) else str(result.get("error","실행 실패"));signature=""
  if result.get("ok",false):app.feedback.audio.play("sfx_build_place"))
func request(action: String) -> void:
 if pending>=0:return
 status.text="호스트 결과 확인 중…"
 if not app.session.send_request("suit_module",{"action":action,"id":selected,"revision":int(FrontierSuitModules.state(member).get("revision",0))}):status.text="연결 상태를 확인하세요."
func _process(_delta: float) -> void:
 if not is_visible_in_tree() or app.session.latest.is_empty():return
 member=app.session.latest.crew.members[app.session.latest.self_id]
 var rack:=FrontierSuitModules.state(member)
 var next: String=JSON.stringify([rack,filter.selected,get_viewport_rect().size,pending])
 if next==signature:return
 signature=next;rebuild()
func tile(item: Dictionary,id: String,small: bool=false) -> FrontierItemTile:
 var t:=FrontierItemTile.new();t.custom_minimum_size=Vector2(90,80) if small else Vector2(100,100)
 if not item.is_empty():
  var d: Dictionary=FrontierSuitModules.config().slots[item.slot]
  t.picture=load("res://assets/ui/previews/"+d.model+".png") if ResourceLoader.exists("res://assets/ui/previews/"+d.model+".png") else FrontierResourceIcons.texture(d.model.get_file())
  t.caption=d.name;t.amount="T%d · %s"%[int(item.tier),FrontierSuitModules.config().rarities[item.rarity].name];t.tooltip_text=FrontierSuitModules.title(item)+("\n"+FrontierSuitModules.effect_text(item) if item.get("rarity")=="legendary" else "");t.modulate=Color(FrontierSuitModules.config().rarities[item.rarity].color)
 t.item_id=id;t.selected=id==selected and id!="";t.pressed.connect(func():selected=id;signature="");return t
func rebuild() -> void:
 for container in [slots,grid,detail]:
  for child in container.get_children():container.remove_child(child);child.queue_free()
 var rack:=FrontierSuitModules.state(member);var items: Dictionary=rack.get("items",{})
 if selected!="" and not items.has(selected):selected=""
 var keys: Array=FrontierSuitModules.config().slots.keys()
 for slot in keys:
  var id: String=rack.get("equipped",{}).get(slot,"");var t:=tile(items.get(id,{}),id,true)
  if id=="":t.caption={"storage":"수납","drive":"기동","life":"생존","defense":"실드","work":"작업","sensor":"탐지"}[slot];t.amount="빈 슬롯";t.tooltip_text=FrontierSuitModules.config().slots[slot].name
  slots.add_child(t)
 grid.columns=3 if get_viewport_rect().size.x<1100 else 4
 preview.custom_minimum_size.y=50 if get_viewport_rect().size.y<720 else 105
 var ids:=items.keys();ids.sort_custom(func(a,b):return int(items[a].tier)>int(items[b].tier) if items[a].tier!=items[b].tier else a<b)
 for id in ids:
  if filter.selected>0 and items[id].slot!=keys[filter.selected-1]:continue
  var t:=tile(items[id],id);grid.add_child(t)
  if id in rack.get("equipped",{}).values():t.caption="✓ "+t.caption
 count.text="개인 모듈 케이스 %d / %d · 실드 최대 %.0f"%[items.size(),int(FrontierSuitModules.config().case_capacity),FrontierSuitModules.shield_max(member)]
 starter.visible=not rack.get("starter",false);starter.disabled=pending>=0
 equip.disabled=selected=="" or pending>=0;remove.disabled=true;salvage.disabled=true
 if selected=="":
  preview.hide();FrontierInterfaceStyle.label(detail,"슬롯 아래의 모듈을 선택하세요.",14);return
 var item: Dictionary=items[selected];var d: Dictionary=FrontierSuitModules.config().slots[item.slot]
 preview.show();preview.show_model(d.model)
 var label:=FrontierInterfaceStyle.label(detail,FrontierSuitModules.title(item),17,Color(FrontierSuitModules.config().rarities[item.rarity].color));label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 if item.get("rarity")=="legendary":
  var special:=FrontierInterfaceStyle.label(detail,"◆ "+FrontierSuitModules.effect_text(item),13,Color("f2b45b"));special.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var current: Dictionary=items.get(rack.get("equipped",{}).get(item.slot,""),{})
 var active: bool=rack.get("equipped",{}).get(item.slot,"")==selected
 equip.disabled=active or pending>=0;remove.disabled=not active or pending>=0;salvage.disabled=active or pending>=0
 FrontierInterfaceStyle.label(detail,"기본 · "+FrontierSuitModules.value_text(d.stat,float(d.base[int(item.tier)-1])),13)
 for stat in item.affixes:FrontierInterfaceStyle.label(detail,"옵션 · "+FrontierSuitModules.value_text(stat,item.affixes[stat]),13)
 if not active:
  if current.get("legendary","")!=item.get("legendary","") and current.has("legendary"):
   var lost:=FrontierInterfaceStyle.label(detail,"교체 시 해제 · "+str(FrontierSuitModules.config().legendary[current.legendary].name),12,FrontierInterfaceStyle.WARNING);lost.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  FrontierInterfaceStyle.label(detail,"현재 장착 대비",13,FrontierInterfaceStyle.MUTED)
  var before:=FrontierSuitModules.stats(current);var after:=FrontierSuitModules.stats(item);var all: Array=after.keys()
  for stat in before:
   if stat not in all:all.append(stat)
  for stat in all:
   var delta: float=float(after.get(stat,0))-float(before.get(stat,0))
   if absf(delta)>.0001:FrontierInterfaceStyle.label(detail,FrontierSuitModules.value_text(stat,delta),12,FrontierInterfaceStyle.ACCENT if delta>0 else FrontierInterfaceStyle.WARNING)
 if item.slot=="defense":
  var note:=FrontierInterfaceStyle.label(detail,"피격 후 대기 → 자동 재충전\n교체로 즉시 충전되지 않습니다.",12,FrontierInterfaceStyle.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
