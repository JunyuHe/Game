extends Node2D
## Main scene: HUD, EXP/level display, Tab stats panel, orb spawning, game over screen.

@export var orb_scene: PackedScene

@onready var health_label: Label = $UI/HealthLabel
@onready var kills_label: Label = $UI/KillsLabel
@onready var time_label: Label = $UI/TimeLabel
@onready var xp_label: Label = $UI/XpLabel
@onready var game_over_panel: ColorRect = $UI/GameOverPanel
@onready var stats_panel: ColorRect = $UI/StatsPanel
@onready var stat_level: Label = $UI/StatsPanel/VBox/LevelLabel
@onready var stat_exp: Label = $UI/StatsPanel/VBox/ExpLabel
@onready var stat_hp: Label = $UI/StatsPanel/VBox/HpLabel
@onready var stat_speed: Label = $UI/StatsPanel/VBox/SpeedLabel
@onready var stat_interval: Label = $UI/StatsPanel/VBox/IntervalLabel
@onready var stat_damage: Label = $UI/StatsPanel/VBox/DamageLabel
@onready var stat_kills: Label = $UI/StatsPanel/VBox/KillsLabel

var kills: int = 0
var _elapsed: float = 0.0
var _game_over: bool = false

func _ready() -> void:
	add_to_group("main")
	game_over_panel.visible = false
	stats_panel.visible = false

	var player := $Player
	player.health_changed.connect(_on_player_health_changed)
	player.exp_changed.connect(_on_player_exp_changed)
	player.stats_changed.connect(_refresh_stats)
	player.died.connect(_on_player_died)
	_refresh_stats()

func _process(delta: float) -> void:
	if not _game_over and Input.is_action_just_pressed("toggle_stats"):
		stats_panel.visible = not stats_panel.visible
		if stats_panel.visible:
			_refresh_stats()
	if _game_over:
		return
	_elapsed += delta
	time_label.text = "Time: %02d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60]

func on_mob_killed(position: Vector2, exp_value: int) -> void:
	kills += 1
	kills_label.text = "Kills: %d" % kills
	_spawn_orb(position, exp_value)

func _spawn_orb(position: Vector2, exp_value: int) -> void:
	if orb_scene == null:
		return
	var orb := orb_scene.instantiate()
	add_child(orb)
	orb.global_position = position
	orb.exp_value = exp_value

func _on_player_health_changed(current: int, max: int) -> void:
	health_label.text = "Health: %d / %d" % [current, max]

func _on_player_exp_changed(level: int, exp: int, exp_to_next: int) -> void:
	xp_label.text = "Lv %d    %d / %d EXP" % [level, exp, exp_to_next]
	_refresh_stats()

func _refresh_stats() -> void:
	var player := $Player
	if player == null:
		return
	stat_level.text = "Level: %d" % player.level
	stat_exp.text = "EXP: %d / %d" % [player.exp, player.exp_to_next()]
	stat_hp.text = "HP: %d / %d" % [player.health, player.max_health]
	stat_speed.text = "Speed: %d" % int(player.speed)

	var weapon := player.get_node_or_null("Weapon")
	var interval: float = weapon.fire_interval if weapon != null else 0.45
	stat_interval.text = "Attack interval: %.2fs" % interval
	stat_damage.text = "Damage: %d" % player.damage
	stat_kills.text = "Kills: %d" % kills

func _on_player_died() -> void:
	_game_over = true
	stats_panel.visible = false
	game_over_panel.visible = true

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
