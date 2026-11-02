class_name EnemyData
extends Resource
@export var title: String = "工虫"
@export var health: float = 42.0
@export var speed: float = 14.0
@export var damage: float = 7.0
@export var reward: int = 3
@export var armor: float = 0.0
@export var size: float = 4.0
@export var tint: Color = Color("d39a6d")
@export_enum("normal", "burrow", "spitter", "shield", "boss") var ability: String = "normal"
@export var shield: float = 0.0
@export var attack_range: float = 17.0
@export var attack_interval: float = 1.0
@export_range(0.0, 1.0) var slow_resistance: float = 0.0
