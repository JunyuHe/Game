extends CharacterBody2D
## Enemy: chases the player, deals contact damage; has health, hit flash and death.

@export var speed: float = 70.0
@export var max_health: int = 3
@export var touch_damage: int = 1
## EXP value dropped on death
@export var exp_value: int = 1
## Interval between two contact hits from the same enemy (seconds)
@export var touch_delay: float = 0.6

var health: int
var _player: Node2D
var _touch_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("mobs")
	health = max_health
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return

	var dir := global_position.direction_to(_player.global_position)
	velocity = dir * speed
	move_and_slide()

	if _touch_cooldown > 0.0:
		_touch_cooldown -= delta

	if global_position.distance_to(_player.global_position) < 30.0 and _touch_cooldown <= 0.0:
		if _player.has_method("take_damage"):
			_player.take_damage(touch_damage)
			_touch_cooldown = touch_delay

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
