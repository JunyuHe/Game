extends Node2D
## Main scene: HUD, EXP/level display, Tab stats panel, orb spawning, game over screen.
## All visible text is pulled from the localization service so it follows the chosen language.

@export var orb_scene: PackedScene

@onready var health_label: Label = $UI/HealthLabel
@onready var kills_label: Label = $UI/KillsLabel
@onready var time_label: Label = $UI/TimeLabel
@onready var xp_label: Label = $UI/XpLabel
@onready var game_over_panel: ColorRect = $UI/GameOverPanel
@onready var stats_panel: ColorRect = $UI/StatsPanel
@onready var stats_title: Label = $UI/StatsPanel/VBox/TitleLabel
@onready var stat_level: Label = $UI/StatsPanel/VBox/LevelLabel
@onready var stat_exp: Label = $UI/StatsPanel/VBox/ExpLabel
@onready var stat_hp: Label = $UI/StatsPanel/VBox/HpLabel
@onready var stat_speed: Label = $UI/StatsPanel/VBox/SpeedLabel
@onready var stat_interval: Label = $UI/StatsPanel/VBox/IntervalLabel
@onready var stat_damage: Label = $UI/StatsPanel/VBox/DamageLabel
@onready var stat_kills: Label = $UI/StatsPanel/VBox/KillsLabel
@onready var game_over_label: Label = $UI/GameOverPanel/Center/VBox/GameOverLabel
@onready var restart_button: Button = $UI/GameOverPanel/Center/VBox/RestartButton

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
	Loc.language_changed.connect(_on_language_changed)
	_refresh_texts()

func _process(delta: float) -> void:
	if not _game_over and Input.is_action_just_pressed("toggle_stats"):
		stats_panel.visible = not stats_panel.visible
		if stats_panel.visible:
			_refresh_stats()
	if _game_over:
		return
	_elapsed += delta
	time_label.text = Loc.format_tr("hud_time", [int(_elapsed) / 60, int(_elapsed) % 60])

func on_mob_killed(position: Vector2, exp_value: int) -> void:
	kills += 1
	kills_label.text = Loc.format_tr("hud_kills", [kills])
	_spawn_orb(position, exp_value)

func _spawn_orb(position: Vector2, exp_value: int) -> void:
	if orb_scene == null:
		return
	var orb := orb_scene.instantiate()
	add_child(orb)
	orb.global_position = position
	orb.exp_value = exp_value

func _on_player_health_changed(current: int, max: int) -> void:
	health_label.text = Loc.format_tr("hud_health", [current, max])

func _on_player_exp_changed(level: int, exp: int, exp_to_next: int) -> void:
	xp_label.text = Loc.format_tr("hud_level_exp", [level, exp, exp_to_next])
	_refresh_stats()

func _refresh_stats() -> void:
	var player := $Player
	if player == null:
		return
	stat_level.text = Loc.format_tr("stats_level", [player.level])
	stat_exp.text = Loc.format_tr("stats_exp", [player.exp, player.exp_to_next()])
	stat_hp.text = Loc.format_tr("stats_hp", [player.health, player.max_health])
	stat_speed.text = Loc.format_tr("stats_speed", [int(player.speed)])

	var weapon := player.get_node_or_null("Weapon")
	var interval: float = weapon.fire_interval if weapon != null else 0.45
	stat_interval.text = Loc.format_tr("stats_interval", [interval])
	stat_damage.text = Loc.format_tr("stats_damage", [player.damage])
	stat_kills.text = Loc.format_tr("stats_kills", [kills])

## Re-applies every static label after a language change.
func _refresh_texts() -> void:
	var player := $Player
	stats_title.text = Loc.t("stats_title")
	game_over_label.text = Loc.t("game_over")
	restart_button.text = Loc.t("game_over_restart")
	if player == null:
		return
	health_label.text = Loc.format_tr("hud_health", [player.health, player.max_health])
	kills_label.text = Loc.format_tr("hud_kills", [kills])
	xp_label.text = Loc.format_tr("hud_level_exp", [player.level, player.exp, player.exp_to_next()])
	_refresh_stats()

func _on_language_changed(_code: String) -> void:
	_refresh_texts()

func _on_player_died() -> void:
	_game_over = true
	stats_panel.visible = false
	game_over_panel.visible = true

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
