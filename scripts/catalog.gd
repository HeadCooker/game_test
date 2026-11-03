class_name GameCatalog
extends RefCounted
const TOWER_IDS := [0, 1, 2, 5, 6]

static func normalize_tower_ids(values: Array) -> Array:
	# JSON numbers are floats; Array.has uses strict numeric types.
	var result: Array = []
	for value in values:
		if not (value is int or value is float): continue
		var number := int(value)
		if float(value) == float(number) and TOWER_IDS.has(number) and not result.has(number): result.append(number)
	return result
const TOWER_NAMES := {0: "机枪塔", 1: "火炮塔", 2: "减速塔", 5: "电弧塔", 6: "轨道狙击塔"}
const MODULES := {"": "标准核心：没有额外代价", "scout": "侦察：钻地预警 +1 秒；核心生命 -10%", "industry": "工业：采矿上限 +1；初始合金 -30", "emergency": "应急：每波一次，生命降至30%时花20合金恢复10%"}
const ACHIEVEMENTS := {"first": "res://data/achievements/first.tres", "depth": "res://data/achievements/depth.tres", "ending": "res://data/achievements/ending.tres", "logs": "res://data/achievements/logs.tres", "shield": "res://data/achievements/shield.tres", "rail": "res://data/achievements/rail.tres", "chain": "res://data/achievements/chain.tres", "untouched": "res://data/achievements/untouched.tres", "extract": "res://data/achievements/extract.tres", "expedition": "res://data/achievements/expedition.tres", "boons": "res://data/achievements/boons.tres", "hard": "res://data/achievements/hard.tres"}
const SHOP := {"core_amber": {"title": "琥珀核心", "price": 50, "slot": "core"}, "tower_violet": {"title": "紫罗兰炮塔涂装", "price": 100, "slot": "tower"}, "bridge_raven": {"title": "渡鸦舰桥徽章", "price": 150, "slot": "badge"}}
const BOON_IDS := ["fire", "sight", "hull", "cargo", "drill", "barrier"]
const EVENT_IDS := ["distress", "scrap", "weather", "memory", "pressure", "beacon", "reactor", "silence"]
const MODIFIERS := {"armor": "硬壳迁徙：重甲比例增加", "swarm": "密集虫潮：敌人数量增加20%", "haste": "躁动：移动速度增加15%", "tunnel": "地下共鸣：钻地虫比例增加"}

static func mission(index: int) -> MissionData:
	return load("res://data/missions/mission_%d.tres" % index)

static func card(id: String) -> ExpeditionCard:
	return load("res://data/expedition/%s.tres" % id)

static func unlocked_towers(profile: Dictionary) -> Array:
	var result: Array = [0]
	for i in range(1, 7):
		if profile.records.has(str(i)):
			var id := mission(i).reward_tower
			if id >= 0 and not result.has(id): result.append(id)
	return result

static func unlocked_modules(profile: Dictionary) -> Array:
	var result: Array = [""]
	for i in range(1, 7):
		if profile.records.has(str(i)):
			var key := mission(i).reward_module
			if not key.is_empty(): result.append(key)
	return result

static func wave_copy(source: WaveData) -> WaveData:
	return source.duplicate(true) as WaveData

static func achievement(key: String) -> AchievementData:
	return load(ACHIEVEMENTS[key])
