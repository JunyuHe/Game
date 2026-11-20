extends Control
## Unified shop + attributes screen (B or Tab).
## Left: four random quality weapons for the current wave, then the equipped slots
## (click one to open the sell / cancel menu and sell it at half price). Right: live character stats.

@export var inventory: Node
@export var wave_manager: Node
@export var player: Node2D

@onready var background: ColorRect = $Background
@onready var title_label: Label = $Margin/HBox/Left/Header/Title
@onready var gold_label: Label = $Margin/HBox/Left/Header/GoldLabel
@onready var hint_label: Label = $Margin/HBox/Left/HintLabel
@onready var item_list: VBoxContainer = $Margin/HBox/Left/ItemList
@onready var sell_title: Label = $Margin/HBox/Left/SellTitle
@onready var owned_grid: GridContainer = $Margin/HBox/Left/OwnedGrid
@onready var merge_label: Label = $Margin/HBox/Left/MergeLabel
@onready var close_button: Button = $Margin/HBox/Left/Footer/CloseButton
@onready var reroll_button: Button = $Margin/HBox/Left/Footer/RerollButton

@onready var stats_title: Label = $Margin/HBox/Right/StatsMargin/Stats/StatsTitle
@onready var level_label: Label = $Margin/HBox/Right/StatsMargin/Stats/LevelLabel
@onready var hp_label: Label = $Margin/HBox/Right/StatsMargin/Stats/HpLabel
@onready var atk_label: Label = $Margin/HBox/Right/StatsMargin/Stats/AtkLabel
@onready var def_label: Label = $Margin/HBox/Right/StatsMargin/Stats/DefLabel
@onready var speed_label: Label = $Margin/HBox/Right/StatsMargin/Stats/SpeedLabel
@onready var luck_label: Label = $Margin/HBox/Right/StatsMargin/Stats/LuckLabel
@onready var lifesteal_label: Label = $Margin/HBox/Right/StatsMargin/Stats/LifestealLabel
@onready var dodge_label: Label = $Margin/HBox/Right/StatsMargin/Stats/DodgeLabel
@onready var kills_label: Label = $Margin/HBox/Right/StatsMargin/Stats/KillsLabel
@onready var wave_label: Label = $Margin/HBox/Right/StatsMargin/Stats/WaveLabel

var shop_items: Array = []
var last_shop_wave: int = -1
var _bound: bool = false
## How many times the current wave's stock has been re-rolled (drives the price).
var reroll_count: int = 0

## Right-click context menu for selling one equipped weapon.
var sell_popup: PanelContainer
var popup_label: Label
var popup_sell_button: Button
var popup_cancel_button: Button
var pending_sell_index: int = -1
## Bumped every time a merge toast appears, so an older timer never hides a newer toast.
var _toast_token: int = 0

const ITEMS_PER_SHOP := 4
## Cost of the first refresh in a wave, and how much it grows with each refresh.
const REROLL_BASE_COST := 60
const REROLL_STEP_COST := 40
## Extra weight given to each quality tier per 100 luck (0 for base, up to 1.6x for legendary).
const LUCK_BIAS := [0.0, 0.12, 0.3, 0.6, 1.0, 1.6]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("shop_ui")
	hide()

	close_button.pressed.connect(_close_shop)
	reroll_button.pressed.connect(_reroll)
	Loc.language_changed.connect(_on_language_changed)
	_build_sell_popup()
	background.gui_input.connect(_on_background_input)

	_resolve_targets()
	call_deferred("_bind_inventory")
	_refresh_texts()

## Instance NodePath overrides are not always resolved, so fall back to a tree lookup.
func _resolve_targets() -> void:
	var scene_root: Node = owner
	if scene_root == null:
		scene_root = get_tree().current_scene
	if scene_root == null:
		return
	if inventory == null:
		inventory = scene_root.get_node_or_null("Player/WeaponInventory")
	if wave_manager == null:
		wave_manager = scene_root.get_node_or_null("MobSpawner")
	if player == null:
		player = scene_root.get_node_or_null("Player") as Node2D

func _bind_inventory() -> void:
	if _bound:
		return
	if inventory == null:
		push_error("ShopUI: assign Inventory in the Inspector.")
		return
	_bound = true
	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.weapon_merged.connect(_on_weapon_merged)

func _unhandled_input(event: InputEvent) -> void:
	# B and Tab now open the very same screen.
	if event.is_action_pressed("toggle_shop") or event.is_action_pressed("toggle_stats"):
		if visible:
			_close_shop()
		else:
			_open_shop()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_close_shop()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reroll()
		get_viewport().set_input_as_handled()

func _open_shop() -> void:
	if inventory == null or wave_manager == null:
		return
	# Never stack on top of level-up cards or the game over screen.
	if _upgrade_cards_visible() or _game_is_over():
		return
	var wave: int = int(wave_manager.current_wave)
	# Refresh only once per wave, so closing and reopening never re-rolls the stock.
	if last_shop_wave != wave:
		_generate_shop(wave)
		last_shop_wave = wave
		reroll_count = 0

	_refresh_all()
	merge_label.visible = false
	show()
	get_tree().paused = true

func _close_shop() -> void:
	_close_sell_popup()
	merge_label.visible = false
	_toast_token += 1
	hide()
	get_tree().paused = false

func _upgrade_cards_visible() -> bool:
	for node in get_tree().get_nodes_in_group("upgrade_ui"):
		if node is CanvasItem and node.visible:
			return true
	return false

func _game_is_over() -> bool:
	var main := get_tree().get_first_node_in_group("main")
	return main != null and bool(main.get("_game_over"))

## Quality weights per wave band; luck shifts the odds towards the better tiers.
func _roll_quality(wave: int, luck: int) -> String:
	var weights: Array
	if wave <= 5:
		weights = [50.0, 30.0, 15.0, 4.0, 0.9, 0.1]
	elif wave <= 15:
		weights = [25.0, 30.0, 25.0, 15.0, 4.0, 1.0]
	else:
		weights = [10.0, 20.0, 30.0, 25.0, 12.0, 3.0]

	var bonus := float(luck) / 100.0
	var total := 0.0
	for i in weights.size():
		weights[i] = float(weights[i]) * (1.0 + bonus * LUCK_BIAS[i])
		total += weights[i]

	var roll := randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return String(inventory.QUALITY_KEYS[i])
	return String(inventory.QUALITY_KEYS[0])

func _generate_shop(wave: int) -> void:
	shop_items.clear()
	var luck := int(player.luck) if player != null else 0
	var ids: Array = inventory.WEAPON_DATA.keys()
	for i in ITEMS_PER_SHOP:
		shop_items.append({
			"id": ids.pick_random(),
			"quality": _roll_quality(wave, luck),
			"sold": false
		})

func _refresh_all() -> void:
	_close_sell_popup()
	_refresh_header()
	_refresh_items()
	_refresh_owned()
	_refresh_stats()

## Price of the next refresh: it grows every time you re-roll within the same wave.
func _reroll_cost() -> int:
	return REROLL_BASE_COST + REROLL_STEP_COST * reroll_count

## Pay gold to throw away the four current offers and roll four new ones.
func _reroll() -> void:
	if inventory == null or wave_manager == null or shop_items.is_empty():
		return
	var cost: int = _reroll_cost()
	if inventory.gold < cost:
		return
	inventory.gold -= cost
	inventory.inventory_changed.emit()
	reroll_count += 1
	# A refresh brings the sold slots back as brand-new offers.
	_generate_shop(int(wave_manager.current_wave))
	_refresh_all()

func _refresh_header() -> void:
	if inventory == null:
		return
	gold_label.text = Loc.format_tr("shop_gold", [inventory.gold])
	sell_title.text = Loc.format_tr("shop_sell_title", [inventory.weapons.size(), inventory.MAX_WEAPONS])
	var cost: int = _reroll_cost()
	reroll_button.text = Loc.format_tr("shop_refresh", [cost])
	reroll_button.disabled = inventory.gold < cost
	reroll_button.tooltip_text = Loc.t("shop_refresh_tip")

func _refresh_items() -> void:
	for child in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()
	if inventory == null:
		return

	for i in shop_items.size():
		var item: Dictionary = shop_items[i]
		var id: String = item["id"]
		var quality: String = item["quality"]
		var price: int = inventory.get_weapon_price(id, quality)
		var damage: int = inventory.get_weapon_damage(id, quality)

		var button := Button.new()
		button.custom_minimum_size = Vector2(640, 46)
		button.add_theme_font_size_override("font_size", 17)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_list.add_child(button)

		var color := Color(inventory.QUALITY_DATA[quality]["color"])
		_style_button(button, color, 2, 8)

		if item["sold"]:
			button.text = Loc.format_tr("shop_sold_item", [
				Loc.t("quality_" + quality),
				inventory.get_weapon_name(id)
			])
		else:
			button.text = Loc.format_tr("shop_item", [
				Loc.t("quality_" + quality),
				inventory.get_weapon_name(id),
				damage,
				price
			])

		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		var full: bool = inventory.weapons.size() >= inventory.MAX_WEAPONS
		button.disabled = (
			item["sold"]
			or inventory.gold < price
			or (full and not inventory.has_merge_partner(id, quality))
		)
		var tip: String = _tooltip_text(damage, float(inventory.WEAPON_DATA[id]["cooldown"]))
		if inventory.has_merge_partner(id, quality):
			var next_q: String = inventory.next_quality(quality)
			tip += "\n" + Loc.format_tr("shop_merge_hint", [Loc.t("quality_" + next_q)])
		button.tooltip_text = tip
		button.pressed.connect(_buy_item.bind(i))

## Equipped weapons: one button per slot; clicking opens the sell confirmation menu.
func _refresh_owned() -> void:
	for child in owned_grid.get_children():
		owned_grid.remove_child(child)
		child.queue_free()
	if inventory == null:
		return

	var count: int = inventory.weapons.size()
	for i in count:
		var item: Dictionary = inventory.weapons[i]
		var quality: String = item["quality"]
		var id: String = item["id"]
		var sell_price: int = floori(float(inventory.get_weapon_price(id, quality)) * 0.5)

		var button := Button.new()
		button.custom_minimum_size = Vector2(176, 44)
		button.add_theme_font_size_override("font_size", 14)
		button.text = Loc.format_tr("shop_sell_item", [
			Loc.t("quality_" + quality),
			inventory.get_weapon_name(id),
			sell_price
		])
		var color := Color(inventory.QUALITY_DATA[quality]["color"])
		_style_button(button, color, 2, 8)
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		# The last weapon cannot be sold, otherwise the player would be unarmed.
		button.disabled = count <= 1
		var attack: int = int(player.damage) if player != null else 0
		button.tooltip_text = _tooltip_text(inventory.get_final_damage(id, quality, attack), _owned_interval(i))
		# No more one-click selling: left or right click only opens the confirm menu.
		button.pressed.connect(_open_sell_popup.bind(i))
		button.gui_input.connect(_on_owned_input.bind(i))
		owned_grid.add_child(button)

func _refresh_stats() -> void:
	if player == null:
		return
	level_label.text = Loc.format_tr("stats_level", [player.level])
	hp_label.text = Loc.format_tr("stats_hp", [player.health, player.max_health])
	atk_label.text = Loc.format_tr("stats_damage", [player.damage])
	def_label.text = Loc.format_tr("stats_defense", [player.defense])
	speed_label.text = Loc.format_tr("stats_speed", [int(player.speed)])
	luck_label.text = Loc.format_tr("stats_luck", [player.luck])
	lifesteal_label.text = Loc.format_tr("stats_lifesteal", [player.lifesteal])
	dodge_label.text = Loc.format_tr("stats_dodge", [player.dodge])
	kills_label.text = Loc.format_tr("stats_kills", [_kills()])
	var wave: int = int(wave_manager.current_wave) if wave_manager != null else 1
	wave_label.text = Loc.format_tr("hud_wave", [wave])

func _kills() -> int:
	var main := get_tree().get_first_node_in_group("main")
	if main == null:
		return 0
	return int(main.get("kills"))

## Dark card with a colored border in the item's quality color.
func _style_button(button: Button, color: Color, border: int, radius: int) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#1E2330")
	normal.border_color = color
	normal.set_border_width_all(border)
	normal.set_corner_radius_all(radius)
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	button.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#2B3245")
	button.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = color.darkened(0.6)
	button.add_theme_stylebox_override("pressed", pressed)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("#1A1E27")
	disabled.border_color = color.darkened(0.55)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_disabled_color", color.darkened(0.35))

## Hover text: damage and attack interval (plus the resulting DPS).
func _tooltip_text(damage: int, interval: float) -> String:
	var safe_interval := maxf(interval, 0.01)
	return "\n".join([
		Loc.format_tr("shop_tip_damage", [damage]),
		Loc.format_tr("shop_tip_interval", [safe_interval]),
		Loc.format_tr("shop_tip_dps", [float(damage) / safe_interval])
	])

## Build the little "sell / cancel" context menu once, and reuse it for every weapon.
func _build_sell_popup() -> void:
	sell_popup = PanelContainer.new()
	sell_popup.name = "SellPopup"
	sell_popup.visible = false
	sell_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	sell_popup.z_index = 20

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#151A24")
	style.border_color = Color("#3A4457")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	sell_popup.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	sell_popup.add_child(box)

	popup_label = Label.new()
	popup_label.add_theme_font_size_override("font_size", 15)
	box.add_child(popup_label)

	popup_sell_button = Button.new()
	popup_sell_button.custom_minimum_size = Vector2(184, 38)
	popup_sell_button.add_theme_font_size_override("font_size", 16)
	popup_sell_button.add_theme_color_override("font_color", Color(0.98, 0.82, 0.3, 1))
	popup_sell_button.pressed.connect(_confirm_sell)
	box.add_child(popup_sell_button)

	popup_cancel_button = Button.new()
	popup_cancel_button.custom_minimum_size = Vector2(184, 34)
	popup_cancel_button.add_theme_font_size_override("font_size", 15)
	popup_cancel_button.pressed.connect(_close_sell_popup)
	box.add_child(popup_cancel_button)

	add_child(sell_popup)

func _on_owned_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_open_sell_popup(index)
		get_viewport().set_input_as_handled()

func _open_sell_popup(index: int) -> void:
	if inventory == null or index < 0 or index >= inventory.weapons.size():
		return
	var item: Dictionary = inventory.weapons[index]
	var quality: String = item["quality"]
	var sell_price: int = floori(float(inventory.get_weapon_price(item["id"], quality)) * 0.5)

	popup_label.text = Loc.format_tr("shop_sell_confirm", [
		Loc.t("quality_" + quality),
		inventory.get_weapon_name(item["id"]),
		sell_price
	])
	popup_label.add_theme_color_override("font_color", Color(inventory.QUALITY_DATA[quality]["color"]))
	popup_sell_button.text = Loc.t("shop_sell_do")
	popup_cancel_button.text = Loc.t("shop_sell_cancel")
	pending_sell_index = index

	sell_popup.reset_size()
	sell_popup.visible = true
	var box_size: Vector2 = sell_popup.get_combined_minimum_size()
	var view_size: Vector2 = size
	var pos: Vector2 = get_local_mouse_position() + Vector2(14.0, 14.0)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view_size.x - box_size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, view_size.y - box_size.y - 8.0))
	sell_popup.position = pos

func _confirm_sell() -> void:
	var index: int = pending_sell_index
	_close_sell_popup()
	if inventory == null or index < 0:
		return
	if inventory.sell_weapon(index):
		_refresh_all()

func _close_sell_popup() -> void:
	pending_sell_index = -1
	if sell_popup != null:
		sell_popup.visible = false

## Clicking the empty background dismisses the context menu.
func _on_background_input(event: InputEvent) -> void:
	if sell_popup != null and sell_popup.visible and event is InputEventMouseButton and event.pressed:
		_close_sell_popup()
		get_viewport().set_input_as_handled()

## Real attack interval of an equipped weapon (level-ups shorten it).
func _owned_interval(index: int) -> float:
	if inventory == null or index < 0 or index >= inventory.weapons.size():
		return 0.45
	var slots: Node = player.get_node_or_null("WeaponSlots") if player != null else null
	if slots != null and index < slots.get_child_count():
		return float(slots.get_child(index).fire_interval)
	var item: Dictionary = inventory.weapons[index]
	return float(inventory.WEAPON_DATA[item["id"]]["cooldown"])

func _buy_item(index: int) -> void:
	if index < 0 or index >= shop_items.size():
		return
	var item: Dictionary = shop_items[index]
	if item["sold"]:
		return

	if inventory.buy_weapon(item["id"], item["quality"]):
		item["sold"] = true
		_refresh_all()

func _on_inventory_changed() -> void:
	if visible:
		_refresh_all()

## Two identical weapons combined: show a short-lived "auto-merged" line in the shop.
func _on_weapon_merged(weapon_id: String, from_quality: String, to_quality: String) -> void:
	_toast_token += 1
	var token: int = _toast_token
	merge_label.text = Loc.format_tr("shop_merge_toast", [
		Loc.t("quality_" + from_quality),
		inventory.get_weapon_name(weapon_id),
		Loc.t("quality_" + to_quality)
	])
	merge_label.add_theme_color_override("font_color", Color(inventory.QUALITY_DATA[to_quality]["color"]))
	merge_label.visible = true
	await get_tree().create_timer(2.5).timeout
	if token == _toast_token:
		merge_label.visible = false

func _on_language_changed(_code: String) -> void:
	_refresh_texts()
	if visible:
		_refresh_all()

func _refresh_texts() -> void:
	title_label.text = Loc.t("shop_title")
	hint_label.text = Loc.t("shop_hint")
	close_button.text = Loc.t("shop_close")
	stats_title.text = Loc.t("stats_title")
	_refresh_header()
	if player != null:
		_refresh_stats()
