extends CharacterBody2D
## Enemy: chases the player and deals contact damage.
## HP follows the wave: max_health = base_hp + (wave - 1) * hp_per_wave.

## Enemy archetypes: HP on wave 1, HP added per wave, plus movement and contact stats.
const TYPES := {
	"normal": {"base_hp": 12, "hp_per_wave": 5, "speed": 72.0, "touch_damage": 1, "exp_value": 2, "size": 26.0, "color": Color(0.85, 0.25, 0.35)},
	"fast": {"base_hp": 9, "hp_per_wave": 3, "speed": 140.0, "touch_damage": 1, "exp_value": 2, "size": 22.0, "color": Color(0.95, 0.62, 0.2)},
	"tank": {"base_hp": 40, "hp_per_wave": 9, "speed": 50.0, "touch_damage": 2, "exp_value": 4, "size": 34.0, "color": Color(0.45, 0.38, 0.8)},
	"elite": {"base_hp": 110, "hp_per_wave": 20, "speed": 88.0, "touch_damage": 3, "exp_value": 10, "size": 44.0, "color": Color(0.95, 0.85, 0.2)}
}

## Which archetype this enemy is; the spawner overwrites it through setup_enemy().
@export var type_key: String = "normal"
@export var speed: float = 70.0
@export var max_health: int = 10
@export var touch_damage: int = 1
## EXP value dropped on death
@export var exp_value: int = 2
## Interval between two contact hits from the same enemy (seconds).
## Kept short so touching an enemy hurts right away; the player's own
## invulnerability window (hurt_delay) is what limits how often health drops.
@export var touch_delay: float = 0.2

var health: int
var wave: int = 1
var _player: Node2D
var _touch_cooldown: float = 0.0
## Distance at which contact damage starts: own half-size plus a small body margin,
## so only a real overlap hurts and you can still brush past an enemy.
var _touch_radius: float = 21.0
## Red aura that marks elites apart from the crowd.
var _glow: ColorRect

func _ready() -> void:
	add_to_group("mobs")
	if health <= 0:
		health = max_health
	_player = get_tree().get_first_node_in_group("player")

## Called by the spawner right after instantiate(): sets stats from the current wave.
func setup_enemy(wave_number: int, enemy_type: String = "normal") -> void:
	wave = maxi(1, wave_number)
	type_key = enemy_type if TYPES.has(enemy_type) else "normal"
	var data: Dictionary = TYPES[type_key]

	max_health = int(data["base_hp"]) + (wave - 1) * int(data["hp_per_wave"])
	health = max_health
	speed = data["speed"]
	touch_damage = data["touch_damage"]
	exp_value = data["exp_value"]
	_touch_radius = float(data["size"]) * 0.5 + 8.0
	_apply_look(data)

func _apply_look(data: Dictionary) -> void:
	var half: float = float(data["size"]) * 0.5
	var placeholder := $Placeholder as ColorRect
	if placeholder != null:
		placeholder.color = data["color"]
		placeholder.offset_left = -half
		placeholder.offset_top = -half
		placeholder.offset_right = half
		placeholder.offset_bottom = half

	var shape_node := $CollisionShape2D as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		# Duplicate first: the scene resource is shared between instances.
		var circle: CircleShape2D = shape_node.shape.duplicate()
		circle.radius = half
		shape_node.shape = circle

	if type_key == "elite":
		_make_glow(half)

## Elites get a pulsing red aura so they read as a threat before they reach you.
func _make_glow(half: float) -> void:
	if _glow != null:
		return
	_glow = ColorRect.new()
	_glow.color = Color(1.0, 0.06, 0.03, 0.9)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.position = Vector2(-half * 1.45, -half * 1.45)
	_glow.size = Vector2(half * 2.9, half * 2.9)
	add_child(_glow)
	move_child(_glow, 0)
	var tween := create_tween().set_loops()
	tween.tween_property(_glow, "modulate:a", 0.6, 0.7)
	tween.tween_property(_glow, "modulate:a", 0.18, 0.7)

## Enemies steer slightly away from each other so a crowd spreads out instead of stacking.
const SEPARATION_RADIUS := 36.0
const SEPARATION_STRENGTH := 25.0

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return

	var dir := global_position.direction_to(_player.global_position)
	velocity = dir * speed + _separation_vector() * SEPARATION_STRENGTH
	move_and_slide()

	if _touch_cooldown > 0.0:
		_touch_cooldown -= delta

	if global_position.distance_to(_player.global_position) < _touch_radius and _touch_cooldown <= 0.0:
		if _player.has_method("take_damage"):
			_player.take_damage(touch_damage)
			_touch_cooldown = touch_delay

## Sum of pushes away from nearby enemies, normalised to roughly -1..1 per axis.
func _separation_vector() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("mobs"):
		if other == self:
			continue
		var offset: Vector2 = other.global_position - global_position
		var distance := offset.length()
		if distance > 0.1 and distance < SEPARATION_RADIUS:
			push -= offset.normalized() * (SEPARATION_RADIUS - distance) / SEPARATION_RADIUS
	return push.limit_length(1.0)

func take_damage(amount: int) -> void:
	health -= amount
	_flash()
	if health <= 0:
		_die()
	else:
		# Slight knockback when hit
		if _player != null:
			velocity = global_position.direction_to(_player.global_position) * -120.0

func _flash() -> void:
	var placeholder := $Placeholder as ColorRect
	if placeholder == null:
		return
	placeholder.modulate = Color(1.0, 1.0, 0.4)
	var tween := create_tween()
	tween.tween_property(placeholder, "modulate", Color.WHITE, 0.2)

func _die() -> void:
	get_tree().call_group("main", "on_mob_killed", global_position, exp_value)
	queue_free()
