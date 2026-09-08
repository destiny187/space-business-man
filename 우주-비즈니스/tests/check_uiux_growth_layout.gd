extends SceneTree
func _initialize() -> void:call_deferred("run")
func capture(path: String) -> void:
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	var world:=FrontierWorldStore.new("/tmp/uiux-ux03/world.json").read_state()
	if world.is_empty():quit(1);return
	var data: Dictionary={"self_id":world.crew.owner_id,"crew":world.crew.duplicate(true),"location":world.location,"vessel_seed":world.manifest.seed,"vessel":world.get("vessel",{})}
	var yard:=FrontierShipyardPanel.new();root.add_child(yard);yard.show();yard.update_snapshot(data,world.business);yard.tabs.current_tab=1
	var dock:=Button.new();dock.text="차량 적재함";yard.heading.get_parent().add_child(dock)
	await capture("/tmp/uiux-ux03/shipyard-final-960.png")
	var ok: bool=yard.preview.size.y>=240 and yard.action_map.vessel_draw.get_global_rect().end.y<yard.get_global_rect().end.y
	print("LAYOUT ship preview/actions ",ok)
	yard.hide()
	var market:=FrontierStationMarketPanel.new();root.add_child(market)
	data.crew.landing={};data.crew.navigation.mode="idle";data.crew.navigation.speed=0;data.crew.navigation.position=[0,0,0]
	data.station={"name":"WAYFARER","position":[0,0,0],"credits":1000,"stock":{"iron":10,"copper":0,"stone":0},"prices":{"iron":12,"copper":20,"stone":5}};data.inventory={"copper":3}
	market.data=data;market.mode="goods";market.selected="iron";market.rebuild();market.show()
	await capture("/tmp/uiux-ux03/market-final-960.png")
	var fits: bool=market.icon.get_global_rect().end.y<market.quantity.get_global_rect().position.y
	print("LAYOUT commodity image/actions ",fits);print("LAYOUT audio open/ambience ",market.hum.playing)
	quit(0 if ok and fits else 1)
