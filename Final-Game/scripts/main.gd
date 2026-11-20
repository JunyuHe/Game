extends Node2D
## Main scene: HUD, EXP/level display, orb spawning, game over screen.
## The shop and the attribute panel live together in UI/ShopUI.
## All visible text is pulled from the localization service so it follows the chosen language.

@export var orb_scene: PackedScene

@onready var health_label: Label = $UI/HealthLabel
@onready var kills_label: Label = $UI/KillsLabel
@onready var time_label: Label = $UI/TimeLabel
@onready var wave_label: Label = $UI/WaveLabel
@onready var xp_label: Label = $UI/XpLabel
@onready var game_over_panel: ColorRect = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/Center/VBox/GameOverLabel
@onready var restart_button: Button = $UI/GameOverPanel/Center/VBox/RestartButton
@onready var menu_button: Button = $UI/GameOverPanel/Center/VBox/MenuButton
@onready var upgrade_ui: Control = $UI/UpgradeUI
@onready var gold_label: Label = $UI/GoldLabel
@onready var shop_ui: Control = $UI/ShopUI
@onready var inventory: Node = $Player/WeaponInventory

var kills: int = 0
var _elapsed: float = 0.0
var _game_over: bool = false

func _ready() -> void:
	add_to_group("main")
	game_over_panel.visible = false

	var player := $Player
	player.health_changed.connect(_on_player_health_changed)
	player.exp_changed.connect(_on_player_exp_changed)
	player.died.connect(_on_player_died)
	inventory.inventory_changed.connect(_on_inventory_changed)
	# Safety net: make sure the shop always sees the inventory, the wave counter and the player.
	shop_ui.inventory = inventory
	shop_ui.wave_manager = get_node("MobSpawner")
	shop_ui.player = player
	Loc.language_changed.connect(_on_language_changed)
	_refresh_texts()

func _process(delta: float) -> void:
	if _game_over:
		return
	_elapsed += delta
	time_label.text = Loc.format_tr("hud_time", [int(_elapsed) / 60, int(_elapsed) % 60])

func on_mob_killed(position: Vector2, exp_value: int) -> void:
	kills += 1
	kills_label.text = Loc.format_tr("hud_kills", [kills])
	# Gold reward scales with the enemy's EXP value (bigger enemies pay more).
	inventory.add_gold(maxi(1, exp_value * 2))
	# Lifesteal roll for this kill.
	var player := $Player
	if player != null:
		player.on_enemy_killed()
	# Mob deaths happen inside physics callbacks, so spawn the orb on the next idle frame.
	call_deferred("_spawn_orb", position, exp_value)

## Keeps the HUD gold label in sync with the inventory.
func _on_inventory_changed() -> void:
	gold_label.text = Loc.format_tr("hud_gold", [inventory.gold])

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

## Called by the spawner when the wave counter goes up.
func on_wave_changed(wave: int) -> void:
	wave_label.text = Loc.format_tr("hud_wave", [wave])

## Re-applies every static label after a language change.
func _refresh_texts() -> void:
	var player := $Player
	game_over_label.text = Loc.t("game_over")
	restart_button.text = Loc.t("game_over_retry")
	menu_button.text = Loc.t("game_over_menu")
	var spawner := get_node_or_null("MobSpawner")
	var wave: int = spawner.current_wave if spawner != null else 1
	wave_label.text = Loc.format_tr("hud_wave", [wave])
	gold_label.text = Loc.format_tr("hud_gold", [inventory.gold])
	if player == null:
		return
	health_label.text = Loc.format_tr("hud_health", [player.health, player.max_health])
	kills_label.text = Loc.format_tr("hud_kills", [kills])
	xp_label.text = Loc.format_tr("hud_level_exp", [player.level, player.exp, player.exp_to_next()])

func _on_language_changed(_code: String) -> void:
	_refresh_texts()

func _on_player_died() -> void:
	if _game_over:
		return
	_game_over = true
	# Close the level-up cards and the shop: the run is over.
	upgrade_ui.hide()
	shop_ui.hide()
	game_over_panel.visible = true
	# Freeze the whole run: player, enemies, bullets, spawning and the clock.
	get_tree().paused = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
