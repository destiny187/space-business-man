extends RefCounted
## Only active materials retain arrays; catalog growth does not load every map.
static var palettes: Dictionary={}
static func ids_for(profile: Dictionary) -> Array[String]:
 var ids: Array[String]=[]
 var required: Array=profile.get("region_rocks",[str(profile.rock)]).duplicate()
 required.append_array([str(profile.deposit),"snow","ice"])
 for id in required:
  if not ids.has(id):ids.append(id)
 ids.sort()
 return ids
static func texture(ids: Array[String],catalog: Array,resolution: int=1024) -> Texture2DArray:
 var key:=str(resolution)+":"+"|".join(ids)
 if palettes.has(key):
  var live=palettes[key].get_ref()
  if live!=null:return live
 var images: Array[Image]=[]
 for id in ids:
  var path:=""
  for row in catalog:
   if row.id==id:path=str(row.texture);break
  assert(not path.is_empty(),"Unknown surface material: "+id)
  var source:=load(path) as Texture2D
  var picture:=source.get_image()
  if picture.is_compressed():picture.decompress()
  picture.convert(Image.FORMAT_RGBA8)
  if picture.get_width()!=resolution:
   picture.clear_mipmaps();picture.resize(resolution,resolution,Image.INTERPOLATE_LANCZOS)
  if not picture.has_mipmaps():picture.generate_mipmaps()
  images.append(picture)
 var result:=Texture2DArray.new();var error:=result.create_from_images(images)
 assert(error==OK,"Surface palette creation failed")
 result.resource_name=key
 if palettes.size()>=32:
  # Removing a weak cache entry never invalidates a currently displayed array.
  palettes.erase(palettes.keys()[0])
 palettes[key]=weakref(result)
 return result
