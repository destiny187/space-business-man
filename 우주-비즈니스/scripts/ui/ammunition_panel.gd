extends HBoxContainer
## Five retained recipe cards; closed panels do no inventory or preview work.
var app: FrontierCrewExpedition
var selected:="ammo_light"
var cards: Dictionary={}
var preview: FrontierEquipmentPreview
var heading: Label
var count: Label
var cost: FrontierResourceReadout
var batches: SpinBox
var action: Button
var status: Label
var pending:=-1
var signature: Array=[]
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;name="탄약";add_theme_constant_override("separation",20)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=240;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var grid:=GridContainer.new();grid.columns=2;scroll.add_child(grid)
	for id in FrontierFirearms.config().ammunition:
		var recipe: Dictionary=FrontierFirearms.config().ammunition[id]
		var tile:=FrontierItemTile.new();tile.picture=FrontierResourceIcons.texture(id);tile.caption=recipe.name;tile.amount="×%d"%int(recipe.amount);tile.tooltip_text=recipe.use;grid.add_child(tile);cards[id]=tile
		tile.pressed.connect(func():selected=id;signature=[];refresh())
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(right)
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size.y=185;preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_child(preview)
	heading=FrontierInterfaceStyle.label(right,"",21)
	count=FrontierInterfaceStyle.label(right,"",14);count.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cost=FrontierResourceReadout.new();right.add_child(cost)
	var row:=HBoxContainer.new();right.add_child(row)
	batches=SpinBox.new();batches.min_value=1;batches.max_value=10;batches.value=1;batches.prefix="묶음 ";row.add_child(batches);batches.value_changed.connect(func(_n):signature=[];refresh())
	action=Button.new();action.size_flags_horizontal=Control.SIZE_EXPAND_FILL;action.custom_minimum_size.y=42;row.add_child(action)
	action.pressed.connect(func():
		if pending<0:app.session.send_request("equipment_ammo_craft",{"ammunition":selected,"batches":int(batches.value)}))
	status=FrontierInterfaceStyle.label(right,"",12);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	FrontierInterfaceStyle.label(right,"권총은 약한 대신 예비탄 무한 · 탄창 재장전 필요",12,FrontierInterfaceStyle.MUTED)
	app.session.request_started.connect(func(seq,kind,_args):
		if kind=="equipment_ammo_craft":pending=seq;signature=[])
	app.session.response_received.connect(func(seq,result):
		if seq!=pending:return
		pending=-1;signature=[];status.text="탄약 제작 완료" if result.get("ok",false) else str(result.get("error","제작할 수 없습니다.")))
func _process(_delta: float) -> void:
	if is_visible_in_tree():refresh()
func refresh() -> void:
	if app.session.latest.is_empty():return
	var stock: Dictionary=app.session.latest.get("inventory",{})
	var recipe: Dictionary=FrontierFirearms.config().ammunition[selected]
	var materials:=FrontierProductionTier2.batch_cost(recipe,int(batches.value))
	var next: Array=[selected,int(batches.value),pending,int(stock.get(selected,0))]
	for id in materials:next.append(int(stock.get(id,0)))
	if next==signature:return
	signature=next
	for id in cards:cards[id].selected=id==selected;cards[id].queue_redraw()
	preview.show_model(recipe.model);heading.text=recipe.name
	count.text="%s\n보유 %d발 · 한 칸 %d발"%[recipe.use,int(stock.get(selected,0)),int(recipe.stack)]
	cost.show_cost(materials,stock,true)
	action.text="제작 중…" if pending>=0 else "%d발 제작"%(int(recipe.amount)*int(batches.value))
	action.disabled=pending>=0 or not FrontierExpeditionBusiness.affordable(stock,materials)
