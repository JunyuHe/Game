extends CharacterBody2D
## Boss: appears every 5 waves. HP and contact damage come from lookup tables,
## and behaviour changes in three phases as its health drops.

signal health_changed(current: int, max: int)
signal boss_died

## Boss HP by wave (four times the original balance table, so fights last).
const HP_TABLE := {5: 800, 10: 1600, 15: 2600, 20: 3800, 25: 5200, 30: 7000}
## Contact damage by wave.
const DAMAGE_TABLE := {5: 8, 10: 12, 15: 15, 20: 20, 25: 25, 30: 30}

const BASE_SPEED := 60.0
const BASE_TOUCH_DELAY := 0.6
const EXP_REWARD := 40

var type_key: String = "boss"
var wave: int = 5
var max_hp: int = 800
var hp: int = 800
var touch_damage: int = 8
var speed: float = BASE_SPEED
var touch_delay: float = BASE_TOUCH_DELAY
var exp_value: int = EXP_REWARD
## 1 = normal (100%-70%), 2 = aggressive (70%-40%), 3 = enrage (below 40%).
var phase: int = 1

var _player: Node2D
var _touch_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("boss")
	add_to_group("mobs")
	_player = get_tree().get_first_node_in_group("player")
	_apply_phase(true)

## Called by the spawner when the boss enters the arena.
func setup_boss(wave_number: int) -> void:
	wave = maxi(1, wave_number)
	max_hp = _lookup(HP_TABLE, wave, 800)
	hp = max_hp
	touch_damage = _lookup(DAMAGE_TABLE, wave, 8)
	health_changed.emit(hp, max_hp)

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return

	_apply_phase()

	var dir := global_position.direction_to(_player.global_position)
	velocity = dir * speed
	move_and_slide()

	if _touch_cooldown > 0.0:
		_touch_cooldown -= delta

	if global_position.distance_to(_player.global_position) < 48.0 and _touch_cooldown <= 0.0:
		if _player.has_method("take_damage"):
			_player.take_damage(touch_damage)
			_touch_cooldown = touch_delay

## Phase by remaining health: faster and more aggressive as the fight goes on.
func _apply_phase(force: bool = false) -> void:
	var ratio: float = 1.0
	if max_hp > 0:
		ratio = float(hp) / float(max_hp)

	var new_phase := 1
	if ratio <= 0.4:
		new_phase = 3
	elif ratio <= 0.7:
		new_phase = 2

	if not force and new_phase == phase:
		return
	phase = new_phase

	match phase:
		1:
			speed = BASE_SPEED
			touch_delay = BASE_TOUCH_DELAY
			_set_tint(Color(0.72, 0.1, 0.18))
		2:
			speed = BASE_SPEED * 1.4
			touch_delay = BASE_TOUCH_DELAY * 0.75
			_set_tint(Color(0.9, 0.25, 0.15))
		3:
			speed = BASE_SPEED * 1.8
			touch_delay = BASE_TOUCH_DELAY * 0.5
			_set_tint(Color(1.0, 0.35, 0.1))

func _set_tint(color: Color) -> void:
	var placeholder := $Placeholder as ColorRect
	if placeholder != null:
		placeholder.color = color

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp)
	_flash()
	if hp <= 0:
		_die()

func _flash() -> void:
	var placeholder := $Placeholder as ColorRect
	if placeholder == null:
		return
	placeholder.modulate = Color(1.0, 1.0, 0.5)
	var tween := create_tween()
	tween.tween_property(placeholder, "modulate", Color.WHITE, 0.18)

func _die() -> void:
	boss_died.emit()
	get_tree().call_group("main", "on_mob_killed", global_position, EXP_REWARD)
	queue_free()

## Exact table hit, otherwise linear interpolation; beyond the table it keeps the last slope.
func _lookup(table: Dictionary, wave_number: int, fallback: int) -> int:
	if table.has(wave_number):
		return int(table[wave_number])

	var keys: Array = table.keys()
	keys.sort()
	if keys.is_empty():
		return fallback
	if wave_number <= int(keys[0]):
		return int(table[keys[0]])

	var last: int = keys.back()
	if wave_number >= last:
		var prev: int = keys[keys.size() - 2]
		var slope := float(table[last] - table[prev]) / float(last - prev)
		return int(round(float(table[last]) + slope * float(wave_number - last)))

	for i in range(keys.size() - 1):
		var a: int = keys[i]
		var b: int = keys[i + 1]
		if wave_number > a and wave_number < b:
			var t := float(wave_number - a) / float(b - a)
			return int(round(float(table[a]) + float(table[b] - table[a]) * t))
	return fallback
