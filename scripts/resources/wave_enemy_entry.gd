class_name WaveEnemyEntry
extends Resource

## Data definition for an enemy entry in a wave spawn table.

enum EnemyCategory {
	LIGHT_GROUND,
	MEDIUM_GROUND,
	ANTI_AIR,
	AIR,
	ELITE,
	BOSS
}

@export var enemy_scene: PackedScene
@export var spawn_weight: float = 1.0
@export var spawn_cost: int = 1
@export var minimum_wave: int = 1
@export var category: EnemyCategory = EnemyCategory.LIGHT_GROUND
