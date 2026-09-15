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
var pending: Dictionary={}
var ingredient_key: String=""
var maximum: Button
var batches: SpinBox
func configure(owner_panel: FrontierBusinessPanel) -> void:
	panel=owner_panel;name="생산 / 개조"
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
	title=panel.label(right,"");description=panel.label(right,"");ingredients=HBoxContainer.new();detail.add_child(ingredients)
	targets=panel.option(content);targets.item_selected.connect(func(_i: int):refresh())
	target_cost=FrontierResourceReadout.new();content.add_child(target_cost)
	upgrade=panel.button(detail,"",func():panel.command.emit("business_robot_upgrade" if current.get("robots",{}).has(panel.selected(targets)) else "business_facility_upgrade",{"building_id":panel.selected(targets),"robot_id":panel.selected(targets)}))
	help_label=panel.label(detail,"재료  완성품 → 현장 창고",13)
	var quantity_row:=HBoxContainer.new();detail.add_child(quantity_row)
	batches=SpinBox.new();batches.size_flags_horizontal=Control.SIZE_EXPAND_FILL;batches.min_value=1;batches.max_value=int(FrontierProductionTier2.config().maximum_batch);batches.value=1;batches.prefix="묶음 ";quantity_row.add_child(batches);batches.value_changed.connect(func(_value):refresh())
	maximum=panel.button(quantity_row,"최대",func():batches.value=maxi(1,FrontierProductionTier2.available_batches(current,panel.context_id,FrontierProductionTier2.product(selected_product),panel.planet_body,panel.engineering)))
	panel.button(quantity_row,"창고 ↗",func():panel.work_target.emit({"kind":"warehouse"}))
	progress=ProgressBar.new();progress.custom_minimum_size.y=18;detail.add_child(progress)
	produce=panel.button(detail,"",func():panel.command.emit("business_produce",{"building_id":panel.selected(targets),"product":selected_product,"batches":int(batches.value)}))
func update_site(site: Dictionary) -> void:
	current=site
	if FrontierDiscoveryIndustry.building(panel.context_kind) and FrontierRegionalTerraform.enabled(site):
		var focused: Dictionary=site.get("buildings",{}).get(panel.context_id,{})
		if not focused.is_empty():current=FrontierRegionalTerraform.facade(site,str(focused.get("region_id","region:0")))
	var options: Dictionary={}
	for id in site.get("buildings",{}):
		if id!=panel.context_id:continue
		if site.buildings[id].type in ["factory","metalworks"]:options[id]="제작소"
	for id in site.get("buildings",{}):
		if id!=panel.context_id:continue
		var b: Dictionary=site.buildings[id]
		if b.type not in ["factory","metalworks","source_control"] and not FrontierProductionTier2.config().facility_upgrades.has(b.type):continue
		options[id]=FrontierTerraformTier3.name(b)+"  "+str(b.status)
	for id in site.get("robots",{}):
		if id==panel.context_id:options[id]="M-01  Mk.%d  %s"%[int(site.robots[id].get("tier",1)),id]
	panel.choices(targets,options);refresh()
func refresh() -> void:
	if FrontierFieldManufacturing.station(selected_product)!=panel.context_kind and panel.context_kind in ["factory","metalworks"]:
		for id in product_cards:
			if FrontierFieldManufacturing.station(id)==panel.context_kind:selected_product=id;break
	var manufacturing: bool=panel.context_kind in ["factory","metalworks"]
	product_list.visible=manufacturing;search.get_parent().visible=manufacturing;ingredients.visible=manufacturing;help_label.visible=manufacturing
	var def:=FrontierProductionTier2.product(selected_product)
	var batch_count:=int(batches.value);var recipe_cost:=FrontierProductionTier2.batch_cost(def,batch_count);batches.visible=manufacturing
	if manufacturing:preview.show_model(def.model)
	title.text=def.name+" ×%d"%(int(def.amount)*batch_count);description.text=FrontierInterfaceStyle.player_text(def.use)
	for id in product_cards:product_cards[id].selected=id==selected_product;product_cards[id].queue_redraw()
	var stock: Dictionary=current.get("inventory",{})
	var next_ingredients:=str([recipe_cost,stock])
	if ingredient_key!=next_ingredients:
		ingredient_key=next_ingredients
		for child in ingredients.get_children():ingredients.remove_child(child);child.queue_free()
		for resource in recipe_cost:
			var column:=VBoxContainer.new();ingredients.add_child(column);column.add_child(FrontierResourceIcons.view(resource,28))
			var enough: bool=int(stock.get(resource,0))>=int(recipe_cost[resource])
			FrontierInterfaceStyle.label(column,("✓ " if enough else "− ")+"%d/%d"%[int(stock.get(resource,0)),int(recipe_cost[resource])],12,FrontierInterfaceStyle.ACCENT if enough else FrontierInterfaceStyle.DANGER)
			column.tooltip_text=FrontierCatalog.entry("resources",resource).name+"  현장 창고 / 필요"
	var id:=panel.selected(targets)
	var b: Dictionary=current.get("buildings",{}).get(id,current.get("robots",{}).get(id,{}))
	if not manufacturing:
		var target_def:=FrontierCatalog.entry("buildings",b.get("type",""))
		preview.show_model("miner" if panel.context_kind=="robot" else target_def.get("model",""))
		title.text="M-01 로봇" if panel.context_kind=="robot" else FrontierTerraformTier3.name(b)
		description.text="Mk.%d  %s"%[int(b.get("tier",1)),b.get("status","")]
		if FrontierDiscoveryIndustry.building(str(b.get("type",""))):description.text=str(b.get("status",""))+"\n"+str(target_def.description)
		if current.has("tier3") and not FrontierFreeTerraform.active(current):
			var zone: Dictionary=current.regions.get(str(b.get("region_id","region:0")),{})
			if not zone.is_empty():description.text+="\n"+FrontierTerraformTier3.detail(current,zone)
	var job: Dictionary=b.get("production",{})
	progress.value=0;progress.visible=not job.is_empty()
	if not job.is_empty():progress.value=float(job.progress)/float(FrontierProductionTier2.product(job.product).seconds)*100
	produce.text="%d묶음 생산  %.0f초"%[batch_count,float(def.seconds)*batch_count/FrontierProductionTier2.factor(b)]
	var reason:=production_reason(selected_product,batch_count)
	var possible:=FrontierProductionTier2.available_batches(current,panel.context_id,def,panel.planet_body,panel.engineering)
	maximum.visible=manufacturing;maximum.disabled=possible<=0 or not pending.is_empty();maximum.text="최대 %d"%possible;maximum.tooltip_text="현장 재료와 예약된 완성품의 창고 공간을 포함한 수량"
	batches.editable=pending.is_empty()
	produce.disabled=not pending.is_empty() or b.get("type","") not in ["factory","metalworks"] or not job.is_empty() or not FrontierExpeditionBusiness.affordable(stock,recipe_cost) or not FrontierPlanetSupply.operating(current) or not reason.is_empty()
	help_label.text=reason if not reason.is_empty() else "재료  완성품 → 현장 창고"
	if not job.is_empty():help_label.text=str(b.get("status",""))+"  "+"%d / %d묶음 남음  |  창고가 가득 차면 출고 대기"%[int(job.get("remaining",1)),int(job.get("total",1))]
	if not pending.is_empty():help_label.text="호스트 저장 확인 중…"
	filter_products()
	var is_robot: bool=current.get("robots",{}).has(id)
	var upgrade_def: Dictionary=(FrontierProductionTier2.config().robot_upgrade if int(b.get("tier",1))==1 else {}) if is_robot else FrontierProductionTier2.upgrade_definition(b)
	var next_tier:=int(b.get("tier",1))+1
	target_cost.value="Mk.%d 개조  "%next_tier+FrontierCatalog.cost_text(upgrade_def.get("cost",{}))
	upgrade.text="제작소 Mk.%d 개조"%next_tier if manufacturing else "Mk.%d 개조"%next_tier
	upgrade.tooltip_text=str(upgrade_def.get("effect","채광 18  적재 64  이동 +20%"))
	upgrade.disabled=b.get("submerged",false) or b.is_empty() or upgrade_def.is_empty() or not job.is_empty() or not FrontierExpeditionBusiness.affordable(stock,upgrade_def.get("cost",{})) or not FrontierPlanetSupply.operating(current)
	if not is_robot and next_tier==2:
		var research_error:=FrontierFacilityResearch.gate(panel.ledger,str(b.get("type","")))
		if not research_error.is_empty():upgrade.disabled=true;upgrade.text="공동 설비 연구 필요";upgrade.tooltip_text=research_error
	var blueprint:=FrontierFacilityBlueprints.required(b,next_tier) if not is_robot else ""
	if not blueprint.is_empty() and blueprint not in panel.ledger.get("facility_blueprints",[]):
		upgrade.disabled=true;upgrade.text="Mk.%d 설계도 필요"%next_tier;upgrade.tooltip_text="정거장 전문 설비 설계도 탭에서 구매하거나 기술 기록고를 복원하세요."
	if upgrade_def.is_empty():upgrade.text="현재 최고 단계  Mk.%d"%int(b.get("tier",1));target_cost.value=""
	if FrontierDiscoveryIndustry.building(str(b.get("type",""))):
		upgrade.text="강화 완료" if upgrade_def.is_empty() else "설비 강화"
		target_cost.value="" if upgrade_def.is_empty() else "강화  "+FrontierCatalog.cost_text(upgrade_def.cost)
		help_label.text="전원과 환경 조건을 충족하면 자동 가동합니다."

func production_reason(product_id: String,count: int=1) -> String:
	var b: Dictionary=current.get("buildings",{}).get(panel.context_id,{})
	if b.get("submerged",false):return FrontierFacilityFlooding.STATUS
	if not FrontierPlanetSupply.operating(current):return "가동 중인 거점이 필요합니다."
	var reason:=FrontierProductionTier2.recipe_reason(current,panel.context_id,FrontierProductionTier2.product(product_id),panel.planet_body,count,panel.engineering)
	if not reason.is_empty():return reason
	if not b.get("active",false):return str(b.get("status","제작소 전력 / 가동 상태를 확인하세요."))
	return ""
func filter_products() -> void:
	var count:=0
	var query:=search.text.strip_edges().to_lower()
	for id in product_cards:
		var card: FrontierItemTile=product_cards[id]
		var reason:=production_reason(id)
		card.visible=FrontierFieldManufacturing.station(id)==panel.context_kind and (query.is_empty() or card.caption.to_lower().contains(query)) and (not craftable.button_pressed or reason.is_empty())
		card.tooltip_text=card.caption+("  제작 가능" if reason.is_empty() else "  "+reason)
		if card.visible:count+=1
	empty.visible=count==0
