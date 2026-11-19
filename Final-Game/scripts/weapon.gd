extends Node2D
## Weapon: auto-targets the nearest enemy in range and fires bullets at it periodically.

@export var bullet_scene: PackedScene
@export var fire_interval: float = 0.45
@export var bullet_speed: float = 420.0
@export var target_range: float = 480.0

signal fired

var _cooldown: float = 0.0
var _player: Node2D

func _ready() -> void:
	_cooldown = 0.0
	_player = get_parent() as Node2D

func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _find_nearest_enemy()
	if target != null:
		aim_at(target.global_position)
		_fire(target.global_position)
		_cooldown = fire_interval

func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := target_range
	for enemy in get_tree().get_nodes_in_group("mobs"):
		var candidate := enemy as Node2D
		if candidate == null:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func aim_at(target_position: Vector2) -> void:
	rotation = global_position.direction_to(target_position).angle()

func _fire(target_position: Vector2) -> void:
	if bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.direction = global_position.direction_to(target_position)
	bullet.speed = bullet_speed
	if _player != null and "damage" in _player:
		bullet.damage = _player.damage
	fired.emit()
