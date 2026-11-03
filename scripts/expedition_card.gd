class_name ExpeditionCard
extends Resource
@export var id: String
@export var title: String
@export_multiline var description: String
@export var effects: Dictionary = {}
@export var choices: PackedStringArray = []
@export var alternatives: Array[Dictionary] = []
