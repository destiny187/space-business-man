extends SceneTree
func _initialize() -> void:
 var world:=FrontierUniverse.new_world(71491)
 FrontierStellarRoutes.build(world.manifest,0,100000000)
 var rows:=FrontierStellarRoutes.nearby(world.manifest,0,FrontierVesselRefit.stellar_range(world))
 for row in rows:
  for orbit in FrontierUniverse.body_count(world.manifest,row.index):
   var ordinal:=FrontierUniverse.first_ordinal(world.manifest,row.index)+orbit
   var body:=FrontierUniverse.body(world.manifest,ordinal)
   if FrontierUniverse.landable(body) and int(body.planet_tier)<=2:
    print("OVERVIEW_ROUTE ",ordinal," ",row);quit();return
 print("NO_ROUTE ",rows," range ",FrontierVesselRefit.stellar_range(world));quit(1)
