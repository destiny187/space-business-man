extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var m:=FrontierUniverse.generate(61739);var index:=702
	var journal:=FrontierNavigationJournal.new();journal.manifest=m;journal.data.systems[str(index)]=true
	var layer:=CanvasLayer.new();layer.layer=50;root.add_child(layer)
	var chart: Control=load("res://scripts/ui/galaxy_chart.gd").new();layer.add_child(chart);chart.position=Vector2.ZERO;chart.size=Vector2(root.size)
	chart.manifest=m;chart.system_index=index;chart.current_system=index;chart.journal=journal
	var sites: Array=FrontierCorporateSites.profile(m,index).sites
	var folder:=ProjectSettings.globalize_path("res://../docs/production/media/corporate-space/")
	for i in 2:
		journal.mark(int(sites[i].body),"scanned");chart.queue_redraw()
		await create_timer(.25).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+("region-map-partial.png" if i==0 else "region-map-route.png"))
	print("CORPORATE_MAP_RENDER_OK ",chart.size);quit()
