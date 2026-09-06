class_name FrontierRadar
extends Control

var campaign: FrontierCampaign

func _draw() -> void:
	var middle: Vector2 = size/2
	var scale_value: float = minf(size.x,size.y)/180
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.07,0.10,0.92))
	for i in range(1,4): draw_circle(middle,float(i)*size.x/8,Color(0.35,0.53,0.53,0.22),false,1,true)
	draw_line(Vector2(middle.x,0),Vector2(middle.x,size.y),Color(0.4,0.6,0.6,0.2))
	draw_line(Vector2(0,middle.y),Vector2(size.x,middle.y),Color(0.4,0.6,0.6,0.2))
	if campaign == null or campaign.planet.is_empty(): return
	var p: Dictionary = campaign.planet
	for node in p.nodes:
		if node.amount <= 0: continue
		var location: Vector2 = middle+FrontierCampaign.point(node.position)*scale_value
		draw_circle(location,1.6,Color(FrontierCatalog.entry("resources",node.resource).color))
	for event in p.events:
		var location: Vector2 = middle+FrontierCampaign.point(event.position)*scale_value
		draw_circle(location,3,Color("d5adfa") if event.discovered else Color("7d8091"),false,1)
	for building in p.buildings:
		var location: Vector2 = middle+FrontierCampaign.point(building.position)*scale_value
		draw_rect(Rect2(location-Vector2.ONE*2.4,Vector2.ONE*4.8),Color("c6dbc4"))
	for robot in p.robots:
		draw_circle(middle+FrontierCampaign.point(robot.position)*scale_value,2.3,Color("82dac4"))
	var player: Vector2 = middle+FrontierCampaign.point(p.player.position)*scale_value
	var yaw: float = p.player.yaw
	var direction := Vector2(-sin(yaw),-cos(yaw))
	draw_line(player,player+direction*11,Color("ffffff"),2,true)
	draw_circle(player,3.5,Color.WHITE)
