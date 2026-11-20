extends CharacterBody2D
## Player: movement, health, EXP/level growth and level-up upgrade rewards.
## Body is a solid color block placeholder.

@export var speed: float = 220.0
@export var max_health: int = 5
## Invulnerability time after being hit (seconds). Short, so contact keeps hurting.
@export var hurt_delay: float = 0.6

# Growth stats
var level: int = 1
var exp: int = 0
var damage: int = 5
var defense: int = 0
## Luck biases high-quality rolls in the shop (0 = no bonus).
var luck: int = 0
## Chance (percent) to heal 1 HP when an enemy dies.
var lifesteal: int = 0
## Chance (percent) to ignore an incoming hit completely.
var dodge: int = 0

var health: int
var _hurt_cooldown: float = 0.0

## Number of levels whose reward cards are still waiting to be picked.
var pending_levels: int = 0
## One set of four options per pending level, oldest first.
var _pending_upgrades: Array = []

signal health_changed(current: int, max: int)
signal exp_changed(level: int, exp: int, exp_to_next: int)
signal stats_changed()
signal died
## Asks the upgrade UI to show these four options.
signal level_up_started(options: Array)

## Six quality tiers, worst to best. "weight" is the roll chance, the other values are the bonus for that stat.
const QUALITIES := [
	{"key": "base", "weight": 40, "hp": 2, "attack": 1, "defense": 1, "luck": 1, "lifesteal": 1, "dodge": 1},
	{"key": "common", "weight": 27, "hp": 4, "attack": 2, "defense": 2, "luck": 2, "lifesteal": 2, "dodge": 2},
	{"key": "fine", "weight": 17, "hp": 7, "attack": 3, "defense": 3, "luck": 3, "lifesteal": 3, "dodge": 3},
	{"key": "epic", "weight": 10, "hp": 11, "attack": 5, "defense": 5, "luck": 5, "lifesteal": 4, "dodge": 5},
	{"key": "mythic", "weight": 4, "hp": 16, "attack": 8, "defense": 8, "luck": 8, "lifesteal": 6, "dodge": 7},
	{"key": "legendary", "weight": 2, "hp": 24, "attack": 12, "defense": 12, "luck": 12, "lifesteal": 8, "dodge": 10}
]

const UPGRADE_STATS := ["hp", "attack", "defense", "luck", "lifesteal", "dodge"]
const CARDS_PER_LEVEL := 4

func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.connect(_on_health_changed)
	exp_changed.emit(level, exp, exp_to_next())
	stats_changed.emit()
	_update_health_bar()

func _on_health_changed(current: int, max_value: int) -> void:
	_update_health_bar()

## Health bar above the head: width follows the health ratio, color turns yellow then red.
func _update_health_bar() -> void:
	var bar := get_node_or_null("HealthBar/Fill") as ColorRect
	if bar == null:
		return
	var ratio: float = 1.0
	if max_health > 0:
		ratio = clampf(float(health) / float(max_health), 0.0, 1.0)
	var full_width := 42.0
	bar.size = Vector2(full_width * ratio, bar.size.y)
	if ratio > 0.6:
		bar.color = Color(0.35, 0.8509804, 0.4)
	elif ratio > 0.3:
		bar.color = Color(0.95, 0.8, 0.25)
	else:
		bar.color = Color(0.92, 0.3, 0.3)

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

	# Every equipped weapon shoots a little faster. The multiplier is stored on the
	# inventory so it survives the rebuild after every shop purchase or merge.
	var inventory := get_node_or_null("WeaponInventory")
	if inventory != null:
		inventory.fire_rate_mult = maxf(0.1, float(inventory.fire_rate_mult) * 0.93)
	var slots := get_node_or_null("WeaponSlots")
	if slots != null:
		for weapon in slots.get_children():
			if "fire_interval" in weapon:
				weapon.fire_interval = maxf(0.15, weapon.fire_interval * 0.93)

	if level % 3 == 0:
		damage += 1

	# Queue one set of reward cards for this level.
	pending_levels += 1
	_pending_upgrades.append(_roll_options(CARDS_PER_LEVEL))

	health_changed.emit(health, max_health)
	stats_changed.emit()

	# Only open the UI for the first pending level; later sets follow after each pick.
	if pending_levels == 1:
		level_up_started.emit(_current_options())

## Called by the upgrade UI with the index of the card the player clicked.
func choose_upgrade(index: int) -> void:
	var options := _current_options()
	if index < 0 or index >= options.size():
		return

	var option: Dictionary = options[index]
	var value: int = option["value"]
	match option["stat"]:
		"hp":
			max_health += value
			health = mini(health + value, max_health)
		"attack":
			damage += value
		"defense":
			defense += value
		"luck":
			luck += value
		"lifesteal":
			lifesteal = mini(100, lifesteal + value)
		"dodge":
			dodge = mini(75, dodge + value)

	_pending_upgrades.pop_front()
	pending_levels = maxi(0, pending_levels - 1)

	health_changed.emit(health, max_health)
	stats_changed.emit()

	# More levels waiting? Hand the next set to the UI, otherwise it closes and unpauses.
	if pending_levels > 0:
		level_up_started.emit(_current_options())

func _current_options() -> Array:
	if _pending_upgrades.is_empty():
		return []
	return _pending_upgrades[0]

func _roll_options(count: int) -> Array:
	var options: Array = []
	while options.size() < count:
		options.append(_roll_upgrade())
	return options

func _roll_upgrade() -> Dictionary:
	var quality := _pick_quality()
	var stat: String = UPGRADE_STATS[randi() % UPGRADE_STATS.size()]
	return {"quality": quality["key"], "stat": stat, "value": quality[stat]}

func _pick_quality() -> Dictionary:
	var total := 0
	for quality in QUALITIES:
		total += quality["weight"]
	var roll := randi() % total
	for quality in QUALITIES:
		roll -= quality["weight"]
		if roll < 0:
			return quality
	return QUALITIES[0]

func take_damage(amount: int) -> void:
	if _hurt_cooldown > 0.0:
		return
	# Dodge: a percentage chance to ignore the hit entirely.
	if dodge > 0 and randf() * 100.0 < float(dodge):
		_hurt_cooldown = hurt_delay * 0.5
		_flash_dodge()
		return
	var incoming := maxi(1, amount - defense)
	health = maxi(0, health - incoming)
	_hurt_cooldown = hurt_delay
	health_changed.emit(health, max_health)
	_flash()
	if health <= 0:
		died.emit()

## Restores health without ever going above the maximum.
func heal(amount: int) -> void:
	if amount <= 0 or health >= max_health:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)

## Lifesteal trigger: called by the main scene whenever an enemy dies.
func on_enemy_killed() -> void:
	if lifesteal > 0 and randf() * 100.0 < float(lifesteal):
		heal(1)

func _flash() -> void:
	var body := get_node_or_null("Body") as CanvasItem
	if body == null:
		return
	body.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(body, "modulate", Color.WHITE, 0.25)

## Different tint for a dodged hit, so the player can see it worked.
func _flash_dodge() -> void:
	var body := get_node_or_null("Body") as CanvasItem
	if body == null:
		return
	body.modulate = Color(0.6, 0.9, 1.0)
	var tween := create_tween()
	tween.tween_property(body, "modulate", Color.WHITE, 0.2)
