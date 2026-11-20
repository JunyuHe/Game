extends Control
## In-game pause menu (Esc): resume, settings with the language picker, quit back to the main menu.

@onready var title_label: Label = $CenterContainer/VBox/Title
@onready var resume_button: Button = $CenterContainer/VBox/ResumeButton
@onready var settings_button: Button = $CenterContainer/VBox/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBox/QuitButton

@onready var settings_panel: ColorRect = $SettingsPanel
@onready var settings_title: Label = $SettingsPanel/Center/VBox/SettingsTitle
@onready var language_label: Label = $SettingsPanel/Center/VBox/LanguageLabel
@onready var language_option: OptionButton = $SettingsPanel/Center/VBox/LanguageOption
@onready var back_button: Button = $SettingsPanel/Center/VBox/BackButton

func _ready() -> void:
	# Must keep running while the game itself is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	settings_panel.hide()

	resume_button.pressed.connect(_close)
	settings_button.pressed.connect(_open_settings)
	back_button.pressed.connect(_close_settings)
	quit_button.pressed.connect(_quit_to_menu)
	language_option.item_selected.connect(_on_language_selected)
	Loc.language_changed.connect(_on_language_changed)

	_populate_languages()
	_refresh_texts()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_escape()
		get_viewport().set_input_as_handled()

func _on_escape() -> void:
	# Settings open: Esc goes back to the pause buttons first.
	if visible and settings_panel.visible:
		_close_settings()
		return
	# Do not stack on top of the level-up cards, the shop or the game over screen.
	if not visible and (_upgrade_screen_visible() or _shop_visible() or _game_over()):
		return
	if visible:
		_close()
	else:
		_open()

func _open() -> void:
	settings_panel.hide()
	show()
	get_tree().paused = true

func _close() -> void:
	settings_panel.hide()
	hide()
	get_tree().paused = false

func _open_settings() -> void:
	_populate_languages()
	settings_panel.show()

func _close_settings() -> void:
	settings_panel.hide()

func _quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _upgrade_screen_visible() -> bool:
	for node in get_tree().get_nodes_in_group("upgrade_ui"):
		if node is CanvasItem and node.visible:
			return true
	return false

func _shop_visible() -> bool:
	for node in get_tree().get_nodes_in_group("shop_ui"):
		if node is CanvasItem and node.visible:
			return true
	return false

func _game_over() -> bool:
	var root := get_tree().current_scene
	if root == null:
		return false
	return root.get("_game_over") == true

func _populate_languages() -> void:
	language_option.clear()
	var languages := Loc.languages()
	for i in languages.size():
		language_option.add_item(languages[i]["label"], i)
	language_option.select(Loc.current_index())

func _on_language_selected(index: int) -> void:
	var languages := Loc.languages()
	if index < 0 or index >= languages.size():
		return
	Loc.set_language(languages[index]["code"])

func _on_language_changed(_code: String) -> void:
	_refresh_texts()
	language_option.select(Loc.current_index())

func _refresh_texts() -> void:
	title_label.text = Loc.t("pause_title")
	resume_button.text = Loc.t("pause_resume")
	settings_button.text = Loc.t("pause_settings")
	quit_button.text = Loc.t("pause_quit")
	settings_title.text = Loc.t("settings_title")
	language_label.text = Loc.t("settings_language")
	back_button.text = Loc.t("settings_back")
