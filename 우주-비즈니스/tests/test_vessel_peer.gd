extends "res://tests/test_business_peer.gd"
func handle_command(command: Dictionary) -> void:
	match command.kind:
		"shipyard":app.toggle_shipyard()
		"ship_action":
			var panel: FrontierShipyardPanel=app.shipyard_panel
			if not panel.visible:app.toggle_shipyard()
			for i in panel.kind.item_count:
				if panel.kind.get_item_metadata(i)==command.get("module_type",""):panel.kind.select(i)
			for i in panel.owned.item_count:
				if panel.owned.get_item_metadata(i)==command.get("module_id",""):panel.owned.select(i)
			panel.actions[int(command.button)].pressed.emit()
		"ship_surface_frame":
			app.shipyard_panel.hide();app.test_camera_position=Vector3(8,16,42)
			var direction: Vector3=(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(0,1,0)-app.test_camera_position).normalized();app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
		"resize":root.size=Vector2i(command.width,command.height)
		_:super.handle_command(command)
func status_value() -> Dictionary:
	var value:=super.status_value()
	value["shipyard"]=app.shipyard_panel.visible
	value["shipyard_summary"]=app.shipyard_panel.summary.text
	value["flight_modules"]=app.flight.refits.installed.keys() if app.flight!=null else []
	value["surface_modules"]=app.surface_world.refits.installed.keys() if app.surface_world!=null else []
	return value
