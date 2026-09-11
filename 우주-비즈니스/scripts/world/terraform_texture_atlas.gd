extends RefCounted
## Exact cell resolution over occupied bounds, owned by the receiving material.
## No global world cache: reopening a save cannot reuse another session's pixels.
const META:="terraform_texture_atlas"
static func apply(material: ShaderMaterial,body_id: String,record: Dictionary) -> void:
 var cached: Dictionary=material.get_meta(META,{})
 if cached.get("body_id","")==body_id and cached.get("revision",-1)==int(record.revision):
  if not material.get_shader_parameter("free_enabled"):_bind(material,cached)
  return
 var samples:=_samples(record)
 var layout_changed: bool=cached.get("bounds",Rect2i())!=samples.bounds or cached.get("cells",PackedVector2Array())!=samples.cells
 for channel in ["values","extras","mask"]:
  if cached.has(channel) and not layout_changed and (channel=="mask" or cached.get(channel+"_data") == samples[channel+"_data"]):continue
  var picture:=_image(samples,channel)
  if cached.has(channel) and cached[channel].get_size()==Vector2(picture.get_size()):cached[channel].update(picture)
  else:cached[channel]=ImageTexture.create_from_image(picture)
 for key in ["bounds","cells","values_data","extras_data","origin","size"]:cached[key]=samples[key]
 cached.body_id=body_id;cached.revision=int(record.revision)
 material.set_meta(META,cached)
 _bind(material,cached)
static func _bind(material: ShaderMaterial,data: Dictionary) -> void:
 material.set_shader_parameter("free_enabled",true)
 for channel in ["values","extras","mask"]:material.set_shader_parameter("free_"+channel,data[channel])
 material.set_shader_parameter("free_origin",data.origin);material.set_shader_parameter("free_size",data.size)
 material.set_shader_parameter("region_count",0)
static func _samples(record: Dictionary) -> Dictionary:
 var cell_size: float=record.rules.cell_size
 var half:=ceili(float(record.rules.extent)/cell_size)
 var low:=Vector2i(half,half);var high:=Vector2i(-half,-half)
 var cells:=PackedVector2Array();var values:=PackedColorArray();var extras:=PackedColorArray()
 for cell in record.cells.values():
  var key:=Vector2i(floori(float(cell.position[0])/cell_size),floori(float(cell.position[2])/cell_size))
  if key.x < -half or key.y < -half or key.x>=half or key.y>=half:continue
  low=low.min(key);high=high.max(key+Vector2i.ONE)
  var e: Dictionary=cell.environment;var r: Dictionary=cell.restoration2;var state:=e.duplicate();state.merge(r,true)
  var conditions:=FrontierSurfaceRecovery.conditions(state)
  cells.append(Vector2(key))
  values.append(Color(float(e.temperature),float(conditions.life),float(conditions.water),float(e.pressure)))
  extras.append(Color(float(r.salinity)/100,float(r.soil)/100,float(e.ecology)/100,clampf(float(cell.pollution)/60,0,1)))
 if cells.is_empty():low=Vector2i.ZERO;high=Vector2i.ONE
 else:
  # One empty border preserves unmodified terrain at the cropped atlas edge.
  low=(low-Vector2i.ONE).max(Vector2i(-half,-half));high=(high+Vector2i.ONE).min(Vector2i(half,half))
 var bounds:=Rect2i(low,high-low)
 return {"bounds":bounds,"origin":Vector2(low)*cell_size,"size":Vector2(bounds.size)*cell_size,"cells":cells,"values_data":values,"extras_data":extras}
static func _image(samples: Dictionary,channel: String) -> Image:
 var bounds: Rect2i=samples.bounds
 var picture:=Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_R8 if channel=="mask" else Image.FORMAT_RGBAF)
 picture.fill(Color(0,0,0,0))
 for i in samples.cells.size():
  var key:=Vector2i(samples.cells[i])-bounds.position
  picture.set_pixelv(key,Color.WHITE if channel=="mask" else samples[channel+"_data"][i])
 return picture
