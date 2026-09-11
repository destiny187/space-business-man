extends RefCounted
## Visual state only. Original conditions prevent untreated cells looking restored.
const Palette=preload("res://scripts/world/surface_palette.gd")
static func bind(material: ShaderMaterial,body: Dictionary,site: Dictionary) -> void:
 if site.is_empty():material.set_shader_parameter("recovery_surface_enabled",false);return
 var cfg: Dictionary=FrontierSurfaceMaterialLibrary.config().recovery
 if not material.has_meta("recovery_surface_maps"):
  var ids: Array[String]=[]
  for id in cfg.materials:ids.append(str(id))
  material.set_shader_parameter("recovery_textures",Palette.texture(ids,FrontierSurfaceMaterialLibrary.config().materials,int(cfg.resolution)))
  material.set_shader_parameter("recovery_meters",Vector2(cfg.soil_meters,cfg.life_meters))
  material.set_shader_parameter("recovery_soil_color",Color(cfg.soil_color));material.set_shader_parameter("recovery_life_color",Color(cfg.life_color))
  material.set_meta("recovery_surface_maps",true)
 var original: Dictionary=body.get("traits",{}).duplicate()
 original.ecology=0.0;original.soil=100.0;original.salinity=0.0
 if FrontierFreeTerraform.active(site):
  original=site.free_terraform.base.duplicate();original.merge(site.free_terraform.restoration,true)
 var life:=float(FrontierSurfaceRecovery.conditions(original).life)
 material.set_shader_parameter("original_surface_state",Vector4(float(original.get("soil",100))/100,float(original.get("water",0))/100,float(original.get("salinity",0))/100,life))
 material.set_shader_parameter("recovery_surface_enabled",true)
