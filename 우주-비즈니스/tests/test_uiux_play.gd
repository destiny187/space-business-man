extends "res://tests/test_equipment_play.gd"
## Render the real inventory and exercise slot selection/drag through host requests.
func capture(name_value: String) -> void:
	await create_timer(.25).timeout
	if name_value=="inventory-new":
		check(app.inventory_panel.preview.model!=null,"selected item has actual INK 3D preview")
		check(app.inventory_panel.recipes.get_child_count()==7,"seven recipes shown as visual slots")
	if name_value=="pulse-equipped":
		check(app.field_hud.visible and not app.status.get_parent().visible,"context HUD replaces legacy header")
		check(not app.navigation_toggle.get_parent().visible,"legacy toolbar hidden on surface")
	if name_value=="inventory-960":
		check(app.inventory_panel.detail.get_global_rect().end.x<=936,"details fit small inventory")
		check(app.inventory_panel.action.get_global_rect().end.y<532,"primary action visible without scrolling")
	if name_value=="owned-960":
		var panel:=app.inventory_panel
		panel.selected_item="crafted:3";panel.selected_definition="pulse_1"
		panel.hotbuttons[4].pressed.emit()
		await create_timer(.15).timeout
		check(FrontierEquipment.state(app.session.latest.crew.members[app.session.latest.self_id]).slots[4]=="crafted:3","clicking a slot equips selected owned item")
		panel.hotbuttons[1]._drop_data(Vector2.ZERO,{"equipment_item":"crafted:3"})
		await create_timer(.15).timeout
		var state:=FrontierEquipment.state(app.session.latest.crew.members[app.session.latest.self_id])
		check(state.slots[1]=="crafted:3" and state.slots[4]=="","drag assignment moves item without duplication")
		panel._refresh_details();panel._highlight()
	await super.capture(name_value)
