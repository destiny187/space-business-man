extends SceneTree
const Atlas=preload("res://scripts/world/terraform_texture_atlas.gd")
var failures:=0
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var fixture:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--fixture="):fixture=arg.trim_prefix("--fixture=")
 if fixture.is_empty():quit(2);return
 var world: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
 var site: Dictionary=world.business.sites.values()[0]
 var record: Dictionary=site.free_terraform.duplicate(true)
 var data:=Atlas._samples(record);var values:=Atlas._image(data,"values");var extras:=Atlas._image(data,"extras");var mask:=Atlas._image(data,"mask")
 var exact:=true
 for cell in record.cells.values():
  var at: Vector2i=Vector2i(floori(float(cell.position[0])/float(record.rules.cell_size)),floori(float(cell.position[2])/float(record.rules.cell_size)))-data.bounds.position
  var e: Dictionary=cell.environment;var r: Dictionary=cell.restoration2;var state:=e.duplicate();state.merge(r,true)
  var conditions:=FrontierSurfaceRecovery.conditions(state)
  exact=exact and values.get_pixelv(at)==Color(e.temperature,conditions.life,conditions.water,e.pressure)
  exact=exact and extras.get_pixelv(at)==Color(float(r.salinity)/100,float(r.soil)/100,float(e.ecology)/100,clampf(float(cell.pollution)/60,0,1)) and mask.get_pixelv(at).r==1.0
 check(exact,"cropped cells preserve exact float channels")
 check(data.bounds.size.x<32 and data.bounds.size.y<32 and mask.get_pixel(0,0).r==0,"sparse fixture retains an empty border without full-world images")
 var material:=ShaderMaterial.new();material.shader=load("res://assets/materials/space/terrain.gdshader")
 Atlas.apply(material,"fixture",record)
 var texture: ImageTexture=material.get_shader_parameter("free_values")
 var original_id:=texture.get_instance_id();var original_mask: Texture2D=material.get_shader_parameter("free_mask")
 var first: Dictionary=record.cells.values()[0];first.environment.temperature-=10;record.revision+=1
 Atlas.apply(material,"fixture",record)
 check(material.get_shader_parameter("free_values").get_instance_id()==original_id and material.get_shader_parameter("free_mask")==original_mask,"changing temperature reuses texture allocation and coverage")
 var other:=ShaderMaterial.new();other.shader=material.shader
 Atlas.apply(other,"fixture",record)
 check(other.get_shader_parameter("free_values")!=texture,"separate world materials own separate caches")
 var empty: Dictionary=record.duplicate(true);empty.cells={};empty.revision+=1
 Atlas.apply(material,"fixture",empty)
 check(material.get_shader_parameter("free_mask").get_size()==Vector2.ONE,"empty area uses a single unmodified pixel")
 Atlas.apply(material,"fixture",record)
 check(material.get_shader_parameter("free_values").get_size()==Vector2(data.bounds.size),"restoring an older revision rebuilds its exact bounds")
 print("ATLAS_SIZE ",data.bounds.size," OLD_SIZE ",ceili(float(record.rules.extent)/float(record.rules.cell_size))*2)
 quit(1 if failures else 0)
