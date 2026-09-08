class_name FrontierPlanetSupplyPanel
extends VBoxContainer
## Native item cards keep the supply chain and its actual warehouse stocks visible.
var panel: FrontierBusinessPanel
var heading: Label
var lease: Button
var release: Button
var register: Button
var cards: GridContainer
var last_key: String=""
func configure(owner_panel: FrontierBusinessPanel) -> void:
	panel=owner_panel
	heading=panel.label(self,"")
	var chain:=HBoxContainer.new();chain.alignment=BoxContainer.ALIGNMENT_CENTER;add_child(chain)
	for id in ["alloy_frame","cryo_cell","industrial_core"]:
		var tile:=FrontierItemTile.new();tile.picture=FrontierResourceIcons.texture(id);tile.caption=FrontierProductionTier2.product(id).name;tile.grade=3
		tile.tooltip_text=FrontierProductionTier2.product(id).use;chain.add_child(tile)
		if id!="industrial_core":panel.label(chain,"+" if id=="alloy_frame" else "→",22)
	lease=panel.button(self,"생산 이용권 · %d Cr"%int(FrontierPlanetSupply.config().lease_price),func():panel.command.emit("business_lease",{}))
	register=panel.button(self,"이 거점에서 복원 계약 시작",func():panel.command.emit("business_register",{}))
	release=panel.button(self,"비운 거점 이용권 반납 · 환급 없음",func():panel.command.emit("business_lease_release",{}))
	cards=GridContainer.new();cards.columns=2;add_child(cards)
	panel.label(self,"현지 제작 → 창고에서 인수 → 우주선에 적재 → 다음 거점에 하역\n세션 중 다른 행성·항해에서도 생산합니다. 원료·전력·창고 조건에 따라 대기합니다. 항성 지도 › 생산 거점에서 재방문하세요.",13)
func update(ledger: Dictionary,body: Dictionary,actor: String,owner: bool) -> void:
	var site: Dictionary=ledger.get("sites",{}).get(body.get("id",""),{})
	var allowed:=FrontierUniverse.landable(body) if not body.is_empty() else false
	var leased: bool=site.get("production_lease",false)
	var role:=FrontierPlanetSupply.role(body) if allowed else ""
	heading.text="%s · 생산 거점 %d/%d"%[FrontierPlanetSupply.role_name(role),ledger.get("supply_sites",[]).size(),int(FrontierPlanetSupply.config().maximum_leases)]
	lease.visible=allowed and not leased and site.get("state","")!="settled"
	lease.disabled=not owner or int(ledger.get("credits",0))<int(FrontierPlanetSupply.config().lease_price) or ledger.get("supply_sites",[]).size()>=int(FrontierPlanetSupply.config().maximum_leases)
	release.visible=leased and site.get("state")!="active";release.disabled=not owner
	register.visible=allowed and site.get("state","") in ["exploration","supply"] and site.get("settlement",{}).is_empty()
	register.disabled=not owner or not str(ledger.get("active","")).is_empty() or not str(ledger.get("active_elsewhere","")).is_empty()
	var key:=str(ledger.get("supply_sites",[]))
	if last_key==key:return
	last_key=key
	for child in cards.get_children():cards.remove_child(child);child.queue_free()
	for row in ledger.get("supply_sites",[]):
		var frame:=PanelContainer.new();frame.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box());frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cards.add_child(frame)
		var column:=VBoxContainer.new();column.custom_minimum_size.x=210;frame.add_child(column)
		panel.label(column,str(row.name),16)
		panel.label(column,FrontierPlanetSupply.role_name(row.role)+(" · Ⅱ 운영 정지" if row.paused else (" · ▶ 원격 운영" if row.get("remote",false) else " · ▶ 현장 운영")),12)
		var stock:=HBoxContainer.new();column.add_child(stock)
		var shown:=0
		for id in row.inventory:
			if int(row.inventory[id])<=0:continue
			if shown==3:break
			var item:=VBoxContainer.new();stock.add_child(item);item.add_child(FrontierResourceIcons.view(id,28));panel.label(item,str(int(row.inventory[id])),12);item.tooltip_text=FrontierCatalog.entry("resources",id).name;shown+=1
		var count:=0
		for id in row.inventory:
			if int(row.inventory[id])>0:count+=1
		var more:=panel.button(column,"창고 전체 · %d종"%count,func():
			var dialog:=FrontierResourceListDialog.new();add_child(dialog);dialog.configure(str(row.name)+" · 현장 창고",row.inventory);dialog.popup_centered(Vector2i(510,400)))
		more.tooltip_text="전 품목 검색 · 보유 재고만 표시"
		for job in row.get("production",[]):
			var product:=FrontierProductionTier2.product(job.product)
			var line:=HBoxContainer.new();column.add_child(line);line.add_child(FrontierResourceIcons.view(job.product,24))
			panel.label(line,product.name+" · "+("생산 중" if job.active else str(job.status)),12)
			var progress:=ProgressBar.new();progress.custom_minimum_size.y=14;progress.value=clampf(float(job.progress)/float(product.seconds)*100,0,100);column.add_child(progress)
		if row.get("production",[]).is_empty():panel.label(column,"생산 대기",12)
		frame.tooltip_text="현장 창고 · "+FrontierCatalog.stock_text(row.inventory)
		if shown==0:panel.label(column,"창고 비어 있음",12)
