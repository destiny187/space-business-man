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
var search: LineEdit
var craftable: CheckButton
var empty: Label
var product_list: VBoxContainer
func configure(owner_panel: FrontierBusinessPanel) -> void:
	panel=owner_panel;name="생산·개조"
	var browse:=HBoxContainer.new();add_child(browse)
	search=LineEdit.new();search.placeholder_text="부품 이름 검색";search.clear_button_enabled=true;search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;browse.add_child(search)
	craftable=CheckButton.new();craftable.text="제작 가능만";browse.add_child(craftable)
	search.text_changed.connect(func(_s):filter_products());craftable.toggled.connect(func(_v):filter_products())
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(body)
	var list:=VBoxContainer.new();list.custom_minimum_size.x=230;body.add_child(list);product_list=list
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;list.add_child(scroll)
	var grid:=GridContainer.new();grid.columns=2;scroll.add_child(grid);product_grid=grid
	empty=panel.label(list,"조건에 맞는 부품이 없습니다.",13)
	for id in FrontierProductionTier2.config().products:
		var card:=FrontierItemTile.new();card.picture=FrontierResourceIcons.texture(id);card.grade=int(FrontierProductionTier2.product(id).tier);card.caption=FrontierProductionTier2.product(id).name
		card.pressed.connect(func():selected_product=id;refresh());grid.add_child(card);product_cards[id]=card
	var detail:=VBoxContainer.new();detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(detail)
	var detail_scroll:=ScrollContainer.new();detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail.add_child(detail_scroll)
	var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.add_child(content)
	var row:=HBoxContainer.new();content.add_child(row);product_row=row
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(120,120);row.add_child(preview)
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(right)
	title=panel.label(right,"");description=panel.label(right,"");ingredients=HBoxContainer.new();content.add_child(ingredients)
	targets=panel.option(content);targets.item_selected.connect(func(_i: int):refresh())
	target_cost=FrontierResourceReadout.new();content.add_child(target_cost)
	upgrade=panel.button(content,"",func():panel.command.emit("business_robot_upgrade" if current.get("robots",{}).has(panel.selected(targets)) else "business_facility_upgrade",{"building_id":panel.selected(targets),"robot_id":panel.selected(targets)}))
	help_label=panel.label(detail,"재료 · 완성품 → 현장 창고",13)
	progress=ProgressBar.new();progress.custom_minimum_size.y=18;detail.add_child(progress)
	produce=panel.button(detail,"",func():panel.command.emit("business_produce",{"building_id":panel.selected(targets),"product":selected_product}))
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
	product_list.visible=manufacturing;search.get_parent().visible=manufacturing;ingredients.visible=manufacturing;help_label.visible=manufacturing
	var def:=FrontierProductionTier2.product(selected_product)
	if manufacturing:preview.show_model(def.model)
	title.text=def.name+" ×%d"%int(def.amount);description.text=def.use
	for id in product_cards:product_cards[id].selected=id==selected_product;product_cards[id].queue_redraw()
	for child in ingredients.get_children():ingredients.remove_child(child);child.queue_free()
	var stock: Dictionary=current.get("inventory",{})
	for id in def.cost:
		var column:=VBoxContainer.new();ingredients.add_child(column);column.add_child(FrontierResourceIcons.view(id,28))
		FrontierInterfaceStyle.label(column,("부족 · %d 필요"%int(def.cost[id])) if int(stock.get(id,0))<=0 else "%d/%d"%[int(stock.get(id,0)),int(def.cost[id])],12,FrontierInterfaceStyle.ACCENT if int(stock.get(id,0))>=int(def.cost[id]) else FrontierInterfaceStyle.WARNING)
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
	var reason:=production_reason(selected_product)
	produce.disabled=b.get("type","")!="factory" or not job.is_empty() or not FrontierExpeditionBusiness.affordable(stock,def.cost) or not FrontierPlanetSupply.operating(current) or not reason.is_empty()
	help_label.text=reason if not reason.is_empty() else "재료 · 완성품 → 현장 창고"
	filter_products()
	var is_robot: bool=current.get("robots",{}).has(id)
	var upgrade_def: Dictionary=(FrontierProductionTier2.config().robot_upgrade if int(b.get("tier",1))==1 else {}) if is_robot else FrontierProductionTier2.upgrade_definition(b)
	var next_tier:=int(b.get("tier",1))+1
	target_cost.value="Mk.%d 개조 · "%next_tier+FrontierCatalog.cost_text(upgrade_def.get("cost",{}))
	upgrade.text="제작소 Mk.%d 개조"%next_tier if manufacturing else "Mk.%d 개조"%next_tier
	upgrade.tooltip_text=str(upgrade_def.get("effect","채광 18 · 적재 64 · 이동 +20%"))
	upgrade.disabled=b.is_empty() or upgrade_def.is_empty() or not job.is_empty() or not FrontierExpeditionBusiness.affordable(stock,upgrade_def.get("cost",{})) or not FrontierPlanetSupply.operating(current)
	if upgrade_def.is_empty():upgrade.text="현재 최고 단계 · Mk.%d"%int(b.get("tier",1));target_cost.value=""

func production_reason(product_id: String) -> String:
	var b: Dictionary=current.get("buildings",{}).get(panel.context_id,{})
	var recipe:=FrontierProductionTier2.product(product_id)
	if b.get("type","")!="factory":return "제작소가 필요합니다."
	if not FrontierPlanetSupply.operating(current):return "가동 중인 거점이 필요합니다."
	if not b.get("production",{}).is_empty():return "생산 중 · "+FrontierProductionTier2.product(b.production.product).name
	for job in current.get("jobs",{}).values():
		if job.factory_id==panel.context_id:return "로봇 조립 중"
	for project in panel.engineering.get("projects",{}).values():
		if project.get("facility_id","")==panel.context_id and project.get("stage","") in ["prototype","trial"]:return "공학 작업 진행 중"
	if not panel.planet_body.is_empty():
		var gate:=FrontierPlanetSupply.production_reason(panel.planet_body,b,recipe)
		if not gate.is_empty():return gate
	if not b.get("active",false):return "제작소 전력·가동 상태를 확인하세요."
	if not FrontierExpeditionBusiness.affordable(current.get("inventory",{}),recipe.cost):return "현장 창고의 제작 재료가 부족합니다."
	return ""
func filter_products() -> void:
	var count:=0
	var query:=search.text.strip_edges().to_lower()
	for id in product_cards:
		var card: FrontierItemTile=product_cards[id]
		var reason:=production_reason(id)
		card.visible=(query.is_empty() or card.caption.to_lower().contains(query)) and (not craftable.button_pressed or reason.is_empty())
		card.tooltip_text=card.caption+(" · 제작 가능" if reason.is_empty() else " · "+reason)
		if card.visible:count+=1
	empty.visible=count==0
