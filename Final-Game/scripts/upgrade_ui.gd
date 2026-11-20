extends Control
## Level-up reward cards: the game pauses, four random cards appear in the middle,
## the player clicks one, the bonus is applied and the game resumes.

@export var player: CharacterBody2D

@onready var title_label: Label = $CenterContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/Subtitle
@onready var cards: Array = [
	$CenterContainer/VBoxContainer/Cards/Card1,
	$CenterContainer/VBoxContainer/Cards/Card2,
	$CenterContainer/VBoxContainer/Cards/Card3,
	$CenterContainer/VBoxContainer/Cards/Card4
]

## Border and text color per quality tier, matching the six tiers in player.gd.
const QUALITY_COLORS := {
	"base": "#BDBDBD",
	"common": "#36B76A",
	"fine": "#378DE8",
	"epic": "#A35ADC",
	"mythic": "#D5A000",
	"legendary": "#E0454B"
}

const CARD_BG := "#252A38"
const CARD_BG_HOVER := "#353B4F"

## Options currently on screen, kept so a language change can redraw the same cards.
var _options: Array = []

func _ready() -> void:
	# Keep working while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("upgrade_ui")
	hide()

	for i in cards.size():
		cards[i].pressed.connect(_on_card_pressed.bind(i))

	Loc.language_changed.connect(_on_language_changed)

	if player == null:
		# Fallback for scenes where the Inspector assignment was skipped.
		player = get_node_or_null("../../Player") as CharacterBody2D
	if player == null:
		push_error("UpgradeUI: assign the Player node in the Inspector.")
		return
	player.level_up_started.connect(show_rewards)

func show_rewards(options: Array) -> void:
	if options.is_empty():
		return
	_options = options
	_apply_options()
	show()
	get_tree().paused = true

## Builds the text and styling of every card from the current options.
func _apply_options() -> void:
	title_label.text = Loc.t("upgrade_title")
	subtitle_label.text = Loc.t("upgrade_subtitle")

	for i in cards.size():
		var card: Button = cards[i]
		if i >= _options.size():
			card.hide()
			continue

		card.show()
		var option: Dictionary = _options[i]
		var quality_key: String = option["quality"]
		var stat_key: String = option["stat"]
		var value: int = option["value"]

		var unit := Loc.t("unit_" + stat_key)
		if unit == "%":
			card.text = "%s\n\n%s\n\n+%d%%" % [
				Loc.t("quality_" + quality_key),
				Loc.t("stat_" + stat_key),
				value
			]
		else:
			card.text = "%s\n\n%s\n\n+%d %s" % [
				Loc.t("quality_" + quality_key),
				Loc.t("stat_" + stat_key),
				value,
				unit
			]

		var quality_color := Color(QUALITY_COLORS.get(quality_key, "#FFFFFF"))
		style_card(card, quality_color)

func style_card(card: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(CARD_BG)
	normal.border_color = color
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	card.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(CARD_BG_HOVER)
	card.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = color.darkened(0.5)
	card.add_theme_stylebox_override("pressed", pressed)

	card.add_theme_color_override("font_color", color)
	card.add_theme_color_override("font_hover_color", color)
	card.add_theme_color_override("font_pressed_color", Color.WHITE)

func _on_language_changed(_code: String) -> void:
	if visible:
		_apply_options()

func _on_card_pressed(index: int) -> void:
	if _options.is_empty() or index >= _options.size():
		return

	hide()
	player.choose_upgrade(index)

	# No more pending levels: resume the game. Otherwise player emits again with the next set.
	if player.pending_levels <= 0:
		get_tree().paused = false
