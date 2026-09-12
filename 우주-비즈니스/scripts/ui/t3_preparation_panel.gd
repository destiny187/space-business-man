class_name FrontierT3PreparationPanel
extends VBoxContainer
## Images and the actual recipes explain the next installation before spending funds.
var app: FrontierCrewExpedition
var target: OptionButton
var starting: OptionButton
var content: VBoxContainer
var signature:=""
var site: Dictionary={}
var body: Dictionary={}
var point:=Vector2.ZERO
func configure(owner_app: FrontierCrewExpedition) -> void:
 app=owner_app
 var options:=HBoxContainer.new();add_child(options)
 target=OptionButton.new();target.size_flags_horizontal=Control.SIZE_EXPAND_FILL;options.add_child(target)
 for id in FrontierFacilityBlueprints.definitions():
  var def: Dictionary=FrontierFacilityBlueprints.definitions()[id]
  target.add_item(def.name);target.set_item_metadata(target.item_count-1,id)
 starting=OptionButton.new();options.add_child(starting)
 for label in ["신축부터","Mk.1에서","Mk.2에서"]:starting.add_item(label)
 target.item_selected.connect(func(_i):signature="";refresh())
 starting.item_selected.connect(func(_i):signature="";refresh())
 content=VBoxContainer.new();content.add_theme_constant_override("separation",14);add_child(content)
func update_context(current: Dictionary,planet: Dictionary,focus: Vector2) -> void:
 site=current;body=planet;point=focus;refresh()
func refresh() -> void:
 if body.is_empty():return
 var id:=str(target.get_item_metadata(target.selected));var def: Dictionary=FrontierFacilityBlueprints.definitions()[id]
 starting.disabled=def.building=="source_control"
 var from_tier:=0 if def.building=="source_control" else starting.selected
 var district_id:=FrontierRegionalTerraform.region_id(site,Vector3(point.x,0,point.y)) if not site.is_empty() else "region:0"
 var district: Dictionary=site.get("regions",{}).get(district_id,{})
 var stock: Dictionary=district.get("inventory",site.get("inventory",{}) if not site.has("regions") else {})
 var cost:=FrontierProductionPlan.facility_cost(def.building,from_tier)
 var plan:=FrontierProductionPlan.estimate(cost,stock)
 var snapshot: Dictionary=app.session.latest.duplicate(false);snapshot.manifest=app.session.manifest
 var owned:=FrontierFacilityBlueprints.owned(snapshot,id)
 var sources: Array=app.session.latest.get("supply_sites",[])
 var next:=JSON.stringify([body.id,id,from_tier,plan,district_id,owned,sources])
 if signature==next:return
 signature=next
 for child in content.get_children():content.remove_child(child);child.queue_free()
 var heading:=HBoxContainer.new();content.add_child(heading)
 var tile:=FrontierItemTile.new();tile.disabled=true;tile.picture=load("res://assets/ui/previews/"+("terraform3/source_control" if def.building=="source_control" else str(def.building))+".png");tile.caption=def.name;tile.grade=3;heading.add_child(tile)
 var summary:=VBoxContainer.new();summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(summary)
 label(summary,"공동 설계 보유" if owned else "설계도 %d Cr 또는 기록고 복원"%int(def.price),17)
 label(summary,"현장 재고만 반영 · "+str(district.get("name","선택 위치의 새 보급 현장")),13)
 label(summary,"설비 한 대의 재료 견적입니다. 발전·창고·선행 제작소는 별도로 마련하세요.",13)
 if not str(plan.error).is_empty():label(content,plan.error,15);return
 label(content,"추가로 모을 원료" if not plan.raw.is_empty() else "필요한 원료 확보",17)
 materials(content,plan.raw,true)
 if not plan.used.is_empty():
  label(content,"현장 재고에서 확보",16);materials(content,plan.used,false)
 if not plan.steps.is_empty():label(content,"선행 가공 순서 · 한 묶음의 여분은 다음 공정에 사용",17)
 for step in plan.steps:
  var recipe:=FrontierProductionTier2.product(step.id)
  var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);content.add_child(row);row.add_child(FrontierResourceIcons.view(step.id,40))
  var text:=VBoxContainer.new();text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
  label(text,"%s ×%d  ·  %d묶음  ·  Mk.%d 이상"%[recipe.name,step.amount,step.batches,step.factory_tier],15)
  if not step.role.is_empty():
   var names: PackedStringArray=[]
   for source in sources:
    if source.role==step.role:names.append(str(source.name))
   label(text,FrontierPlanetSupply.role_name(step.role)+" 현지 제작"+(" · 현재 행성" if FrontierPlanetSupply.role(body)==step.role else " → 직접 운송"),14)
   if FrontierPlanetSupply.role(body)==step.role:label(text,"이 행성의 Mk.%d 이상 제작소에서 가공"%int(step.factory_tier),13)
   else:label(text,"보유 거점: "+", ".join(names) if not names.is_empty() else "생산처 마련: 해당 지질의 복원 계약 또는 이용권 %d Cr"%int(FrontierPlanetSupply.config().lease_price),13)
  var ingredients:=FrontierResourceReadout.new();ingredients.value=FrontierCatalog.cost_text(step.cost);text.add_child(ingredients)
func label(parent: Node,value: String,size: int) -> Label:
 var result:=FrontierInterfaceStyle.label(parent,value,size);result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return result
func materials(parent: Node,values: Dictionary,raw: bool) -> void:
 var flow:=HFlowContainer.new();flow.add_theme_constant_override("h_separation",14);flow.add_theme_constant_override("v_separation",12);parent.add_child(flow)
 for id in values:
  var column:=VBoxContainer.new();column.custom_minimum_size.x=120;flow.add_child(column);column.add_child(FrontierResourceIcons.view(id,40))
  label(column,FrontierCatalog.entry("resources",id).name+" ×%d"%int(values[id]),14)
  if raw:
   var profile: Dictionary=body.get("mineral_profile",{})
   var absent:=FrontierGroundProgression.absent_starter(body)
   var local: bool=(id in ["iron","copper","stone","ice"] and id!=absent) or id in profile.get("primary",[]) or id in profile.get("secondary",[])
   var origin:=label(column,("직접 반입 · Lotus 보급" if id==absent else "다른 행성에서 반입") if not local else "현지 분포 후보",12)
   if not local:origin.add_theme_color_override("font_color",FrontierInterfaceStyle.WARNING)
   label(column,"채집기 Mk.%d 이상"%FrontierMineralWorld.tier(id),12)
