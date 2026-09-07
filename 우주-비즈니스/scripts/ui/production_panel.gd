class_name FrontierProductionPanel
extends VBoxContainer
## One shared live preview, product cards and an explicit warehouse-to-backpack path.
var panel: FrontierBusinessPanel
var selected_product: String="refined_iron"
var selected_target: String=""
var product_cards: Dictionary={}
var targets: OptionButton
var preview: FrontierEquipmentPreview
var ingredients: HBoxContainer
var title: Label
var description: Label
var progress: ProgressBar
var produce: Button
var upgrade: Button
var target_cost: FrontierResourceReadout
var current: Dictionary={}
var product_grid: GridContainer
var product_row: HBoxContainer
var help_label: Label
func configure(owner_panel: FrontierBusinessPanel) -> void:
	panel=owner_panel;name="생산·개조"
	var row:=HBoxContainer.new();add_child(row);product_row=row
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(185,185);row.add_child(preview)
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(right)
	title=panel.label(right,"");description=panel.label(right,"");ingredients=HBoxContainer.new();right.add_child(ingredients)
	var grid:=GridContainer.new();grid.columns=7;add_child(grid);move_child(grid,0);product_grid=grid
	for id in FrontierProductionTier2.config().products:
		var card:=FrontierItemTile.new();card.picture=FrontierResourceIcons.texture(id);card.grade=2;card.caption=FrontierProductionTier2.product(id).name;card.tooltip_text=card.caption
		card.pressed.connect(func():selected_product=id;refresh());grid.add_child(card);product_cards[id]=card
	targets=panel.option(self);targets.item_selected.connect(func(_i: int):refresh())
	progress=ProgressBar.new();progress.custom_minimum_size.y=18;add_child(progress)
	produce=panel.button(self,"",func():panel.command.emit("business_produce",{"building_id":panel.selected(targets),"product":selected_product}))
	target_cost=FrontierResourceReadout.new();add_child(target_cost)
	upgrade=panel.button(self,"",func():panel.command.emit("business_robot_upgrade" if current.get("robots",{}).has(panel.selected(targets)) else "business_facility_upgrade",{"building_id":panel.selected(targets),"robot_id":panel.selected(targets)}))
	help_label=panel.label(self,"원광 → 정제재 → Mk.2 부품 · 생산품은 공동 창고로 이동합니다.")
func update_site(site: Dictionary) -> void:
	current=site
	var options: Dictionary={}
	for id in site.get("buildings",{}):
		if id!=panel.context_id:continue
		if site.buildings[id].type=="factory":options[id]="제작소"
	for id in site.get("buildings",{}):
		if id!=panel.context_id:continue
		var b: Dictionary=site.buildings[id]
		if b.type!="factory" and not FrontierProductionTier2.config().facility_upgrades.has(b.type):continue
		options[id]=FrontierCatalog.entry("buildings",b.type).name+" · Mk.%d · %s"%[int(b.get("tier",1)),b.status]
	for id in site.get("robots",{}):
		if id==panel.context_id:options[id]="M-01 · Mk.%d · %s"%[int(site.robots[id].get("tier",1)),id]
	panel.choices(targets,options);refresh()
func refresh() -> void:
	var manufacturing: bool=panel.context_kind=="factory"
	product_grid.visible=manufacturing;ingredients.visible=manufacturing;help_label.visible=manufacturing
	var def:=FrontierProductionTier2.product(selected_product)
	if manufacturing:preview.show_model(def.model)
	title.text=def.name+" ×%d"%int(def.amount);description.text=def.use
	for id in product_cards:product_cards[id].selected=id==selected_product;product_cards[id].queue_redraw()
	for child in ingredients.get_children():ingredients.remove_child(child);child.queue_free()
	var stock: Dictionary=current.get("inventory",{})
	for id in def.cost:
		var column:=VBoxContainer.new();ingredients.add_child(column);column.add_child(FrontierResourceIcons.view(id,28))
		FrontierInterfaceStyle.label(column,"%d/%d"%[int(stock.get(id,0)),int(def.cost[id])],12,FrontierInterfaceStyle.ACCENT if int(stock.get(id,0))>=int(def.cost[id]) else FrontierInterfaceStyle.WARNING)
	var id:=panel.selected(targets)
	var b: Dictionary=current.get("buildings",{}).get(id,current.get("robots",{}).get(id,{}))
	if not manufacturing:
		var target_def:=FrontierCatalog.entry("buildings",b.get("type",""))
		preview.show_model("miner" if panel.context_kind=="robot" else target_def.get("model",""))
		title.text="M-01 로봇" if panel.context_kind=="robot" else target_def.get("name","시설")
		description.text="Mk.%d · %s"%[int(b.get("tier",1)),b.get("status","")]
	var job: Dictionary=b.get("production",{})
	progress.value=0;progress.visible=not job.is_empty()
	if not job.is_empty():progress.value=float(job.progress)/float(FrontierProductionTier2.product(job.product).seconds)*100
	produce.text="제품 생산 · %.0f초 · 제작소 8m 이내"%(float(def.seconds)/FrontierProductionTier2.factor(b))
	produce.disabled=b.get("type","")!="factory" or not job.is_empty() or not FrontierExpeditionBusiness.affordable(stock,def.cost) or current.get("state","")!="active"
	var upgrade_def: Dictionary=FrontierProductionTier2.config().robot_upgrade if current.get("robots",{}).has(id) else FrontierProductionTier2.config().facility_upgrades.get(b.get("type",""),{})
	target_cost.value="Mk.2 개조 · "+FrontierCatalog.cost_text(upgrade_def.get("cost",{}))
	upgrade.text="Mk.2 개조 · "+str(upgrade_def.get("effect","채광 18 · 적재 64 · 이동 +20%"))
	upgrade.disabled=b.is_empty() or int(b.get("tier",1))>=2 or upgrade_def.is_empty() or not job.is_empty() or not FrontierExpeditionBusiness.affordable(stock,upgrade_def.get("cost",{})) or current.get("state","")!="active"
	if int(b.get("tier",1))>=2:upgrade.text="Mk.2 개조 완료"
