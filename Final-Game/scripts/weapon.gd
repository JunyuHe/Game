extends Node2D
## Weapon: auto-targets the nearest enemy in range and fires on its own cooldown.
## Its damage is ceil(base * quality multiplier) + the character's attack.

@export var bullet_scene: PackedScene
@export var fire_interval: float = 0.6
@export var bullet_speed: float = 420.0
@export var target_range: float = 480.0

var weapon_id: String = "pistol"
var quality_key: String = "base"
var base_damage: int = 5
var damage_mult: float = 1.0
var pellets: int = 1
var spread: float = 0.0

var _cooldown: float = 0.0
var _player: Node2D

func _ready() -> void:
	add_to_group("weapons")
	if _player == null:
		_player = get_parent().get_parent() as Node2D
	_cooldown = randf() * maxf(0.05, fire_interval)

## Called by WeaponSlots right after instantiate().
func setup_weapon(id: String, quality: String, inventory: Node, player_node: Node2D) -> void:
	weapon_id = id
	quality_key = quality
	var data: Dictionary = inventory.WEAPON_DATA[id]

	base_damage = int(data["damage"])
	damage_mult = float(inventory.QUALITY_DATA[quality]["damage_mult"])
	fire_interval = maxf(0.15, float(data["cooldown"]) * float(inventory.fire_rate_mult))
	bullet_speed = float(data.get("speed", 420.0))
	target_range = float(data.get("range", 480.0))
	pellets = int(data.get("pellets", 1))
	spread = float(data.get("spread", 0.0))
	_player = player_node

	set_quality_color(Color(inventory.QUALITY_DATA[quality]["color"]))

## Tints the weapon marker with the quality color.
func set_quality_color(color: Color) -> void:
	var body := get_node_or_null("Body") as ColorRect
	if body != null:
		body.color = color

func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return

	var target := _find_nearest_enemy()
	if target == null:
		return

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

	var attack_bonus := 0
	if _player != null and "damage" in _player:
		attack_bonus = int(_player.damage)

	var final_damage := ceili(float(base_damage) * damage_mult) + attack_bonus
	var base_direction := global_position.direction_to(target_position)

	for i in pellets:
		var bullet := bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position
		bullet.speed = bullet_speed
		bullet.damage = final_damage

		var offset := 0.0
		if pellets > 1:
			offset = spread * (float(i) - float(pellets - 1) * 0.5)
		bullet.direction = base_direction.rotated(offset)
