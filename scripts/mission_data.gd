class_name MissionData
extends Resource
@export var id: String
@export var title: String
@export_multiline var briefing: String
@export_multiline var log_main: String
@export_multiline var log_optional: String
@export var waves: Array[WaveData] = []
@export var rocks: PackedVector2Array = []
@export var forbidden: PackedVector2Array = []
@export var marker := Vector2i(-1, -1)
@export var mining_required := 0
@export var optional_rule := "miner"
@export var reward_tower := -1
@export var reward_module := ""
@export var tint := Color("142631")
