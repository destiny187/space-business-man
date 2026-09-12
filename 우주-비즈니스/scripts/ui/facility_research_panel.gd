class_name FrontierFacilityResearchPanel
extends HBoxContainer
var app: FrontierCrewExpedition
var selected:="factory"
var cards: Dictionary={}
var preview: FrontierEquipmentPreview
var title: Label
var explanation: Label
var credits: Label
var materials: FrontierResourceReadout
var action: Button
var signature:=""
func configure(owner_app: FrontierCrewExpedition) -> void:
 app=owner_app;name="설비 연구";add_theme_constant_override("separation",20)
 var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(scroll)
 var grid:=GridContainer.new();grid.columns=2;scroll.add_child(grid)
 for key in FrontierFacilityResearch.config().projects:
  var def: Dictionary=FrontierFacilityResearch.config().projects[key]
  var card:=FrontierItemTile.new();card.custom_minimum_size=Vector2(120,108);card.caption=def.name;card.picture=load("res://assets/ui/previews/"+def.model+".png");grid.add_child(card);cards[key]=card
  card.pressed.connect(func():selected=key;signature="";refresh())
 var column:=VBoxContainer.new();column.custom_minimum_size.x=260;column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(column)
 preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(220,130);column.add_child(preview)
 title=FrontierInterfaceStyle.label(column,"",20)
 explanation=FrontierInterfaceStyle.label(column,"",14);explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 credits=FrontierInterfaceStyle.label(column,"",16)
 materials=FrontierResourceReadout.new();materials.custom_minimum_size.x=0;column.add_child(materials)
 action=Button.new();action.custom_minimum_size.y=42;column.add_child(action)
 action.pressed.connect(func():app.session.send_request("business_facility_research",{"research":selected,"station_id":"ship:research"}))
func _process(_delta: float) -> void:
 if is_visible_in_tree():refresh()
func refresh() -> void:
 if app.session.latest.is_empty():return
 var actor: String=app.session.latest.self_id
 var ledger: Dictionary=app.session.surface.get("business",{})
 var world: Dictionary={"crew":app.session.latest.crew,"business":ledger}
 var reason:=app.stations.work_reason("research")
 if reason.is_empty():reason=FrontierFacilityResearch.reason(world,actor,selected)
 var bag:=FrontierExpeditionBusiness.bag(world,actor)
 var key:=str([selected,ledger.get("facility_research",[]),ledger.get("credits",0),bag,reason])
 if signature==key:return
 signature=key
 var def: Dictionary=FrontierFacilityResearch.config().projects[selected]
 for id in cards:cards[id].selected=id==selected;cards[id].amount="✓" if FrontierFacilityResearch.owned(ledger,id) else "";cards[id].queue_redraw()
 preview.show_model(def.model);title.text=def.name;explanation.text=def.effect
 credits.text="공동 자금 %d / %d Cr"%[int(ledger.get("credits",0)),int(def.price)]
 credits.modulate=FrontierInterfaceStyle.DANGER if int(ledger.get("credits",0))<int(def.price) else Color.WHITE
 materials.show_cost(def.cost,bag,true)
 action.disabled=not reason.is_empty();action.text=reason if action.disabled else "연구 구매"
