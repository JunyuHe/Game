extends Node2D
## Spawner: one wave every wave_duration seconds; spawn rate speeds up, bursts grow
## and elites / new archetypes unlock as the wave number grows. Enemy HP follows the wave.

@export var mob_scene: PackedScene
## Boss scene: a boss shows up every 5 waves.
@export var boss_scene: PackedScene
@export var initial_interval: float = 1.0
@export var min_interval: float = 0.2
@export var spawn_radius: float = 520.0
@export var max_mobs: int = 60
## Seconds per wave. The wave counter goes up on this clock.
@export var wave_duration: float = 30.0
## Extra enemies per spawn tick as waves progress: 1 + wave / 4, capped here.
@export var burst_cap: int = 4
## How much faster the spawn ticks get per wave.
@export var interval_step: float = 0.12
## Elites are locked until elite_start_time, then their roll grows every wave.
@export var elite_start_time: float = 180.0
@export var elite_chance_base: float = 0.03
@export var elite_chance_per_wave: float = 0.025
@export var elite_chance_cap: float = 0.3
## Never more than this many elites on screen at the same time.
@export var max_elites: int = 3

var current_wave: int = 1

var _timer: float = 0.0
var _elapsed: float = 0.0

func _physics_process(delta: float) -> void:
	_elapsed += delta
	_update_wave()

	var interval := maxf(min_interval, initial_interval - float(current_wave - 1) * interval_step)
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval
		for i in _spawn_count():
			_spawn()

## How many enemies one spawn tick produces at the current wave.
func _spawn_count() -> int:
	return clampi(1 + current_wave / 4, 1, burst_cap)

func _update_wave() -> void:
	var wave := 1 + int(_elapsed / wave_duration)
	if wave != current_wave:
		current_wave = wave
		get_tree().call_group("main", "on_wave_changed", current_wave)
		if wave % 5 == 0:
			_spawn_boss(wave)

## One boss every 5 waves, with HP and damage taken from the boss tables.
func _spawn_boss(wave: int) -> void:
	if boss_scene == null:
		return
	# Never stack two bosses on top of each other.
	if not get_tree().get_nodes_in_group("boss").is_empty():
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var boss := boss_scene.instantiate()
	boss.setup_boss(wave)
	get_parent().add_child(boss)

	var angle := randf() * TAU
	boss.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius

## Which enemy archetype to spawn now: new types unlock with the wave counter.
## Elites are not part of these weights, they come from their own chance roll.
func _pick_type(wave: int) -> String:
	var weights := {"normal": maxf(25.0, 100.0 - float(wave) * 4.0)}
	if wave >= 3:
		weights["fast"] = 30.0
	if wave >= 5:
		weights["tank"] = 18.0

	var total := 0.0
	for key in weights:
		total += weights[key]
	var roll := randf() * total
	for key in weights:
		roll -= weights[key]
		if roll <= 0.0:
			return key
	return "normal"

## Chance an individual spawn turns into an elite. Locked at zero for the first
## elite_start_time seconds (3 minutes), then it climbs every wave.
func elite_chance() -> float:
	if _elapsed < elite_start_time:
		return 0.0
	var waves_since := float(int((_elapsed - elite_start_time) / wave_duration))
	return minf(elite_chance_cap, elite_chance_base + waves_since * elite_chance_per_wave)

func _roll_elite() -> bool:
	if _elapsed < elite_start_time:
		return false
	return randf() < elite_chance()

func _elite_count() -> int:
	var count := 0
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob.get("type_key") == "elite":
			count += 1
	return count

func _spawn() -> void:
	if mob_scene == null:
		return
	var mobs := get_tree().get_nodes_in_group("mobs")
	if mobs.size() >= max_mobs:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var type_key := "normal"
	# Elites are rarer and capped, so a bad roll never floods the screen with them.
	if _roll_elite() and _elite_count() < max_elites:
		type_key = "elite"
	else:
		type_key = _pick_type(current_wave)

	var mob := mob_scene.instantiate()
	mob.setup_enemy(current_wave, type_key)
	get_parent().add_child(mob)

	# Jitter the spawn ring so a burst of enemies does not pop out on the exact same spot.
	var angle := randf() * TAU
	var distance := spawn_radius + randf_range(-60.0, 60.0)
	mob.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * distance
