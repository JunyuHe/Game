extends CharacterBody2D
## Player: movement, health, EXP/level growth. Body is a solid color block placeholder.

@export var speed: float = 220.0
@export var max_health: int = 5
## Invulnerability time after being hit (seconds)
@export var hurt_delay: float = 0.8

# Growth stats
var level: int = 1
var exp: int = 0
var damage: int = 1

var health: int
var _hurt_cooldown: float = 0.0

signal health_changed(current: int, max: int)
signal exp_changed(level: int, exp: int, exp_to_next: int)
signal stats_changed()
signal died

func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)
	exp_changed.emit(level, exp, exp_to_next())
	stats_changed.emit()

## EXP needed for the next level: grows faster than linear, so later levels get harder.
func exp_to_next() -> int:
	return int(round(5.0 * pow(level, 1.5)))

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()

	if _hurt_cooldown > 0.0:
		_hurt_cooldown -= delta

func gain_exp(amount: int) -> void:
	exp += amount
	var need := exp_to_next()
	while exp >= need:
		exp -= need
		_level_up()
		need = exp_to_next()
	exp_changed.emit(level, exp, need)

func _level_up() -> void:
	level += 1
	max_health += 2
	health = mini(health + 2, max_health)
	speed = minf(speed + 6.0, 320.0)

	var weapon := get_node_or_null("Weapon")
	if weapon != null and "fire_interval" in weapon:
		weapon.fire_interval = maxf(0.18, weapon.fire_interval * 0.93)

	if level % 3 == 0:
		damage += 1

	health_changed.emit(health, max_health)
	stats_changed.emit()

func take_damage(amount: int) -> void:
	if _hurt_cooldown > 0.0:
		return
	health -= amount
	_hurt_cooldown = hurt_delay
	health_changed.emit(health, max_health)
	_flash()
	if health <= 0:
		died.emit()

func _flash() -> void:
	var body := get_node_or_null("Body") as CanvasItem
	if body == null:
		return
	body.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(body, "modulate", Color.WHITE, 0.25)
