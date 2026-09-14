extends RefCounted
## Owns its terrain/cache and CPU image. Scene nodes and textures stay on the main thread.
var field: FrontierTerrainField
var body: Dictionary
var map_min: Vector2
var map_size: Vector2
var key: String
var result: Image
var resolution:=Vector2i(320,200)
func configure(source: FrontierTerrainField,planet: Dictionary,origin: Vector2,extent: Vector2,bake_key: String) -> void:
 field=FrontierTerrainField.new()
 field.configure(source.seed_value,[],source.span,source.traits)
 body={"kind":planet.kind,"traits":planet.get("traits",{}).duplicate(true)}
 map_min=origin;map_size=extent;key=bake_key
func run() -> void:
 result=bake()
func bake() -> Image:
 var width:=resolution.x;var height:=resolution.y
 var image:=Image.create(width,height,false,Image.FORMAT_RGBA8)
 var heights:=PackedFloat32Array();heights.resize((width+1)*(height+1))
 for z in height+1:
  for x in width+1:
   var point:=map_min+Vector2(float(x)/width,float(z)/height)*map_size
   heights[z*(width+1)+x]=field.height(point.x,point.y)
 # Smooth sub-pixel terrain roughness at this map scale so broad slopes read clearly.
 var sampled:=heights.duplicate()
 for z in height+1:
  for x in width+1:
   var value:=0.0
   for oz in range(-1,2):
    for ox in range(-1,2):
     var weight:=float((2 if ox==0 else 1)*(2 if oz==0 else 1))
     value+=sampled[clampi(z+oz,0,height)*(width+1)+clampi(x+ox,0,width)]*weight
   heights[z*(width+1)+x]=value/16.0
 for z in height:
  for x in width:
   var h:=heights[z*(width+1)+x]
   var dx: float=(heights[z*(width+1)+x+1]-h)/(map_size.x/width)
   var dz: float=(heights[(z+1)*(width+1)+x]-h)/(map_size.y/height)
   var relief:=clampf(dx*.7+dz*.45,-.3,.3)
   var color:=Color("566451").lerp(Color("b4a480"),clampf((h+30)/180,0,1))
   if body.kind=="glacial":color=Color("607f91").lerp(Color("bed5d5"),clampf((h+40)/180,0,1))
   if body.kind=="sulfur":color=Color("665947").lerp(Color("a89054"),clampf((h+40)/180,0,1))
   color=color.lightened(relief) if relief>0 else color.darkened(-relief)
   var contour_width:=clampf((absf(dx)*map_size.x/width+absf(dz)*map_size.y/height)*.7,.3,3)
   var contour:=minf(fposmod(h,20),20-fposmod(h,20))
   color=color.darkened((1-smoothstep(0,contour_width,contour))*.22)
   if h< -3.9 and float(body.get("traits",{}).get("water",0))>15 and float(body.get("traits",{}).get("temperature",-100))>0:color=Color("28545b")
   var point:=map_min+Vector2(float(x)/width,float(z)/height)*map_size
   if maxf(absf(point.x),absf(point.y))>8192:color=Color("10191f")
   image.set_pixel(x,z,color)
 return image
