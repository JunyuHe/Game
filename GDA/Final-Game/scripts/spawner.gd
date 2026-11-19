extends Node2D
## Spawner: spawns enemies at random points on a ring around the player; speeds up over time and caps on-screen count.

@export var mob_scene: PackedScene
@export var initial_interval: float = 1.5
@export var min_interval: float = 0.4
@export var spawn_radius: float = 520.0
@export var max_mobs: int = 25

var _timer: float = 0.0
var _elapsed: float = 0.0

func _physics_process(delta: float) -> void:
	_elapsed += delta
	var interval := maxf(min_interval, initial_interval - _elapsed * 0.01)
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval
		_spawn()

func _spawn() -> void:
	if mob_scene == null:
		return
	if get_tree().get_nodes_in_group("mobs").size() >= max_mobs:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var mob := mob_scene.instantiate()
	get_parent().add_child(mob)
	var angle := randf() * TAU
	mob.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius
