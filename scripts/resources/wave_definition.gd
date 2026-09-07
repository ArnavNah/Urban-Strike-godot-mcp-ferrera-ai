class_name WaveDefinition
extends Resource

## Data definition for a single wave in the 10-wave run.

@export var wave_number: int = 1
@export var duration: float = 24.0
@export var spawn_interval: float = 3.0
@export var spawn_budget: int = 6
@export var maximum_alive: int = 5
@export var enemy_entries: Array[WaveEnemyEntry] = []
@export var final_wave: bool = false
@export var announcement: String = ""
@export var ground_attack_slots: int = 2
@export var air_attack_slots: int = 0
