extends Node
## Runtime localization service for the game.
## Source strings are English. Chinese and Spanish are provided as translations;
## every language keeps the same key set so switching never leaves a string untranslated.

signal language_changed(code: String)

const SETTINGS_PATH := "user://settings.cfg"

## Languages offered in the settings menu. Labels stay in English on purpose.
const SUPPORTED := [
	{"code": "en", "label": "English"},
	{"code": "es", "label": "Spanish"},
	{"code": "zh", "label": "Chinese"}
]

const STRINGS := {
	"en": {
		"app_title": "VAMPIRE SURVIVORS CLONE",
		"menu_start": "Start",
		"menu_settings": "Settings",
		"menu_quit": "Quit",
		"settings_title": "Settings",
		"settings_language": "Language",
		"settings_back": "Back",
		"hud_health": "Health: %d / %d",
		"hud_kills": "Kills: %d",
		"hud_level_exp": "Lv %d    %d / %d EXP",
		"hud_time": "Time: %02d:%02d",
		"stats_title": "Character Stats (press Tab to close)",
		"stats_level": "Level: %d",
		"stats_exp": "EXP: %d / %d",
		"stats_hp": "HP: %d / %d",
		"stats_speed": "Speed: %d",
		"stats_interval": "Attack interval: %.2fs",
		"stats_damage": "Damage: %d",
		"stats_kills": "Kills: %d",
		"game_over": "GAME OVER",
		"game_over_restart": "Restart"
	},
	"es": {
		"app_title": "CLON DE VAMPIRE SURVIVORS",
		"menu_start": "Jugar",
		"menu_settings": "Ajustes",
		"menu_quit": "Salir",
		"settings_title": "Ajustes",
		"settings_language": "Idioma",
		"settings_back": "Volver",
		"hud_health": "Salud: %d / %d",
		"hud_kills": "Bajas: %d",
		"hud_level_exp": "Nv %d    %d / %d EXP",
		"hud_time": "Tiempo: %02d:%02d",
		"stats_title": "Atributos (Tab para cerrar)",
		"stats_level": "Nivel: %d",
		"stats_exp": "EXP: %d / %d",
		"stats_hp": "Salud: %d / %d",
		"stats_speed": "Velocidad: %d",
		"stats_interval": "Intervalo de disparo: %.2f s",
		"stats_damage": "Dano: %d",
		"stats_kills": "Bajas: %d",
		"game_over": "FIN DEL JUEGO",
		"game_over_restart": "Reiniciar"
	},
	"zh": {
		"app_title": "吸血鬼幸存者 复刻版",
		"menu_start": "开始游戏",
		"menu_settings": "设置",
		"menu_quit": "退出",
		"settings_title": "设置",
		"settings_language": "语言",
		"settings_back": "返回",
		"hud_health": "生命：%d / %d",
		"hud_kills": "击杀：%d",
		"hud_level_exp": "等级 %d    %d / %d 经验",
		"hud_time": "时间：%02d:%02d",
		"stats_title": "角色属性（Tab 关闭）",
		"stats_level": "等级：%d",
		"stats_exp": "经验：%d / %d",
		"stats_hp": "生命：%d / %d",
		"stats_speed": "移速：%d",
		"stats_interval": "攻击间隔：%.2f 秒",
		"stats_damage": "伤害：%d",
		"stats_kills": "击杀：%d",
		"game_over": "游戏结束",
		"game_over_restart": "重新开始"
	}
}

var language: String = "en"

func _ready() -> void:
	_load_preference()

## Languages available for the language picker, in display order.
func languages() -> Array:
	return SUPPORTED

## Translated string for a key, falling back to English and then to the key itself.
func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(language, STRINGS["en"])
	if table.has(key):
		return table[key]
	return STRINGS["en"].get(key, key)

## Translated string with printf-style arguments.
func format_tr(key: String, args: Array) -> String:
	return t(key) % args

## Index of the current language inside SUPPORTED.
func current_index() -> int:
	for i in SUPPORTED.size():
		if SUPPORTED[i]["code"] == language:
			return i
	return 0

## Switch language, persist it and notify listeners.
func set_language(code: String) -> void:
	if not STRINGS.has(code) or code == language:
		return
	language = code
	_save_preference()
	language_changed.emit(code)

func _load_preference() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var saved: String = config.get_value("general", "language", "en")
	if STRINGS.has(saved):
		language = saved

func _save_preference() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", language)
	config.save(SETTINGS_PATH)
