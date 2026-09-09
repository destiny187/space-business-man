class_name FrontierSurfaceWaterView
extends Node3D
## Host snapshots drive one bounded mesh; no second client fluid simulation.
var surface: FrontierCrewSurfaceScene
var state: Dictionary=FrontierSurfaceWater.create()
var visual: MeshInstance3D
var material: ShaderMaterial
var pending: Dictionary={}
var building: Dictionary={}
var keys: Array=[]
var cursor:=0
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var colors:=PackedColorArray()
var nearest: Dictionary={"distance":INF,"kind":"river","position":Vector3.ZERO}
var mask_image: Image
var mask_texture: ImageTexture
var mask_origin:=Vector2.ZERO
var mask_target:=Vector2.INF
var mask_row:=0
var mask_building:=false
var mask_ready:=false
var clock_value:=0.0
var maximum_usec:=0
func configure(owner_surface: FrontierCrewSurfaceScene) -> void:
 surface=owner_surface;visual=MeshInstance3D.new();add_child(visual);visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 material=ShaderMaterial.new();material.shader=load("res://assets/materials/space/physical_water.gdshader");visual.material_override=material
 material.set_shader_parameter("water_color",Color(surface.body.get("traits",{}).get("sea","123d50")))
 if surface.hydrology.ocean!=null:
  mask_image=Image.create(128,128,false,Image.FORMAT_RF);mask_image.fill(Color(1,0,0,1));mask_texture=ImageTexture.create_from_image(mask_image)
  surface.hydrology.ocean.material_override.set_shader_parameter("terrain_mask",mask_texture)
func accept(value: Dictionary) -> void:
 if state.cells==value.cells:return
 state=value
 # Coalesce packets while finishing the previous mesh. Never restart an unfinished upload.
 pending=value
func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3) -> void:
 for p in [a,b,c,a,c,d]:vertices.append(p);normals.append(normal);colors.append(Color(1,1,1,1))
func _corner(x: int,y: int,z: int,fallback: float) -> float:
 var sum:=0.0;var count:=0
 for dx in [-1,0]:
  for dz in [-1,0]:
   var row: Array=building.cells.get(FrontierSurfaceWater.key(Vector3i(x+dx,y,z+dz)),[])
   if row.is_empty() or float(row[0])<.015:continue
   sum+=y+minf(1,float(row[0])+float(row[1]));count+=1
 return sum/count if count>0 else fallback
func _append(k: String) -> void:
 var row: Array=building.cells[k]
 if float(row[0])<.015:return
 var c:=FrontierSurfaceWater.point(k);var p:=Vector3(c)
 var bottom:=p.y+float(row[1]);var top:=p.y+minf(1,float(row[0])+float(row[1]))
 var a:=Vector3(p.x,_corner(c.x,c.y,c.z,top),p.z)
 var b:=Vector3(p.x+1,_corner(c.x+1,c.y,c.z,top),p.z)
 var d:=Vector3(p.x,_corner(c.x,c.y,c.z+1,top),p.z+1)
 var e:=Vector3(p.x+1,_corner(c.x+1,c.y,c.z+1,top),p.z+1)
 var above: Array=building.cells.get(FrontierSurfaceWater.key(c+Vector3i.UP),[])
 var covered_by_ocean:=surface.hydrology.native_liquid and absf(top-float(surface.hydrology.cfg.sea_level))<.04 and surface.terrain.field.height(p.x+.5,p.z+.5)<float(surface.hydrology.cfg.sea_level)
 if (above.is_empty() or float(above[0])<.015) and not covered_by_ocean:_quad(a,b,e,d,Vector3.UP)
 var sides: Array=[[Vector3i.LEFT,a,d],[Vector3i.RIGHT,b,e],[Vector3i.FORWARD,a,b],[Vector3i.BACK,d,e]]
 for side in sides:
  var other: Array=building.cells.get(FrontierSurfaceWater.key(c+side[0]),[])
  # Shared corner heights already close adjoining columns. Never draw internal voxel walls.
  if not other.is_empty() and float(other[0])>=.015:continue
  var first: Vector3=side[1];var second: Vector3=side[2]
  _quad(Vector3(first.x,bottom,first.z),Vector3(second.x,bottom,second.z),second,first,Vector3(side[0]))
func _mask() -> void:
 if mask_image==null:return
 var p: Vector3=surface.viewer.position
 var target:=Vector2(floorf(p.x/128)*128-256,floorf(p.z/128)*128-256)
 if not mask_building and target!=mask_target:mask_target=target;mask_row=0;mask_building=true
 var sea_material: ShaderMaterial=surface.hydrology.ocean.material_override
 sea_material.set_shader_parameter("viewer_under_land",p.y<surface.terrain.field.height(p.x,p.z)-1)
 if not mask_building:return
 # One row: no full height-map rebuild on a frame or terrain edit.
 for x in 128:
  var q:=mask_target+Vector2(x+.5,mask_row+.5)*4
  var height_delta:=surface.terrain.field.height(q.x,q.y)-float(surface.hydrology.cfg.sea_level)
  mask_image.set_pixel(x,mask_row,Color(height_delta,0,0,1))
 mask_row+=1
 if mask_row==128:
  mask_texture.update(mask_image);mask_origin=mask_target;mask_building=false;mask_ready=true
  sea_material.set_shader_parameter("mask_origin",mask_origin);sea_material.set_shader_parameter("mask_ready",true)
func _process(delta: float) -> void:
 if surface==null or not surface.session.active:return
 var app=surface.get_parent()
 if app is FrontierCrewExpedition and (app.any_menu_open() or (not get_window().has_focus() and not app.test_mode)):return
 var start:=Time.get_ticks_usec();clock_value+=delta;material.set_shader_parameter("flow_time",clock_value)
 _mask()
 if building.is_empty() and not pending.is_empty():
  building=pending;pending={};keys=building.cells.keys();cursor=0;vertices.clear();normals.clear();colors.clear()
 if building.is_empty():return
 for i in 96:
  if cursor>=keys.size() or Time.get_ticks_usec()-start>1000:break
  _append(keys[cursor]);cursor+=1
 if cursor>=keys.size():
  if vertices.is_empty():visual.mesh=null
  else:
   var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
   var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);visual.mesh=mesh
  building={}
 maximum_usec=maxi(maximum_usec,Time.get_ticks_usec()-start)
func nearest_water(p: Vector3) -> Dictionary:
 var result: Dictionary={"distance":INF,"kind":"river","position":Vector3.ZERO,"physical":true}
 for k in state.cells:
  var row: Array=state.cells[k]
  if float(row[0])<.03:continue
  var q:=Vector3(FrontierSurfaceWater.point(k))+Vector3(.5,minf(1,float(row[0])+float(row[1])),.5)
  var d:=q.distance_to(p)
  if d<float(result.distance):result.distance=d;result.position=q
 return result
