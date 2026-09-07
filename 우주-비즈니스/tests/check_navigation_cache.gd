extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures+=1;printerr("FAIL "+label)
func fill_page(manifest: Dictionary) -> void:
 while FrontierStellarRoutes.finished.is_empty():
  FrontierStellarRoutes.build(manifest,110000);await process_frame
func run() -> void:
 if not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 var manifest:=FrontierUniverse.generate(12940123)
 FrontierStellarRoutes.reset();await fill_page(manifest)
 var page: int=FrontierStellarRoutes.finished.keys()[0]
 var index:=page*FrontierStellarRoutes.PAGE_SIZE
 var coordinate:=FrontierStellarRoutes.points[index]
 check(index>=100000,"current radial band prioritized")
 check(coordinate==FrontierUniverse.map_position(manifest,index),"coordinates unchanged")
 var cold:=FrontierStellarRoutes.generated
 var path:=FrontierStellarRoutes.cache_root+"/%d.bin"%page
 check(FileAccess.file_exists(path),"completed page persisted")
 FrontierStellarRoutes.reset();await fill_page(manifest)
 check(FrontierStellarRoutes.restored>=1024 and FrontierStellarRoutes.generated==0,"warm page skips coordinate generation")
 check(FrontierStellarRoutes.points[index]==coordinate,"disk roundtrip exact")
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var({"version":1,"checksum":"invalid","points":PackedVector2Array([Vector2.ZERO])});file.close()
 FrontierStellarRoutes.reset();await fill_page(manifest)
 check(FrontierStellarRoutes.generated>=1024,"invalid cache regenerated")
 var changed:=manifest.duplicate(true);changed.settings.outer_radius+=1
 check(FrontierStellarRoutes.identity(changed)!=FrontierStellarRoutes.identity(manifest),"settings invalidate cache")
 changed=FrontierUniverse.generate(12940124)
 check(FrontierStellarRoutes.identity(changed)!=FrontierStellarRoutes.identity(manifest),"seed separates cache")
 print("NAVIGATION CACHE failures ",failures," cold generated ",cold," warm restored 1024")
 quit(1 if failures else 0)
