class_name FrontierSuitDye
extends RefCounted
static func valid_colors(value: Variant) -> bool:
	if not value is Dictionary or value.size()>3:return false
	for key in value:
		if key not in FrontierSuitAppearance.config().channels or not value[key] is String:return false
		var color: String=value[key]
		if color.length()!=6 or not Color.html_is_valid(color):return false
		for letter in color:
			if letter not in "0123456789abcdef":return false
	return true
static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.size()>6:return false
	for part in value:
		if not FrontierSuitAppearance.config().parts.has(part) or not valid_colors(value[part]):return false
	return true
static func cost(part: String,colors: Dictionary) -> Dictionary:
	return {} if colors.is_empty() else FrontierSuitAppearance.config().dye_costs[part]
static func apply(world: Dictionary,actor: String,args: Dictionary) -> String:
	if args.size()!=3 or not args.get("part") is String or not FrontierSuitAppearance.config().parts.has(args.part) or not valid_colors(args.get("colors")) or not valid_colors(args.get("expected")):return "염색 요청 오류"
	var member: Dictionary=world.crew.members[actor]
	var dyes: Dictionary=member.get("suit_dyes",{})
	if dyes.get(args.part,{})!=args.expected:return "색상이 바뀌었습니다. 다시 선택하세요."
	if dyes.get(args.part,{})==args.colors:return "이미 적용된 색상입니다."
	var price:=cost(args.part,args.colors)
	if not FrontierExpeditionBusiness.affordable(FrontierExpeditionBusiness.bag(world,actor),price):return "재료가 부족합니다."
	if not price.is_empty():FrontierExpeditionBusiness.transfer(world.business.bags[actor],price,-1)
	if not member.has("suit_dyes"):member.suit_dyes={}
	if args.colors.is_empty():member.suit_dyes.erase(args.part)
	else:member.suit_dyes[args.part]=args.colors.duplicate()
	return ""
