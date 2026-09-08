class_name FrontierProgressionResearchPanel
extends VBoxContainer
var app: FrontierCrewExpedition
var selected:="mining"
var cards: Dictionary={}
var preview: FrontierEquipmentPreview
var title: Label
var effect: Label
var scope: Label
var progress: ProgressBar
var cost: FrontierResourceReadout
var action: Button
var signature:=""
var pending_sequence:=-1
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;name="성능 개조";add_theme_constant_override("separation",10)
	var choices:=HBoxContainer.new();add_child(choices)
	for key in FrontierProgressionResearch.config().fields:
		var def: Dictionary=FrontierProgressionResearch.config().fields[key]
		var tile:=FrontierItemTile.new();tile.custom_minimum_size=Vector2(150,120);tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.caption=def.name;tile.picture=load("res://assets/ui/research/"+def.picture+".png");choices.add_child(tile);cards[key]=tile
		tile.pressed.connect(func():selected=key;signature="";refresh())
	var row:=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(row)
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(250,170);row.add_child(preview)
	var scroll:=ScrollContainer.new();scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;row.add_child(scroll)
	var detail:=VBoxContainer.new();detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(detail)
	title=FrontierInterfaceStyle.label(detail,"",22)
	scope=FrontierInterfaceStyle.label(detail,"",13,FrontierInterfaceStyle.ACCENT)
	progress=ProgressBar.new();progress.max_value=5;progress.show_percentage=false;progress.custom_minimum_size=Vector2(250,12);detail.add_child(progress)
	effect=FrontierInterfaceStyle.label(detail,"",14);effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cost=FrontierResourceReadout.new();cost.custom_minimum_size.x=250;detail.add_child(cost)
	action=Button.new();action.custom_minimum_size.y=42;add_child(action)
	action.pressed.connect(func():app.session.send_request("business_efficiency",{"field":selected}))
	app.session.request_started.connect(func(seq: int,kind: String,_args: Dictionary):
		if kind=="business_efficiency":pending_sequence=seq)
	app.session.response_received.connect(func(seq: int,result: Dictionary):
		signature=""
		if seq==pending_sequence and result.get("ok",false) and app.feedback!=null:
			app.feedback.audio.play("ui_discovery");app.feedback.show_cue("성능 개조 완료"))
func _process(_delta: float) -> void:
	if is_visible_in_tree():refresh()
func refresh() -> void:
	if app.session.latest.is_empty():return
	var actor: String=app.session.latest.self_id
	var world: Dictionary={"crew":app.session.latest.crew,"business":app.session.surface.get("business",{})}
	var level:=FrontierProgressionResearch.level(world,actor,selected)
	var reason:=FrontierProgressionResearch.reason(world,actor,selected)
	var key:=str([selected,level,reason,world.business.get("credits",0),FrontierExpeditionBusiness.bag(world,actor)])
	if key==signature:return
	signature=key
	var def: Dictionary=FrontierProgressionResearch.config().fields[selected]
	for id in cards:cards[id].selected=id==selected;cards[id].amount="%d / 5"%FrontierProgressionResearch.level(world,actor,id);cards[id].queue_redraw()
	preview.show_model(def.model);title.text="%s %d / 5"%[def.name,level];progress.value=level
	scope.text="공동 세계 · 호스트 구매" if selected=="industry" else "내 캐릭터 · 이 세계에 보존"
	effect.text=def.effect+"\n현재 +%d%% → 다음 +%d%%"%[level*10,mini(5,level+1)*10]
	if selected=="logistics":effect.text+="\n현재 가방 %d칸"%FrontierItemInventory.capacity(world.crew.members[actor])
	cost.value="최고 단계" if level>=5 else ("공동 자금 %d Cr"%[int(def.price)*(level+1)] if selected=="industry" else "가방 · "+FrontierCatalog.cost_text(FrontierProgressionResearch.cost(selected,level)))
	action.disabled=not reason.is_empty();action.text=reason if action.disabled else "다음 단계 개조"
