extends Control
## Main menu: Start, Settings (language picker) and Quit.
## Every visible string is fetched from the localization service, so the UI follows the chosen language.

@onready var title_label: Label = $Center/VBox/TitleLabel
@onready var start_button: Button = $Center/VBox/StartButton
@onready var settings_button: Button = $Center/VBox/SettingsButton
@onready var quit_button: Button = $Center/VBox/QuitButton

@onready var settings_panel: ColorRect = $SettingsPanel
@onready var settings_title: Label = $SettingsPanel/Center/VBox/SettingsTitle
@onready var language_label: Label = $SettingsPanel/Center/VBox/LanguageRow/LanguageLabel
@onready var language_option: OptionButton = $SettingsPanel/Center/VBox/LanguageRow/LanguageOption
@onready var back_button: Button = $SettingsPanel/Center/VBox/BackButton

func _ready() -> void:
	settings_panel.visible = false
	Loc.language_changed.connect(_on_language_changed)
	_populate_languages()
	_refresh_texts()

func _populate_languages() -> void:
	language_option.clear()
	for entry in Loc.languages():
		language_option.add_item(entry["label"])
	language_option.selected = Loc.current_index()

func _refresh_texts() -> void:
	title_label.text = Loc.t("app_title")
	start_button.text = Loc.t("menu_start")
	settings_button.text = Loc.t("menu_settings")
	quit_button.text = Loc.t("menu_quit")
	settings_title.text = Loc.t("settings_title")
	language_label.text = Loc.t("settings_language")
	back_button.text = Loc.t("settings_back")

func _on_language_changed(_code: String) -> void:
	_populate_languages()
	_refresh_texts()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_settings_pressed() -> void:
	language_option.selected = Loc.current_index()
	settings_panel.visible = true

func _on_back_pressed() -> void:
	settings_panel.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_language_selected(index: int) -> void:
	var supported := Loc.languages()
	if index < 0 or index >= supported.size():
		return
	Loc.set_language(supported[index]["code"])
